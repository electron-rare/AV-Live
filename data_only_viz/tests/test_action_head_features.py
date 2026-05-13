"""Unit tests for ActionHead feature extraction and buffers."""
from __future__ import annotations

import numpy as np
import pytest


def test_module_imports() -> None:
    from data_only_viz import action_head
    assert hasattr(action_head, "FeatureExtractor")
    assert hasattr(action_head, "PerPersonBuffer")
    assert hasattr(action_head, "ActionHead")
    assert action_head.WINDOW_LEN == 16
    assert action_head.J3D_JOINTS == 22
    assert action_head.NUM_CLASSES == 3
    assert action_head.LABELS == ("debout", "assise", "danse")


def _rand_j3d(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(22, 3)).astype(np.float32)


def test_buffer_starts_empty() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    assert len(buf) == 0
    assert buf.frames_for(7) == []


def test_buffer_append_grows_per_pid() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    buf.append(pid=1, j3d=_rand_j3d(1))
    buf.append(pid=1, j3d=_rand_j3d(2))
    buf.append(pid=2, j3d=_rand_j3d(3))
    assert len(buf.frames_for(1)) == 2
    assert len(buf.frames_for(2)) == 1


def test_buffer_max_len_16() -> None:
    from data_only_viz.action_head import PerPersonBuffer, WINDOW_LEN
    buf = PerPersonBuffer()
    for i in range(WINDOW_LEN + 5):
        buf.append(pid=1, j3d=_rand_j3d(i))
    assert len(buf.frames_for(1)) == WINDOW_LEN


def test_buffer_forget_releases_pid() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    buf.append(pid=1, j3d=_rand_j3d(0))
    buf.forget(1)
    assert buf.frames_for(1) == []
    assert len(buf) == 0


def test_buffer_rejects_bad_shape() -> None:
    from data_only_viz.action_head import PerPersonBuffer
    buf = PerPersonBuffer()
    with pytest.raises(ValueError, match="22"):
        buf.append(pid=1, j3d=np.zeros((17, 3), dtype=np.float32))


def test_feature_extractor_shape_full_buffer() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, FEATURE_DIM
    frames = [_rand_j3d(i) for i in range(WINDOW_LEN)]
    feat = FeatureExtractor.from_buffer(frames)
    assert feat.shape == (FEATURE_DIM,)
    assert feat.dtype == np.float32
    assert not np.isnan(feat).any()


def test_feature_extractor_short_buffer_pads() -> None:
    from data_only_viz.action_head import FeatureExtractor, FEATURE_DIM
    frames = [_rand_j3d(0), _rand_j3d(1), _rand_j3d(2)]
    feat = FeatureExtractor.from_buffer(frames)
    assert feat.shape == (FEATURE_DIM,)


def test_feature_extractor_static_buffer_zero_velocity() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, J3D_JOINTS
    static = _rand_j3d(42)
    frames = [static.copy() for _ in range(WINDOW_LEN)]
    feat = FeatureExtractor.from_buffer(frames)
    vel_block = feat[J3D_JOINTS * 3 : J3D_JOINTS * 3 * 2]
    assert np.allclose(vel_block, 0.0, atol=1e-6)


def test_feature_extractor_kinetics_speed_and_accel() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN
    frames = []
    for t in range(WINDOW_LEN):
        f = np.zeros((22, 3), dtype=np.float32)
        f[0, 0] = 0.1 * t
        frames.append(f)
    kin = FeatureExtractor.kinetics(frames)
    assert kin.shape == (3,)
    assert kin[0] > 0
    assert abs(kin[0] - 0.1 / 22) < 1e-4
    assert abs(kin[1]) < 1e-4


def test_feature_extractor_symmetry_sign() -> None:
    from data_only_viz.action_head import FeatureExtractor, WINDOW_LEN, WRIST_LEFT, WRIST_RIGHT
    frames = []
    for t in range(WINDOW_LEN):
        f = np.zeros((22, 3), dtype=np.float32)
        f[WRIST_LEFT, 0] = 0.05 * t
        f[WRIST_RIGHT, 0] = -0.05 * t
        frames.append(f)
    kin = FeatureExtractor.kinetics(frames)
    assert kin[2] > 0.9
