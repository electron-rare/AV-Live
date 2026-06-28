"""Tests for the VIDEO_ROTATE frame rotation helper in multi.py."""
from __future__ import annotations

import numpy as np

from data_only_viz.multi import _apply_video_rotate


def _frame():
    """(2, 3, 3) BGR frame with a marker at the top-right corner (row0, col2)."""
    f = np.zeros((2, 3, 3), dtype=np.uint8)
    f[0, 2] = (9, 9, 9)
    return f


def test_none_is_identity():
    f = _frame()
    out = _apply_video_rotate(f, "none")
    assert out is f  # no copy when not rotating


def test_unknown_mode_is_identity():
    f = _frame()
    out = _apply_video_rotate(f, "garbage")
    assert out is f


def test_ccw_swaps_dims_and_moves_corner():
    f = _frame()  # h=2, w=3
    out = _apply_video_rotate(f, "ccw")
    assert out.shape == (3, 2, 3)            # w and h swapped
    # CCW: top-right corner -> top-left
    assert tuple(out[0, 0]) == (9, 9, 9)
    assert out.flags["C_CONTIGUOUS"]


def test_cw_swaps_dims_and_moves_corner():
    f = _frame()
    out = _apply_video_rotate(f, "cw")
    assert out.shape == (3, 2, 3)
    # CW: top-right corner -> bottom-right
    assert tuple(out[2, 1]) == (9, 9, 9)
    assert out.flags["C_CONTIGUOUS"]


def test_180_moves_corner_opposite():
    f = _frame()
    out = _apply_video_rotate(f, "180")
    assert out.shape == (2, 3, 3)            # dims preserved
    # 180: top-right corner -> bottom-left
    assert tuple(out[1, 0]) == (9, 9, 9)
    assert out.flags["C_CONTIGUOUS"]
