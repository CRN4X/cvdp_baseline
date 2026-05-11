# NVIDIA CVDP Problem Set

This repository runs local agentic RTL debug/eval workflows for harnessed verification tasks.

## Prerequisites

- Python `3.12`
- Codex CLI (`codex`) on `PATH`
- Icarus Verilog tools on `PATH`:
  - `iverilog`
  - `vvp`

## One-Time Setup

Run from repo root:

```bash
./setup_local_no_docker.sh
```

This script:
- creates/reuses `agent_env`
- installs Python dependencies from `requirements.txt`
- prepares harness RTL links/copies when staged RTL exists

## Main Command

Run agent orchestration from repo root:

```bash
source agent_env/bin/activate
python3 my-agent/agent.py -i <index>
```

## CLI Options

```text
python3 my-agent/agent.py -i <index> [--max-retries N] [--save_log]
python3 my-agent/agent.py -i "[start,end]" [--max-retries N] [--save_log]
python3 my-agent/agent.py --index-range <start> <end> [--max-retries N] [--save_log]
```

- `--index/-i`: 1-based dataset index (single) or bracket range
- `--index-range`: inclusive 1-based range
- `--max-retries/-r`: retries per solve cycle (default `8`, max `17`)
- `--save_log/-s`: archive `work/run.log` for single-index mode

Examples:

```bash
python3 my-agent/agent.py -i 1
python3 my-agent/agent.py -i "[1,5]"
python3 my-agent/agent.py --index-range 10 20 -r 12
```

## Dataset Input

- Dataset file: `dataset/hackathon-agentic-obfuscated_final_corrected.jsonl`
- Each row `id` must map to:
  - `work/<problem_name>/harness/<id>/`

## Current Runtime Flow

1. Resolve dataset row by index.
2. Resolve harness path under `work/.../harness/<id>`.
3. Reset staged RTL from original baseline:
   - source: `work/.../harness/<id>/rtl.orig`
   - target: `my-agent/agent_files/<problem>/<id>/rtl`
4. Run Codex iterative solve loop.
5. Run local eval via `my-agent/run_local_eval.sh`.
6. Run single-target batch reporting to refresh benchmark artifacts.

Important:
- Edits are restricted to staged files under `my-agent/agent_files/.../rtl`.
- Original baseline `work/.../rtl.orig` is treated as read-only input.

## Logs and Reports

### Single-index mode (`-i 7`)

- Live run log: `work/run.log`
- Optional archive with `--save_log`:
  - `work/logs/run_<unix_timestamp>__<index>.log`

### Batch mode (`-i "[1,10]"` or `--index-range`)

- Folder per run:
  - `my-agent/batch_reports/<YYYYMMDD_HHMMSS>/`
- Per-problem log:
  - `run_<problem_name>_<problem_id>.log`
- Summary CSV:
  - `local_eval_summary_run_<YYYYMMDD_HHMMSS>.csv`

## Benchmark Artifacts (updated each run)

- `work/result.json`
- `work/raw_result.json`
- `work/report.json`
- `work/report.txt`

## Troubleshooting

If a run fails, check in this order:

1. Problem log in batch folder (batch mode) or `work/run.log` (single mode)
2. Harness simulation log:
   - `work/<problem>/harness/<id>/rundir/sim.log`
3. Harness agent report:
   - `work/<problem>/harness/<id>/rundir/agent_report.json`

## Quick Start

```bash
./setup_local_no_docker.sh
source agent_env/bin/activate
python3 my-agent/agent.py -i 1
```
