#!/usr/bin/env python3

import os
import sys
import time
from pathlib import Path
from typing import Optional, TextIO, Tuple
from utils.constants import (
    BATCH_REPORTS_DIRNAME,
    MY_AGENT_DIRNAME,
    RUN_LOG_FILENAME,
    UTF8_ENCODING,
    WORK_DIRNAME,
    WORK_LOGS_DIRNAME,
)


def log_timestamp() -> str:
    return time.strftime("%d_%b_%Y_%H_%M_%S").lower()


def log(msg: str) -> None:
    print(f"\n[{log_timestamp()}] [agent.py] {msg}", flush=True)


def log_codex(msg: str) -> None:
    print(f"\n[{log_timestamp()}] [codex] {msg}", flush=True)


class TeeStream:
    def __init__(self, console_stream: TextIO, log_stream: TextIO) -> None:
        self.console_stream = console_stream
        self.log_stream = log_stream

    def write(self, data: str) -> int:
        n = self.console_stream.write(data)
        self.log_stream.write(data)
        return n

    def flush(self) -> None:
        self.console_stream.flush()
        self.log_stream.flush()

    def isatty(self) -> bool:
        return bool(getattr(self.console_stream, "isatty", lambda: False)())


def lock_log_file(log_file: TextIO, log_path: Path) -> None:
    if os.name == "nt":
        import msvcrt

        try:
            msvcrt.locking(log_file.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise RuntimeError(
                f"Could not lock {log_path}. It may be open in another application. "
                "Close the file and retry."
            ) from exc
        return

    import fcntl

    try:
        fcntl.flock(log_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        raise RuntimeError(
            f"Could not lock {log_path}. It may be open in another application. "
            "Close the file and retry."
        ) from exc


def start_run_log(repo_root: Path) -> Tuple[TextIO, TextIO, TextIO]:
    work_dir = repo_root / WORK_DIRNAME
    log_path = work_dir / RUN_LOG_FILENAME
    log_file, orig_stdout, orig_stderr = start_tee_log(log_path)
    log(f"Logging terminal output to: {log_path}")
    return log_file, orig_stdout, orig_stderr


def start_problem_log(run_dir: Path, log_name: str) -> Tuple[TextIO, TextIO, TextIO]:
    log_path = run_dir / log_name
    log_file, orig_stdout, orig_stderr = start_tee_log(log_path)
    log(f"Logging problem output to: {log_path}")
    return log_file, orig_stdout, orig_stderr


def start_tee_log(log_path: Path) -> Tuple[TextIO, TextIO, TextIO]:
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_file = log_path.open("w", encoding=UTF8_ENCODING)
    except OSError as exc:
        raise RuntimeError(
            f"Could not open {log_path} for writing. Check folder permissions and retry."
        ) from exc

    try:
        lock_log_file(log_file, log_path)
    except RuntimeError:
        log_file.close()
        raise

    orig_stdout = sys.stdout
    orig_stderr = sys.stderr
    sys.stdout = TeeStream(orig_stdout, log_file)
    sys.stderr = TeeStream(orig_stderr, log_file)
    return log_file, orig_stdout, orig_stderr


def stop_run_log(log_file: TextIO, orig_stdout: TextIO, orig_stderr: TextIO) -> None:
    sys.stdout = orig_stdout
    sys.stderr = orig_stderr
    log_file.close()


def archive_run_log(repo_root: Path, idx: int) -> Path:
    run_log_path = repo_root / WORK_DIRNAME / RUN_LOG_FILENAME
    if not run_log_path.exists():
        raise RuntimeError(f"Run log not found at {run_log_path}")

    logs_dir = repo_root / WORK_DIRNAME / WORK_LOGS_DIRNAME
    logs_dir.mkdir(parents=True, exist_ok=True)

    ts = int(time.time())
    archive_path = logs_dir / f"run_{ts}__{idx}.log"
    archive_path.write_text(run_log_path.read_text(encoding=UTF8_ENCODING), encoding=UTF8_ENCODING)
    return archive_path


def ensure_batch_report_dir(repo_root: Path, batch_run_ts: str) -> Path:
    run_dir = repo_root / MY_AGENT_DIRNAME / BATCH_REPORTS_DIRNAME / batch_run_ts
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def append_batch_index_log(run_dir: Optional[Path], log_name: str, message: str) -> None:
    if run_dir is None:
        return
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = run_dir / log_name
    with log_path.open("a", encoding=UTF8_ENCODING) as f:
        f.write(f"[{log_timestamp()}] {message}\n")
