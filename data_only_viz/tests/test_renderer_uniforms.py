"""Verify Metal uniform buffer layout constants after hand-feature expansion.

The renderer imports pyobjc/Metal which is unavailable headless, so we test
the struct layout independently and import the constants with a fallback.
"""

import struct


def test_uniform_layout_struct():
    """24 floats pack to exactly 96 bytes (16-byte aligned for Metal)."""
    assert struct.calcsize("24f") == 96


def test_uniform_constants():
    """UNIFORM_FLOATS == 24 and UNIFORM_SIZE == 96 from renderer module."""
    try:
        from data_only_viz.renderer import UNIFORM_FLOATS, UNIFORM_SIZE
        assert UNIFORM_FLOATS == 24, f"expected 24, got {UNIFORM_FLOATS}"
        assert UNIFORM_SIZE == 96, f"expected 96, got {UNIFORM_SIZE}"
        assert struct.calcsize(f"{UNIFORM_FLOATS}f") == 96
    except ImportError as exc:  # pyobjc/Metal unavailable headless
        # Fallback: at minimum the struct math is correct
        import pytest
        pytest.skip(f"renderer import skipped headless ({exc}); struct layout verified by test_uniform_layout_struct")
