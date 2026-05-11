#!/usr/bin/env python3

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional
from utils.constants import (
    AGENT_ENV_DIRNAME,
    BIN_DIRNAME,
    DEFAULT_SHELL_PATH,
    ENV_SHELL,
    LOCAL_EVAL_IMPORT_CHECK,
    PYTHON_BIN_NAME,
    SHELL_CANDIDATES,
)


def run_cmd(
    cmd: List[str],
    cwd: Path,
    stdin_text: Optional[str] = None,
    stream_stdout: bool = False,
) -> subprocess.CompletedProcess:
    if not stream_stdout:
        return subprocess.run(
            cmd,
            cwd=str(cwd),
            text=True,
            input=stdin_text,
            capture_output=True,
            check=False,
        )

    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd),
        text=True,
        stdin=subprocess.PIPE if stdin_text is not None else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )
    assert proc.stdout is not None
    if stdin_text is not None and proc.stdin is not None:
        proc.stdin.write(stdin_text)
        proc.stdin.close()

    out_lines: List[str] = []
    for line in proc.stdout:
        print(line, end="", flush=True)
        out_lines.append(line)
    rc = proc.wait()
    return subprocess.CompletedProcess(cmd, rc, "".join(out_lines), "")


def resolve_shell_path() -> str:
    env_shell = os.environ.get(ENV_SHELL, "")
    if env_shell and Path(env_shell).is_file() and os.access(env_shell, os.X_OK):
        return env_shell

    for shell_name in SHELL_CANDIDATES:
        resolved = shutil.which(shell_name)
        if resolved:
            return resolved
    return DEFAULT_SHELL_PATH


def ensure_local_eval_env(repo_root: Path) -> bool:
    cmd = [
        str(repo_root / AGENT_ENV_DIRNAME / BIN_DIRNAME / PYTHON_BIN_NAME),
        "-c",
        LOCAL_EVAL_IMPORT_CHECK,
    ]
    cp = run_cmd(cmd, cwd=repo_root)
    return cp.returncode == 0
