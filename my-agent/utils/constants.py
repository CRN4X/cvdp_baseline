#!/usr/bin/env python3

CODEX_TIMEOUT_SEC = 1200  # 20 minutes per Codex attempt
CODEX_TIMEOUT_MINUTES = CODEX_TIMEOUT_SEC // 60
CODEX_TIMEOUT_BACKOFF_SEC = 10
MAX_SOLVE_RUN_CYCLES = 2  # If max retries are exhausted, start one fresh run cycle

DEFAULT_RETRIES = 8
MAX_ALLOWED_RETRIES = 17

UTF8_ENCODING = "utf-8"

# Repository paths / names
WORK_DIRNAME = "work"
RUN_LOG_FILENAME = "run.log"
WORK_LOGS_DIRNAME = "logs"
DATASET_DIRNAME = "dataset"
DATASET_FILENAME = "hackathon-agentic-obfuscated_final_corrected.jsonl"
MY_AGENT_DIRNAME = "my-agent"
AGENT_FILES_DIRNAME = "agent_files"
BATCH_REPORTS_DIRNAME = "batch_reports"
AGENT_ENV_DIRNAME = "agent_env"
BIN_DIRNAME = "bin"
PYTHON_BIN_NAME = "python"
ACTIVATE_SCRIPT_NAME = "activate"

# Harness paths / files
HARNESS_DIRNAME = "harness"
HARNESS_RUNDIR_DIRNAME = "rundir"
HARNESS_PROMPT_FILENAME = "prompt.json"
HARNESS_SIM_LOG_FILENAME = "sim.log"
HARNESS_AGENT_REPORT_FILENAME = "agent_report.json"
RTL_DIRNAME = "rtl"
RTL_ORIG_DIRNAME = "rtl.orig"
BEFORE_DIRNAME = "before"
TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S"
NOOP_AGENT_NAME = "my-hw-agent"
NOOP_MODE = "harness_noop"
NOOP_STATUS = "success"
NOOP_MESSAGE = "No-op in harness mode; external Codex loop performs edits."

# Runtime shells / env
ENV_WORKSPACE_ROOT = "CVDP_WORKSPACE_ROOT"
ENV_SHELL = "SHELL"
SHELL_CANDIDATES = ("zsh", "bash", "sh")
DEFAULT_SHELL_PATH = "/bin/sh"
LOCAL_EVAL_IMPORT_CHECK = "import pytest, cocotb, cocotb_tools.runner; print('ok')"

# Difficulty categories
LEARNING_DIFFICULTIES = ("easy", "medium", "hard")
DEFAULT_LEARNING_DIFFICULTY = "medium"

# Log parsing
SIM_ERROR_PATTERNS = ("error:", "FAILED", "AssertionError", "Traceback", "No module named")

# Codex CLI
CODEX_STREAM_BANNER = "codex"
CODEX_EXEC_CMD = ("codex", "exec", "-", "--skip-git-repo-check", "-C")
CODEX_TIMEOUT_RETURN_CODE = 124

# Tokenization
TOKENIZER_ENCODING_NAME = "cl100k_base"
TOKEN_PARSE_PATTERNS = {
    "input_tokens": (
        r"input tokens:\s*([0-9][0-9,]*)",
        r"tokens input:\s*([0-9][0-9,]*)",
    ),
    "output_tokens": (
        r"output tokens:\s*([0-9][0-9,]*)",
        r"tokens output:\s*([0-9][0-9,]*)",
    ),
    "cached_tokens": (
        r"cached tokens:\s*([0-9][0-9,]*)",
        r"cache(?:d)? tokens:\s*([0-9][0-9,]*)",
    ),
    "total_tokens": (
        r"total tokens:\s*([0-9][0-9,]*)",
        r"tokens used\s*\n\s*([0-9][0-9,]*)",
        r"tokens used:\s*([0-9][0-9,]*)",
    ),
}

# CSV reporting env
TOKEN_ENV_MAPPING = {
    "total_tokens": "AGENT_CODEX_TOTAL_TOKENS",
    "input_tokens": "AGENT_CODEX_INPUT_TOKENS",
    "output_tokens": "AGENT_CODEX_OUTPUT_TOKENS",
    "cached_tokens": "AGENT_CODEX_CACHED_TOKENS",
}
AGENT_CODEX_ITERATION_COUNT_ENV = "AGENT_CODEX_ITERATION_COUNT"
AGENT_PIPELINE_START_EPOCH_ENV = "AGENT_PIPELINE_START_EPOCH"
AGENT_BATCH_TS_ENV = "AGENT_BATCH_TS"
AGENT_MANAGED_PROBLEM_LOG_ENV = "AGENT_MANAGED_PROBLEM_LOG"
