#!/usr/bin/env python3

# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""Codex-driven local solver orchestrator.

Modes:
1) Orchestrator mode: `python3 my-agent/agent.py -i 1`
   - Picks the Nth problem from dataset JSONL
   - Runs Codex CLI + local eval loop (default 8 retries, configurable up to 17)
   - Runs local batch benchmark to refresh result/report artifacts

2) Harness mode (no args): called by run_local_eval.sh
   - No-op agent that only writes a minimal agent_report.json
"""

import subprocess
import sys
import time
import shlex
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from utils.constants import (
    ACTIVATE_SCRIPT_NAME,
    AGENT_FILES_DIRNAME,
    AGENT_ENV_DIRNAME,
    BIN_DIRNAME,
    CODEX_TIMEOUT_BACKOFF_SEC,
    CODEX_TIMEOUT_MINUTES,
    CODEX_TIMEOUT_SEC,
    CODEX_EXEC_CMD,
    CODEX_STREAM_BANNER,
    CODEX_TIMEOUT_RETURN_CODE,
    DATASET_DIRNAME,
    DATASET_FILENAME,
    HARNESS_AGENT_REPORT_FILENAME,
    HARNESS_PROMPT_FILENAME,
    HARNESS_RUNDIR_DIRNAME,
    HARNESS_SIM_LOG_FILENAME,
    MAX_SOLVE_RUN_CYCLES,
    MY_AGENT_DIRNAME,
    AGENT_BATCH_TS_ENV,
    AGENT_MANAGED_PROBLEM_LOG_ENV,
    AGENT_PIPELINE_START_EPOCH_ENV,
    RUN_LOG_FILENAME,
    RTL_DIRNAME,
    WORK_DIRNAME,
    WORK_LOGS_DIRNAME,
)
from utils.cli import parse_cli, print_usage
from utils.csv_reporting import build_codex_reporting_env_exports
from utils.harness_utils import infer_harness_mode_workspace, write_harness_noop_report
from utils.logging_utils import (
    append_batch_index_log,
    archive_run_log,
    ensure_batch_report_dir,
    log,
    log_codex,
    start_problem_log,
    start_run_log,
    stop_run_log,
)
from utils.problem_utils import (
    extract_first_error_from_sim_log,
    infer_entry_difficulty,
    load_dataset_entries,
    read_tail,
    reset_staged_rtl_from_original,
    resolve_harness_path,
    split_problem_and_issue,
)
from utils.runtime_utils import ensure_local_eval_env, resolve_shell_path, run_cmd
from utils.tokens import (
    estimate_codex_token_usage,
    extract_codex_iteration_count,
    extract_codex_token_usage,
    token_count,
)


def infer_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def build_codex_prompt(
    harness_path: Path,
    attempt: int,
    max_retries: int,
    problem_difficulty: str,
    fail_context: str,
) -> str:
    staged_problem = harness_path.parts[-3]
    staged_issue = harness_path.name
    base = f"""Work on this harness iteratively until it passes:
{harness_path}

Rules:
- Run ./{MY_AGENT_DIRNAME}/run_local_eval.sh "{harness_path}"
- If failing, read:
  - {harness_path}/{HARNESS_PROMPT_FILENAME}
  - {harness_path}/{HARNESS_RUNDIR_DIRNAME}/{HARNESS_SIM_LOG_FILENAME}
  - {harness_path}/{HARNESS_RUNDIR_DIRNAME}/{HARNESS_AGENT_REPORT_FILENAME}
- Edit ONLY files under:
  {MY_AGENT_DIRNAME}/{AGENT_FILES_DIRNAME}/{staged_problem}/{staged_issue}/{RTL_DIRNAME}/
- Do NOT modify any file under:
  {harness_path}
- Do not modify before/ originals.
- Keep edits minimal, compile-safe first.
- Use sim.log first-error lines as primary guidance.
- Target dataset difficulty: {problem_difficulty}.
- In your final response, include a line exactly like: Iteration count: `<N>` which 
  tells that how many times the codex was executed

Attempt: {attempt}/{max_retries}
"""
    if fail_context:
        return base + "\nPrevious failure context:\n" + fail_context + "\n"
    return base


def run_codex_once(repo_root: Path, prompt: str) -> subprocess.CompletedProcess:
    log_codex("Invoking codex exec")
    cmd = [*CODEX_EXEC_CMD, str(repo_root)]
    proc = subprocess.Popen(
        cmd,
        cwd=str(repo_root),
        text=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )

    assert proc.stdout is not None
    assert proc.stdin is not None
    proc.stdin.write(prompt)
    proc.stdin.close()

    start = time.time()
    out_lines: List[str] = []

    # Stream output live while enforcing timeout.
    import select

    timed_out = False
    emitted_stream_banner = False

    def _handle_stream_line(raw_line: str) -> None:
        nonlocal emitted_stream_banner
        if raw_line.strip() == CODEX_STREAM_BANNER:
            if not emitted_stream_banner:
                log_codex("Stream output started")
                emitted_stream_banner = True
            return
        print(raw_line, end="", flush=True)

    while True:
        if proc.poll() is not None:
            # Drain any buffered remaining output.
            rest = proc.stdout.read()
            if rest:
                for part in rest.splitlines(True):
                    _handle_stream_line(part)
                out_lines.append(rest)
            break

        if (time.time() - start) > CODEX_TIMEOUT_SEC:
            timed_out = True
            proc.kill()
            break

        ready, _, _ = select.select([proc.stdout], [], [], 0.2)
        if ready:
            line = proc.stdout.readline()
            if line:
                _handle_stream_line(line)
                out_lines.append(line)

    if timed_out:
        # Use 124 as timeout sentinel return code.
        return subprocess.CompletedProcess(cmd, CODEX_TIMEOUT_RETURN_CODE, "".join(out_lines), "")

    rc = proc.wait()
    return subprocess.CompletedProcess(cmd, rc, "".join(out_lines), "")


def run_local_eval(repo_root: Path, harness_path: Path) -> subprocess.CompletedProcess:
    shell_path = resolve_shell_path()
    cmd = [
        shell_path,
        "-lc",
        f". {shlex.quote(str(repo_root / AGENT_ENV_DIRNAME / BIN_DIRNAME / ACTIVATE_SCRIPT_NAME))} && "
        f"./{MY_AGENT_DIRNAME}/run_local_eval.sh {shlex.quote(str(harness_path))}",
    ]
    return run_cmd(cmd, cwd=repo_root)


def run_post_benchmark(
    repo_root: Path,
    harness_path: Path,
    pipeline_start_epoch: int,
    batch_run_ts: str,
    codex_iteration_count: Optional[int],
    codex_token_usage: Dict[str, Optional[int]],
) -> subprocess.CompletedProcess:
    shell_path = resolve_shell_path()
    codex_reporting_env = build_codex_reporting_env_exports(codex_iteration_count, codex_token_usage)
    cmd = [
        shell_path,
        "-lc",
        f". {shlex.quote(str(repo_root / AGENT_ENV_DIRNAME / BIN_DIRNAME / ACTIVATE_SCRIPT_NAME))} && "
        f"export {AGENT_PIPELINE_START_EPOCH_ENV}={pipeline_start_epoch} && "
        f"export {AGENT_BATCH_TS_ENV}={shlex.quote(batch_run_ts)} && "
        f"export {AGENT_MANAGED_PROBLEM_LOG_ENV}=1 && "
        f"{codex_reporting_env}"
        f"./{MY_AGENT_DIRNAME}/run_local_eval_batch.sh {shlex.quote(str(repo_root))} --harness {shlex.quote(str(harness_path))}",
    ]
    return run_cmd(cmd, cwd=repo_root)


def solve_problem(
    repo_root: Path,
    harness_path: Path,
    problem_difficulty: str,
    fixed_input_tokens: int,
    max_retries: int = 1,
) -> Tuple[bool, Optional[int], Dict[str, Optional[int]]]:
    if not ensure_local_eval_env(repo_root):
        log("Environment precheck failed: agent_env is missing pytest/cocotb deps.")
        return False, None, {
            "total_tokens": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "cached_tokens": 0,
        }

    fail_context = ""
    codex_iteration_count: Optional[int] = None
    codex_token_usage: Dict[str, Optional[int]] = {
        "total_tokens": fixed_input_tokens,
        "input_tokens": fixed_input_tokens,
        "output_tokens": 0,
        "cached_tokens": 0,
    }
    previous_prompt_text: Optional[str] = None
    for attempt in range(1, max_retries + 1):
        log(f"Step 1/2: Codex solve attempt {attempt}/{max_retries}")
        prompt = build_codex_prompt(
            harness_path,
            attempt,
            max_retries,
            problem_difficulty,
            fail_context,
        )
        codex = run_codex_once(repo_root, prompt)
        log(f"Codex exit code: {codex.returncode}")
        parsed_iteration_count = extract_codex_iteration_count(codex.stdout or "")
        if parsed_iteration_count is not None:
            codex_iteration_count = parsed_iteration_count
            log(f"Captured Codex iteration count: {codex_iteration_count}")
        estimated_token_usage = estimate_codex_token_usage(
            prompt_text=prompt,
            codex_output_text=(codex.stdout or ""),
            previous_prompt_text=previous_prompt_text,
        )
        parsed_token_usage = extract_codex_token_usage(codex.stdout or "")
        # input_tokens is intentionally fixed from the first prompt (pre-invocation) and never updated.
        output_value = estimated_token_usage.get("output_tokens") or 0
        parsed_output = parsed_token_usage.get("output_tokens")
        parsed_total = parsed_token_usage.get("total_tokens")
        fixed_input = int(codex_token_usage.get("input_tokens") or 0)
        if parsed_output is not None:
            output_value = int(parsed_output or 0)
        elif parsed_total is not None:
            output_value = max(int(parsed_total or 0) - fixed_input, 0)
        cached_value = estimated_token_usage.get("cached_tokens") or 0
        if parsed_token_usage.get("cached_tokens") is not None:
            cached_value = int(parsed_token_usage["cached_tokens"] or 0)
        codex_token_usage["output_tokens"] = int(codex_token_usage.get("output_tokens") or 0) + int(output_value)
        codex_token_usage["cached_tokens"] = int(codex_token_usage.get("cached_tokens") or 0) + int(cached_value)
        codex_token_usage["total_tokens"] = int(codex_token_usage["input_tokens"] or 0) + int(
            codex_token_usage["output_tokens"] or 0
        )
        previous_prompt_text = prompt
        if codex.returncode == CODEX_TIMEOUT_RETURN_CODE:
            log(
                f"Codex timed out after {CODEX_TIMEOUT_MINUTES} minutes. "
                f"Backing off for {CODEX_TIMEOUT_BACKOFF_SEC} seconds and moving to next attempt."
            )
            time.sleep(CODEX_TIMEOUT_BACKOFF_SEC)
            codex_tail = "\n".join((codex.stdout or "").splitlines()[-40:])
            fail_context = (
                f"codex_return_code=124\n"
                f"first_error=codex_timeout_{CODEX_TIMEOUT_MINUTES}m\n"
                f"codex_output_tail:\n{codex_tail}\n"
            )
            continue
        if codex.returncode != 0:
            log("Codex invocation failed; continuing to eval to capture concrete failure.")

        log("Step 2/2: Running local eval")
        ev = run_local_eval(repo_root, harness_path)
        log(f"Eval exit code: {ev.returncode}")
        if ev.stdout.strip():
            log("Eval output (tail):")
            print("\n".join(ev.stdout.splitlines()[-25:]), flush=True)

        if ev.returncode == 0:
            return True, codex_iteration_count, codex_token_usage

        sim_log = harness_path / HARNESS_RUNDIR_DIRNAME / HARNESS_SIM_LOG_FILENAME
        agent_report = harness_path / HARNESS_RUNDIR_DIRNAME / HARNESS_AGENT_REPORT_FILENAME
        eval_tail = "\n".join((ev.stdout or "").splitlines()[-40:])
        if "Missing Python deps in current environment." in (ev.stdout or ""):
            fail_context = (
                f"eval_return_code={ev.returncode}\n"
                "first_error=environment_python_deps_missing\n"
                f"eval_output_tail:\n{eval_tail}\n"
            )
        else:
            first_error = extract_first_error_from_sim_log(sim_log)
            fail_context = (
                f"eval_return_code={ev.returncode}\n"
                f"first_error={first_error}\n"
                f"sim_log_tail:\n{read_tail(sim_log, 80)}\n\n"
                f"agent_report_tail:\n{read_tail(agent_report, 80)}\n"
            )
        log("Attempt failed; prepared failure context for next Codex retry.")

    log(f"Max retries reached ({max_retries}); final status FAIL.")
    return False, codex_iteration_count, codex_token_usage


def main() -> None:
    try:
        indices, max_retries, save_log = parse_cli(sys.argv)
    except ValueError as exc:
        print(f"[Usage Error] Invalid command arguments. {exc}", file=sys.stderr)
        print_usage()
        sys.exit(2)
    repo_root = infer_repo_root()

    # Harness mode (invoked by run_local_eval.sh): no args means no-op report only.
    if indices is None:
        workspace = infer_harness_mode_workspace()
        if workspace is not None:
            log("Harness mode detected (no index argument).")
            write_harness_noop_report(workspace)
            log(f"Wrote no-op agent report: {workspace / HARNESS_RUNDIR_DIRNAME / HARNESS_AGENT_REPORT_FILENAME}")
            log("Harness mode complete.")
            return
        print_usage()
        sys.exit(2)

    batch_run_ts = time.strftime("%Y%m%d_%H%M%S")
    log(f"Batch report key for this agent.py run: {batch_run_ts}")
    is_batch_mode = len(indices) > 1
    batch_run_dir: Optional[Path] = None
    if is_batch_mode:
        batch_run_dir = ensure_batch_report_dir(repo_root, batch_run_ts)
        log(f"Batch report folder initialized: {batch_run_dir}")
        log("Batch mode detected: skipping work/run.log generation.")
    failed_indices: List[int] = []
    for idx in indices:
        if is_batch_mode:
            rc = _main_orchestrator(
                idx,
                max_retries,
                repo_root,
                batch_run_ts,
                batch_run_dir=batch_run_dir,
            )
            if rc != 0:
                failed_indices.append(idx)
            continue

        try:
            log_file, orig_stdout, orig_stderr = start_run_log(repo_root)
        except RuntimeError as exc:
            print(f"[Write Permission Error] Could not create/update work/run.log file. {exc}", file=sys.stderr)
            sys.exit(2)

        try:
            rc = _main_orchestrator(idx, max_retries, repo_root, batch_run_ts)
            if rc != 0:
                failed_indices.append(idx)
        finally:
            stop_run_log(log_file, orig_stdout, orig_stderr)
            if save_log:
                try:
                    archived = archive_run_log(repo_root, idx)
                    log(f"Archived run.log to: {archived}")
                except RuntimeError as exc:
                    print(
                        f"[Write Permission Error] Could not archive {RUN_LOG_FILENAME} to "
                        f"{WORK_DIRNAME}/{WORK_LOGS_DIRNAME}/. {exc}",
                        file=sys.stderr,
                    )
                except OSError as exc:
                    print(
                        f"[Write Permission Error] Could not archive {RUN_LOG_FILENAME} to "
                        f"{WORK_DIRNAME}/{WORK_LOGS_DIRNAME}/. {exc}",
                        file=sys.stderr,
                    )

    if failed_indices:
        print(
            f"[Run Summary] Completed with failures for dataset indices: {', '.join(str(i) for i in failed_indices)}",
            file=sys.stderr,
        )
        sys.exit(3)
    sys.exit(0)


def _main_orchestrator(
    idx: int,
    max_retries: int,
    repo_root: Path,
    batch_run_ts: str,
    batch_run_dir: Optional[Path] = None,
) -> int:
    pipeline_start_epoch = int(time.time())
    default_batch_log_name = f"run_index_{idx}.log"
    problem_log_file = None
    problem_log_stdout = None
    problem_log_stderr = None
    dataset_path = repo_root / DATASET_DIRNAME / DATASET_FILENAME
    if not dataset_path.exists():
        append_batch_index_log(batch_run_dir, default_batch_log_name, f"Dataset file not found: {dataset_path}")
        print(f"[Input File Error] Dataset file not found: {dataset_path}", file=sys.stderr)
        return 1

    log("Step A: Loading dataset entries")
    entries = load_dataset_entries(dataset_path)
    if not entries:
        append_batch_index_log(batch_run_dir, default_batch_log_name, f"Dataset file is empty: {dataset_path}")
        print(f"[Input File Error] Dataset file is empty: {dataset_path}", file=sys.stderr)
        return 1
    if idx < 1 or idx > len(entries):
        append_batch_index_log(
            batch_run_dir,
            default_batch_log_name,
            f"Index out of range: {idx}. Valid range: 1..{len(entries)}",
        )
        print(f"[Input Value Error] Index out of range: {idx}. Valid range: 1..{len(entries)}", file=sys.stderr)
        return 1

    entry = entries[idx - 1]
    entry_id = entry.get("id", "")
    problem_difficulty = infer_entry_difficulty(entry)
    if "_" not in entry_id:
        append_batch_index_log(batch_run_dir, default_batch_log_name, f"Invalid dataset id format: {entry_id}")
        print(f"[Input Format Error] Invalid dataset id format: {entry_id}. Expected <problem_name>_<harness_id>.", file=sys.stderr)
        return 1

    problem, issue = split_problem_and_issue(entry_id)
    batch_log_name = f"run_{problem}_{issue}.log"
    if batch_run_dir is not None:
        try:
            problem_log_file, problem_log_stdout, problem_log_stderr = start_problem_log(
                batch_run_dir, batch_log_name
            )
        except RuntimeError as exc:
            print(f"[Write Permission Error] Could not create batch problem log. {exc}", file=sys.stderr)
            return 1
    append_batch_index_log(batch_run_dir, batch_log_name, f"Starting index={idx}, dataset_id={entry_id}")
    try:
        try:
            harness_path = resolve_harness_path(repo_root, problem, issue)
        except FileNotFoundError as exc:
            append_batch_index_log(batch_run_dir, batch_log_name, f"Harness path resolution failed: {exc}")
            print(f"[Harness Error] Could not find the harness folder for this dataset id. {exc}", file=sys.stderr)
            return 1
        log(f"Selected dataset index {idx}: {entry_id}")
        log(f"Selected dataset difficulty: {problem_difficulty}")
        log(f"Resolved harness path: {harness_path}")
        try:
            source_rtl, staged_rtl = reset_staged_rtl_from_original(repo_root, harness_path, problem)
        except (OSError, FileNotFoundError) as exc:
            append_batch_index_log(batch_run_dir, batch_log_name, f"RTL reset failed: {exc}")
            print(f"[RTL Reset Error] Could not reset staged RTL from original source. {exc}", file=sys.stderr)
            return 1
        log(
            "Reset staged RTL from original source: "
            f"{source_rtl} -> {staged_rtl}"
        )

        solved = False
        codex_iteration_count: Optional[int] = None
        first_prompt = build_codex_prompt(
            harness_path,
            attempt=1,
            max_retries=max_retries,
            problem_difficulty=problem_difficulty,
            fail_context="",
        )
        fixed_input_tokens_for_index = token_count(first_prompt)
        log(f"Fixed input token baseline (first Codex prompt): {fixed_input_tokens_for_index}")
        codex_token_usage: Dict[str, Optional[int]] = {
            "total_tokens": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "cached_tokens": 0,
        }
        for run_cycle in range(1, MAX_SOLVE_RUN_CYCLES + 1):
            log(
                f"Run cycle {run_cycle}/{MAX_SOLVE_RUN_CYCLES}: "
                f"using max retries {max_retries}"
            )
            solved, cycle_iteration_count, cycle_token_usage = solve_problem(
                repo_root,
                harness_path,
                problem_difficulty=problem_difficulty,
                fixed_input_tokens=fixed_input_tokens_for_index,
                max_retries=max_retries,
            )
            if cycle_iteration_count is not None:
                codex_iteration_count = cycle_iteration_count
            # Keep input_tokens fixed from the first Codex cycle for this index.
            if int(codex_token_usage.get("input_tokens") or 0) == 0:
                codex_token_usage["input_tokens"] = int(cycle_token_usage.get("input_tokens") or 0)
            codex_token_usage["output_tokens"] = int(codex_token_usage.get("output_tokens") or 0) + int(
                cycle_token_usage.get("output_tokens") or 0
            )
            codex_token_usage["cached_tokens"] = int(codex_token_usage.get("cached_tokens") or 0) + int(
                cycle_token_usage.get("cached_tokens") or 0
            )
            codex_token_usage["total_tokens"] = int(codex_token_usage.get("input_tokens") or 0) + int(
                codex_token_usage.get("output_tokens") or 0
            )
            if solved:
                break
            if run_cycle < MAX_SOLVE_RUN_CYCLES:
                log(
                    f"Run cycle {run_cycle} reached max retries ({max_retries}) without PASS; "
                    "starting a fresh run cycle."
                )

        log("Step B: Running single-target local benchmark/report pipeline")
        bench = run_post_benchmark(
            repo_root,
            harness_path,
            pipeline_start_epoch,
            batch_run_ts,
            codex_iteration_count,
            codex_token_usage,
        )
        log(f"Benchmark pipeline exit code: {bench.returncode}")
        if bench.stdout.strip():
            log("Benchmark output (tail):")
            print("\n".join(bench.stdout.splitlines()[-30:]), flush=True)
        if bench.returncode != 0:
            append_batch_index_log(
                batch_run_dir,
                batch_log_name,
                f"Benchmark pipeline failed with exit code {bench.returncode}",
            )
            print("[Permission Error] Could not generate final report files.", file=sys.stderr)
            return 1

        final_status = "PASS" if solved else "FAIL"
        append_batch_index_log(batch_run_dir, batch_log_name, f"Completed with status={final_status}")
        log(
            f"Step C: Complete.Target problem final status: {final_status}\n"
            f"Location of Original RTL Files : {source_rtl}\n"
            f"Location of Created/Modified RTL Files : {staged_rtl}"
        )
        return 0 if solved else 3
    finally:
        if problem_log_file is not None and problem_log_stdout is not None and problem_log_stderr is not None:
            stop_run_log(problem_log_file, problem_log_stdout, problem_log_stderr)


if __name__ == "__main__":
    main()
