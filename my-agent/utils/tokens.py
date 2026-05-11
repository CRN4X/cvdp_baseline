#!/usr/bin/env python3

import math
import re
from typing import Dict, Optional
from utils.constants import TOKEN_PARSE_PATTERNS, TOKENIZER_ENCODING_NAME

try:
    import tiktoken  # type: ignore
except ImportError:
    tiktoken = None

_TOKENIZER = None


def extract_codex_iteration_count(text: str) -> Optional[int]:
    patterns = (
        r"iteration count:\s*`?(\d+)`?",
        r"iterations?:\s*`?(\d+)`?",
        r"iteration_count:\s*`?(\d+)`?",
    )
    for pattern in patterns:
        matches = re.findall(pattern, text, flags=re.IGNORECASE)
        if matches:
            return int(matches[-1])
    return None


def extract_codex_token_usage(text: str) -> Dict[str, Optional[int]]:
    usage: Dict[str, Optional[int]] = {
        "total_tokens": None,
        "input_tokens": None,
        "output_tokens": None,
        "cached_tokens": None,
    }

    def _to_int(raw: str) -> int:
        return int(raw.replace(",", "").strip())

    for key, key_patterns in TOKEN_PARSE_PATTERNS.items():
        for pattern in key_patterns:
            matches = re.findall(pattern, text, flags=re.IGNORECASE)
            if matches:
                usage[key] = _to_int(matches[-1])
                break

    return usage


def _get_tokenizer():
    global _TOKENIZER
    if _TOKENIZER is not None:
        return _TOKENIZER
    if tiktoken is None:
        return None
    try:
        _TOKENIZER = tiktoken.get_encoding(TOKENIZER_ENCODING_NAME)
    except Exception:
        _TOKENIZER = None
    return _TOKENIZER


def token_count(text: str) -> int:
    tokenizer = _get_tokenizer()
    if tokenizer is not None:
        try:
            return len(tokenizer.encode(text))
        except Exception:
            pass
    # Fallback heuristic when tokenizer is unavailable.
    return int(math.ceil(len(text) / 4.0))


def _common_prefix_token_count(a: str, b: str) -> int:
    tokenizer = _get_tokenizer()
    if tokenizer is not None:
        try:
            ta = tokenizer.encode(a)
            tb = tokenizer.encode(b)
            i = 0
            lim = min(len(ta), len(tb))
            while i < lim and ta[i] == tb[i]:
                i += 1
            return i
        except Exception:
            pass
    # Fallback heuristic via character prefix.
    max_len = min(len(a), len(b))
    i = 0
    while i < max_len and a[i] == b[i]:
        i += 1
    return int(math.ceil(i / 4.0))


def estimate_codex_token_usage(
    prompt_text: str,
    codex_output_text: str,
    previous_prompt_text: Optional[str],
) -> Dict[str, Optional[int]]:
    input_tokens = token_count(prompt_text)
    output_tokens = token_count(codex_output_text)
    cached_tokens = 0
    if previous_prompt_text:
        cached_tokens = min(
            input_tokens,
            _common_prefix_token_count(previous_prompt_text, prompt_text),
        )
    return {
        "total_tokens": input_tokens + output_tokens,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cached_tokens": cached_tokens,
    }
