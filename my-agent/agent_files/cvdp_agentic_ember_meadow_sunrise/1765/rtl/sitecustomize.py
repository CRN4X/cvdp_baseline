"""Local test harness compatibility patch.

This module is auto-imported by Python when present on PYTHONPATH.
It patches cocotb_tools to allow bare SV defines passed as None.
"""

from __future__ import annotations


def _patch_cocotb_define_serializer() -> None:
    try:
        import cocotb_tools.runner as runner  # type: ignore
    except Exception:
        return

    orig = getattr(runner, "_as_sv_literal", None)
    if not callable(orig):
        return

    def _as_sv_literal_compat(value):
        if value is None:
            # Treat bare macro defines as enabled.
            return "1"
        return orig(value)

    runner._as_sv_literal = _as_sv_literal_compat


_patch_cocotb_define_serializer()
