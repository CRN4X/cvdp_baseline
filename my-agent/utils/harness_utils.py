#!/usr/bin/env python3

import json
import os
import time
from pathlib import Path
from typing import Optional
from utils.constants import (
    ENV_WORKSPACE_ROOT,
    HARNESS_AGENT_REPORT_FILENAME,
    HARNESS_PROMPT_FILENAME,
    HARNESS_RUNDIR_DIRNAME,
    NOOP_AGENT_NAME,
    NOOP_MESSAGE,
    NOOP_MODE,
    NOOP_STATUS,
    TIMESTAMP_FORMAT,
    UTF8_ENCODING,
)


def infer_harness_mode_workspace() -> Optional[Path]:
    env_root = Path.cwd().resolve()
    ws_env = os.environ.get(ENV_WORKSPACE_ROOT)
    if ws_env:
        p = Path(ws_env).resolve()
        if p.exists():
            return p
    if (env_root / HARNESS_PROMPT_FILENAME).exists() and (env_root / HARNESS_RUNDIR_DIRNAME).exists():
        return env_root
    return None


def write_harness_noop_report(workspace: Path) -> None:
    rundir = workspace / HARNESS_RUNDIR_DIRNAME
    rundir.mkdir(parents=True, exist_ok=True)
    report = {
        "agent": NOOP_AGENT_NAME,
        "mode": NOOP_MODE,
        "status": NOOP_STATUS,
        "message": NOOP_MESSAGE,
        "timestamp": time.strftime(TIMESTAMP_FORMAT),
    }
    (rundir / HARNESS_AGENT_REPORT_FILENAME).write_text(json.dumps(report, indent=2) + "\n", encoding=UTF8_ENCODING)
