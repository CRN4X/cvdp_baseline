#!/bin/sh
set -eu

# One-shot local flow (no Docker):
# 1) Run agent locally (staged copy refreshed from harness rtl.orig baseline)
# 2) Run local cocotb/pytest harness using staged agent_files rtl directly
#
# Usage:
#   ./run_local_eval.sh /abs/path/to/work/<problem>/harness/<id>

HARNESS_PATH="${1:-}"
if [ -z "$HARNESS_PATH" ]; then
  echo "Usage: $0 /abs/path/to/work/<problem>/harness/<id>"
  exit 1
fi

# Normalize to absolute path to avoid pytest path issues after cd.
HARNESS_PATH=$(cd "$HARNESS_PATH" && pwd)

if [ ! -d "$HARNESS_PATH" ]; then
  echo "Harness path does not exist: $HARNESS_PATH"
  exit 1
fi

if [ ! -f "$HARNESS_PATH/prompt.json" ] || [ ! -d "$HARNESS_PATH/src" ]; then
  echo "Invalid harness folder (missing prompt.json or src/): $HARNESS_PATH"
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Pre-check local toolchain
if ! command -v iverilog >/dev/null 2>&1; then
  echo "Missing tool: iverilog (install via Homebrew: brew install icarus-verilog)"
  exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
  echo "Missing tool: vvp (comes with icarus-verilog)"
  exit 1
fi
if ! python3 -c "import pytest, cocotb, cocotb_tools.runner" >/dev/null 2>&1; then
  echo "Missing Python deps in current environment."
  echo "Activate venv and run: pip install -r requirements.txt"
  exit 1
fi

# Ensure cocotb can locate a shared libpython runtime.
# If LIBPYTHON_LOC is not pre-set, try to auto-detect it from the active python.
if [ -z "${LIBPYTHON_LOC:-}" ]; then
  LIBPYTHON_CANDIDATE=$(python3 - <<'PY'
import glob
import os
import sys
import sysconfig

major, minor = sys.version_info[:2]
libdir = sysconfig.get_config_var("LIBDIR") or ""
ldlibrary = sysconfig.get_config_var("LDLIBRARY") or ""
enable_shared = bool(sysconfig.get_config_var("Py_ENABLE_SHARED"))

candidates = []
if enable_shared and libdir and ldlibrary and ".so" in ldlibrary:
    candidates.append(os.path.join(libdir, ldlibrary))

search_dirs = [d for d in [libdir, "/usr/local/lib", "/usr/lib/x86_64-linux-gnu", "/usr/lib64", "/usr/lib"] if d]
patterns = [
    f"libpython{major}.{minor}.so",
    f"libpython{major}.{minor}.so.1.0",
    f"libpython{major}.{minor}.so.*",
]
for d in search_dirs:
    for pat in patterns:
        candidates.extend(sorted(glob.glob(os.path.join(d, pat))))

for path in candidates:
    if os.path.isfile(path):
        print(path)
        break
PY
)
  if [ -n "${LIBPYTHON_CANDIDATE}" ] && [ -f "${LIBPYTHON_CANDIDATE}" ]; then
    export LIBPYTHON_LOC="${LIBPYTHON_CANDIDATE}"
    echo "Auto-detected LIBPYTHON_LOC=$LIBPYTHON_LOC"
  fi
fi

# Step 1: run local agent (creates/updates staged files in my-agent/agent_files/...)
"$SCRIPT_DIR/run_local_agent.sh" "$HARNESS_PATH"

# Step 2: resolve staged rtl path from harness path.
PROBLEM_NAME=$(echo "$HARNESS_PATH" | awk -F'/work/' '{print $2}' | awk -F'/' '{print $1}')
ISSUE_ID=$(basename "$HARNESS_PATH")
STAGED_RTL_PATH_ISSUE="$SCRIPT_DIR/agent_files/$PROBLEM_NAME/$ISSUE_ID/rtl"
STAGED_RTL_PATH_LEGACY="$SCRIPT_DIR/agent_files/$PROBLEM_NAME/rtl"
STAGED_RTL_PATH=""
if [ -d "$STAGED_RTL_PATH_ISSUE" ]; then
  STAGED_RTL_PATH="$STAGED_RTL_PATH_ISSUE"
elif [ -d "$STAGED_RTL_PATH_LEGACY" ]; then
  STAGED_RTL_PATH="$STAGED_RTL_PATH_LEGACY"
fi

if [ -z "$STAGED_RTL_PATH" ]; then
  echo "Staged RTL path not found."
  echo "Tried:"
  echo "  $STAGED_RTL_PATH_ISSUE"
  echo "  $STAGED_RTL_PATH_LEGACY"
  echo "Run the agent once first to generate staged files."
  exit 1
fi

# Parse .env lines like: KEY = value
read_env_val() {
  env_file="$1"
  key="$2"
  val=$(awk -F'=' -v k="$key" '
    $0 ~ /^[[:space:]]*#/ {next}
    NF >= 2 {
      lhs=$1; rhs=$0; sub(/^[^=]*=/, "", rhs)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
      if (lhs == k) { print rhs; exit }
    }
  ' "$env_file")
  printf "%s" "$val"
}

RUNNERS=$(find "$HARNESS_PATH/src" -maxdepth 1 -type f -name 'test_runner*.py' | sort)
if [ -z "$RUNNERS" ]; then
  echo "No test runner files found under: $HARNESS_PATH/src (expected test_runner*.py)"
  exit 1
fi

mkdir -p "$HARNESS_PATH/rundir/harness/.cache"
OVERALL_RC=0

for runner_path in $RUNNERS; do
  runner_file=$(basename "$runner_path")
  runner_suffix="${runner_file#test_runner}"
  runner_suffix="${runner_suffix%.py}"

  ENV_FILE="$HARNESS_PATH/src/.env${runner_suffix}"
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$HARNESS_PATH/src/.env" ]; then
      ENV_FILE="$HARNESS_PATH/src/.env"
    else
      echo "Missing env file for runner $runner_file (looked for $HARNESS_PATH/src/.env${runner_suffix} and fallback .env)"
      OVERALL_RC=1
      continue
    fi
  fi

  VERILOG_SOURCES_RAW=$(read_env_val "$ENV_FILE" "VERILOG_SOURCES")
  TOPLEVEL=$(read_env_val "$ENV_FILE" "TOPLEVEL")
  MODULE=$(read_env_val "$ENV_FILE" "MODULE")
  SIM=$(read_env_val "$ENV_FILE" "SIM")
  TOPLEVEL_LANG=$(read_env_val "$ENV_FILE" "TOPLEVEL_LANG")
  WAVE=$(read_env_val "$ENV_FILE" "WAVE")

  if [ -z "$VERILOG_SOURCES_RAW" ] || [ -z "$TOPLEVEL" ] || [ -z "$MODULE" ]; then
    echo "Missing required variables in $ENV_FILE (VERILOG_SOURCES/TOPLEVEL/MODULE)."
    OVERALL_RC=1
    continue
  fi

  # Remap container paths -> local paths
  VERILOG_SOURCES=$(printf "%s" "$VERILOG_SOURCES_RAW" | \
    sed "s#/code/rtl#$STAGED_RTL_PATH#g" | \
    sed "s#/code/verif#$HARNESS_PATH/verif#g" | \
    sed "s#/code/src#$HARNESS_PATH/src#g")

  export VERILOG_SOURCES
  export TOPLEVEL
  export MODULE
  export SIM="${SIM:-icarus}"
  export TOPLEVEL_LANG="${TOPLEVEL_LANG:-verilog}"
  export WAVE="${WAVE:-true}"
  export PYTHONPATH="$HARNESS_PATH/src${PYTHONPATH:+:$PYTHONPATH}"

  echo "Running local harness eval"
  echo "  HARNESS_PATH=$HARNESS_PATH"
  echo "  RUNNER=$runner_file"
  echo "  ENV_FILE=$(basename "$ENV_FILE")"
  echo "  TOPLEVEL=$TOPLEVEL"
  echo "  MODULE=$MODULE"
  echo "  SIM=$SIM"
  echo "  VERILOG_SOURCES=$VERILOG_SOURCES"

  cd "$HARNESS_PATH/rundir"
  set +e
  python3 -m pytest "$runner_path" -s -v -o cache_dir="$HARNESS_PATH/rundir/harness/.cache"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    OVERALL_RC="$rc"
  fi
done

exit "$OVERALL_RC"
