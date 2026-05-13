"""Tests for j3d augmentations."""
from __future__ import annotations

import numpy as np

WINDOW_LEN = 16


def _sample_stack(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(WINDOW_LEN, 32, 3)).astype(np.float32)


def test_mirror_swap_left_right_joints() -> None:
    from data_only_viz.training.augment import mirror_x, MIRROR_MAP
    x = _sample_stack(0)
    y = mirror_x(x)
    # Check output shape
    assert y.shape == (WINDOW_LEN, 32, 3)
    # x-coords are negated after reindexing
    assert np.allclose(y[..., 0], -x[:, list(MIRROR_MAP), :][:, :, 0], atol=1e-6)


def test_noise_within_sigma() -> None:
    from data_only_viz.training.augment import add_noise
    rng = np.random.default_rng(0)
    x = _sample_stack(0)
    y = add_noise(x, sigma=0.01, rng=rng)
    diff = y - x
    assert np.allclose(diff.std(), 0.01, atol=2e-3)


def test_time_stretch_keeps_shape() -> None:
    from data_only_viz.training.augment import time_stretch
    x = _sample_stack(0)
    y = time_stretch(x, factor=0.9, rng=None)
    assert y.shape == x.shape


def test_rotate_y_preserves_distances() -> None:
    from data_only_viz.training.augment import rotate_y
    x = _sample_stack(0)
    y = rotate_y(x, angle_rad=0.3)
    d_x = np.linalg.norm(x[0, 0] - x[0, 1])
    d_y = np.linalg.norm(y[0, 0] - y[0, 1])
    assert abs(d_x - d_y) < 1e-5
