"""Tests for rule-based auto-labeler."""
from __future__ import annotations

import numpy as np

from data_only_viz.action_head import WINDOW_LEN


def _static_seated(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Hip low (y small), knee bent ~80°."""
    frames = []
    for _ in range(frame_count):
        f = np.zeros((32, 3), dtype=np.float32)
        f[1] = [-0.1, 0.4, 0.0]
        f[2] = [0.1, 0.4, 0.0]
        f[4] = [-0.1, 0.4, 0.3]
        f[5] = [0.1, 0.4, 0.3]
        f[7] = [-0.1, 0.1, 0.3]
        f[8] = [0.1, 0.1, 0.3]
        frames.append(f)
    return frames


def _static_standing(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Hip high, knees ~180°."""
    frames = []
    for _ in range(frame_count):
        f = np.zeros((32, 3), dtype=np.float32)
        f[1] = [-0.1, 0.9, 0.0]
        f[2] = [0.1, 0.9, 0.0]
        f[4] = [-0.1, 0.5, 0.0]
        f[5] = [0.1, 0.5, 0.0]
        f[7] = [-0.1, 0.1, 0.0]
        f[8] = [0.1, 0.1, 0.0]
        frames.append(f)
    return frames


def _dancing(frame_count: int = WINDOW_LEN) -> list[np.ndarray]:
    """Standing pose with high wrist velocity."""
    base = _static_standing(1)[0]
    frames = []
    for t in range(frame_count):
        f = base.copy()
        phase = 2 * np.pi * t * 0.125  # 0.125 = 1/8, slower oscillation
        f[20] = base[20] + np.array([np.sin(phase) * 0.5, np.cos(phase) * 0.5, 0])
        f[21] = base[21] + np.array(
            [-np.sin(phase) * 0.5, np.cos(phase) * 0.5, 0]
        )
        frames.append(f.astype(np.float32))
    return frames


def test_autolabel_static_standing_is_debout() -> None:
    from data_only_viz.training.autolabel import autolabel_window

    label, conf = autolabel_window(_static_standing())
    assert label == "debout"
    assert conf >= 0.5


def test_autolabel_static_seated_is_assise() -> None:
    from data_only_viz.training.autolabel import autolabel_window

    label, conf = autolabel_window(_static_seated())
    assert label == "assise"
    assert conf >= 0.5


def test_autolabel_dancing_is_danse() -> None:
    from data_only_viz.training.autolabel import autolabel_window

    label, conf = autolabel_window(_dancing())
    assert label == "danse"
    assert conf >= 0.5


def test_autolabel_ambiguous_is_none() -> None:
    from data_only_viz.training.autolabel import autolabel_window

    base = _static_standing(WINDOW_LEN)
    for t, f in enumerate(base):
        f[20, 0] += 0.01 * np.sin(t)
    label, _conf = autolabel_window(base)
    assert label in ("debout", None)
