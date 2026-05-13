"""Sanity tests for MediaPipe offline extractor (no MediaPipe runtime -- we
mock the landmarker and feed synthetic landmarks)."""
from __future__ import annotations

from types import SimpleNamespace

import numpy as np
import pytest


def test_build_j3d32_combines_body_and_fingertips() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _build_j3d32
    from data_only_viz.action_head import J3D_JOINTS
    body3d = np.linspace(0, 1, 33 * 3).reshape(33, 3).astype(np.float32)
    hands_kp42 = np.linspace(2, 3, 42 * 3).reshape(42, 3).astype(np.float32)
    j3d = _build_j3d32(body3d, hands_kp42)
    assert j3d is not None
    assert j3d.shape == (J3D_JOINTS, 3)
    # The body22 portion comes from body3d via MEDIAPIPE_TO_22.
    # The fingertip portion (indices 22..31) comes from hands_kp at idx 4,8,12,16,20.
    assert np.allclose(j3d[22], hands_kp42[4])
    assert np.allclose(j3d[26], hands_kp42[20])
    assert np.allclose(j3d[27], hands_kp42[21 + 4])
    assert np.allclose(j3d[31], hands_kp42[21 + 20])


def test_build_j3d32_returns_none_when_no_body() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _build_j3d32
    j3d = _build_j3d32(None, np.zeros((42, 3), dtype=np.float32))
    assert j3d is None


def test_hands_kp42_combines_left_right_sides() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _hands_kp42
    left = np.linspace(0, 1, 21 * 3).reshape(21, 3).astype(np.float32)
    right = np.linspace(2, 3, 21 * 3).reshape(21, 3).astype(np.float32)
    out = _hands_kp42(left, right)
    assert out.shape == (42, 3)
    assert np.allclose(out[:21], left)
    assert np.allclose(out[21:], right)


def test_hands_kp42_zero_pads_when_missing() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _hands_kp42
    left = np.ones((21, 3), dtype=np.float32)
    out = _hands_kp42(left, None)
    assert np.allclose(out[:21], left)
    assert np.allclose(out[21:], 0.0)


def test_mouth_open_from_face_lips() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _mouth_open
    # MediaPipe FaceMesh has 478 landmarks. Build a sparse array : zero
    # everywhere except idx 13 (upper inner) and idx 14 (lower inner),
    # 1 metre apart on the y axis.
    face = np.zeros((478, 3), dtype=np.float32)
    face[13] = [0.0, 1.0, 0.0]
    face[14] = [0.0, 0.0, 0.0]
    assert abs(_mouth_open(face) - 1.0) < 1e-6


def test_mouth_open_returns_zero_on_empty_face() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _mouth_open
    assert _mouth_open(None) == 0.0
    assert _mouth_open(np.zeros((10, 3), dtype=np.float32)) == 0.0


def test_lmk_list_to_array_round_trip() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _lmk_list_to_array
    class _Lmk:
        def __init__(self, x: float, y: float, z: float) -> None:
            self.x = x; self.y = y; self.z = z
    lmks = [_Lmk(i, 2 * i, 3 * i) for i in range(5)]
    arr = _lmk_list_to_array(lmks)
    assert arr is not None
    assert arr.shape == (5, 3)
    assert np.allclose(arr[2], [2.0, 4.0, 6.0])


def test_lmk_list_to_array_none_input() -> None:
    from data_only_viz.scripts.extract_mediapipe_offline import _lmk_list_to_array
    assert _lmk_list_to_array(None) is None
