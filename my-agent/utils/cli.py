#!/usr/bin/env python3

import re
import sys
from typing import List, Optional, Tuple
from utils.constants import DEFAULT_RETRIES, MAX_ALLOWED_RETRIES


def print_usage() -> None:
    print(
        "Usage:\n"
        "  python3 my-agent/agent.py                                     (harness no-op mode)\n"
        "  python3 my-agent/agent.py -i <index> [--max-retries N] [--save_log]\n"
        "  python3 my-agent/agent.py -i \"[start,end]\" [--max-retries N] [--save_log]\n"
        "  python3 my-agent/agent.py --index <index> [--max-retries N] [--save_log]\n\n"
        "  python3 my-agent/agent.py --index-range <start> <end> [--max-retries N] [--save_log]\n\n"
        "Options:\n"
        "  --index, -i <index>       1-based dataset index, or bracket range \"[start,end]\"\n"
        "  --index-range <s> <e>     Inclusive 1-based dataset range\n"
        "  --max-retries, -r N       Retry limit for Codex solve loop (default: 8, max: 17)\n"
        "  --save_log, -s            Archive work/run.log to work/logs/run_<unix>__<index>.log\n",
        file=sys.stderr,
    )


def parse_cli(argv: List[str]) -> Tuple[Optional[List[int]], int, bool]:
    if len(argv) <= 1:
        return None, DEFAULT_RETRIES, False

    def _parse_positive_int(token: str, label: str) -> int:
        if not token.isdigit():
            raise ValueError(f"Invalid {label} value: {token}. Expected a positive integer.")
        return int(token)

    def _parse_index_spec(spec: str) -> Tuple[int, int]:
        text = spec.strip()
        if text.isdigit():
            value = int(text)
            return value, value

        bracket_match = re.fullmatch(r"\[(\d+)\s*,\s*(\d+)\]", text)
        if bracket_match:
            start = int(bracket_match.group(1))
            end = int(bracket_match.group(2))
            if start > end:
                raise ValueError(f"Invalid range {text}. Start must be <= end.")
            return start, end

        raise ValueError(
            f"Invalid index value: {spec}. Expected a positive integer or bracket range like [1,122]."
        )

    index_range: Optional[Tuple[int, int]] = None
    max_retries = DEFAULT_RETRIES
    save_log = False
    i = 1
    while i < len(argv):
        token = argv[i]

        if token in ("--help", "-h"):
            print_usage()
            sys.exit(0)

        if token in ("--max-retries", "-r"):
            if i + 1 >= len(argv):
                raise ValueError("Missing value for --max-retries.")
            value_token = argv[i + 1]
            max_retries = _parse_positive_int(value_token, "--max-retries")
            i += 2
            continue

        if token.startswith("--max-retries="):
            value_token = token.split("=", 1)[1]
            max_retries = _parse_positive_int(value_token, "--max-retries")
            i += 1
            continue

        if token in ("--save_log", "-s"):
            save_log = True
            i += 1
            continue

        if token in ("--index", "-i"):
            if index_range is not None:
                raise ValueError("Index was already provided. Use only one of --index/-i or --index-range.")
            if i + 1 >= len(argv):
                raise ValueError(f"Missing value for {token}.")
            index_range = _parse_index_spec(argv[i + 1])
            i += 2
            continue

        if token == "--index-range":
            if index_range is not None:
                raise ValueError("Index was already provided. Use only one of --index/-i or --index-range.")
            if i + 2 >= len(argv):
                raise ValueError("Missing values for --index-range. Expected: --index-range <start> <end>.")
            start = _parse_positive_int(argv[i + 1], "index-range start")
            end = _parse_positive_int(argv[i + 2], "index-range end")
            if start > end:
                raise ValueError(f"Invalid --index-range {start}..{end}. Start must be <= end.")
            index_range = (start, end)
            i += 3
            continue

        raise ValueError(f"Unexpected argument: {token}")

    if max_retries < 1:
        raise ValueError(f"Invalid --max-retries: {max_retries}. Minimum allowed value is 1.")
    if max_retries > MAX_ALLOWED_RETRIES:
        raise ValueError(
            f"Invalid --max-retries: {max_retries}. Maximum allowed value is {MAX_ALLOWED_RETRIES}."
        )

    if index_range is None:
        raise ValueError(
            "Missing required index. Use --index <N>, -i <N>, -i \"[start,end]\", or --index-range <start> <end>."
        )

    start, end = index_range
    return list(range(start, end + 1)), max_retries, save_log
