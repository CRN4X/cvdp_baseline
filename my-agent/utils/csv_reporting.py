#!/usr/bin/env python3

from typing import Dict, Optional
from utils.constants import AGENT_CODEX_ITERATION_COUNT_ENV, TOKEN_ENV_MAPPING


def build_codex_reporting_env_exports(
    codex_iteration_count: Optional[int],
    codex_token_usage: Dict[str, Optional[int]],
) -> str:
    parts = []
    if codex_iteration_count is None:
        parts.append(f"unset {AGENT_CODEX_ITERATION_COUNT_ENV}")
    else:
        parts.append(f"export {AGENT_CODEX_ITERATION_COUNT_ENV}={codex_iteration_count}")

    for token_key, env_key in TOKEN_ENV_MAPPING.items():
        value = codex_token_usage.get(token_key)
        if value is None:
            parts.append(f"unset {env_key}")
        else:
            parts.append(f"export {env_key}={value}")

    return " && ".join(parts) + " && "
