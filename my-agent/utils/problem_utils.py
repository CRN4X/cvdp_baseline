#!/usr/bin/env python3

import json
import shutil
from pathlib import Path
from typing import Dict, List, Tuple
from utils.constants import (
    AGENT_FILES_DIRNAME,
    BEFORE_DIRNAME,
    DEFAULT_LEARNING_DIFFICULTY,
    HARNESS_DIRNAME,
    HARNESS_SIM_LOG_FILENAME,
    LEARNING_DIFFICULTIES,
    MY_AGENT_DIRNAME,
    RTL_DIRNAME,
    RTL_ORIG_DIRNAME,
    SIM_ERROR_PATTERNS,
    UTF8_ENCODING,
    WORK_DIRNAME,
)


def load_dataset_entries(dataset_path: Path) -> List[Dict]:
    entries: List[Dict] = []
    with dataset_path.open("r", encoding=UTF8_ENCODING) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entries.append(json.loads(line))
    return entries


def split_problem_and_issue(dataset_id: str) -> Tuple[str, str]:
    problem, issue = dataset_id.rsplit("_", 1)
    return problem, issue


def normalize_difficulty(value: object) -> str:
    text = str(value).strip().lower()
    if text in LEARNING_DIFFICULTIES:
        return text
    return DEFAULT_LEARNING_DIFFICULTY


def infer_entry_difficulty(entry: Dict) -> str:
    categories = entry.get("categories")
    if isinstance(categories, list):
        for token in categories:
            norm = normalize_difficulty(token)
            if norm in LEARNING_DIFFICULTIES and str(token).strip().lower() == norm:
                return norm
    return DEFAULT_LEARNING_DIFFICULTY


def resolve_harness_path(repo_root: Path, problem: str, issue: str) -> Path:
    exact = repo_root / WORK_DIRNAME / problem / HARNESS_DIRNAME / issue
    if exact.exists():
        return exact

    # Handle zero-padded mismatch (e.g., dataset has 0681 but dir is 681).
    harness_dir = repo_root / WORK_DIRNAME / problem / HARNESS_DIRNAME
    if not harness_dir.exists():
        raise FileNotFoundError(f"Missing harness dir: {harness_dir}")
    if issue.isdigit():
        issue_num = int(issue)
        for p in harness_dir.iterdir():
            if p.is_dir() and p.name.isdigit() and int(p.name) == issue_num:
                return p
    raise FileNotFoundError(f"Cannot resolve harness path for {problem}_{issue}")


def reset_staged_rtl_from_original(repo_root: Path, harness_path: Path, problem: str) -> Tuple[Path, Path]:
    source_candidates = [
        harness_path / BEFORE_DIRNAME / RTL_DIRNAME,
        harness_path / RTL_ORIG_DIRNAME,
    ]
    source_rtl = None
    for candidate in source_candidates:
        if candidate.exists() and candidate.is_dir():
            source_rtl = candidate
            break

    if source_rtl is None:
        rtl_path = harness_path / RTL_DIRNAME
        if rtl_path.is_symlink():
            target = rtl_path.resolve()
            if target.exists() and target.is_dir():
                source_rtl = target
        elif rtl_path.exists() and rtl_path.is_dir():
            source_rtl = rtl_path

    if source_rtl is None:
        raise FileNotFoundError(
            "Could not locate original RTL source directory; expected one of "
            f"{harness_path / BEFORE_DIRNAME / RTL_DIRNAME}, {harness_path / RTL_ORIG_DIRNAME}, "
            f"non-symlink {harness_path / RTL_DIRNAME}, and symlink target of {harness_path / RTL_DIRNAME}"
        )

    issue = harness_path.name
    staged_rtl = repo_root / MY_AGENT_DIRNAME / AGENT_FILES_DIRNAME / problem / issue / RTL_DIRNAME
    staged_parent = staged_rtl.parent
    staged_parent.mkdir(parents=True, exist_ok=True)
    if staged_rtl.exists() or staged_rtl.is_symlink():
        if staged_rtl.is_symlink() or staged_rtl.is_file():
            staged_rtl.unlink()
        else:
            shutil.rmtree(staged_rtl)
    shutil.copytree(source_rtl, staged_rtl)
    return source_rtl, staged_rtl


def extract_first_error_from_sim_log(sim_log: Path) -> str:
    if not sim_log.exists():
        return f"{HARNESS_SIM_LOG_FILENAME} missing"
    for line in sim_log.read_text(encoding=UTF8_ENCODING, errors="ignore").splitlines():
        if any(p in line for p in SIM_ERROR_PATTERNS):
            return line.strip()
    return f"no explicit error line found in {HARNESS_SIM_LOG_FILENAME}"


def read_tail(path: Path, lines: int = 80) -> str:
    if not path.exists():
        return f"[missing] {path}"
    content = path.read_text(encoding=UTF8_ENCODING, errors="ignore").splitlines()
    return "\n".join(content[-lines:])
