"""Tests for ActionHeadPublisher."""
from __future__ import annotations

import threading
from unittest.mock import MagicMock

import numpy as np
import pytest

torch = pytest.importorskip("torch")


class _FakeState:
    def __init__(self) -> None:
        self.persons_smplx = []
        self.smplx_last_t = 0.0
        self.persons_body3d = []
        self.persons_body_ids = []
        self.pose_last_t = 0.0
        self.persons_hands = []
        self.persons_hands_ids = []
<<<<<<< HEAD
<<<<<<< HEAD
        self.persons_face = []
        self.persons_face_ids = []
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
        self.persons_face = []
        self.persons_face_ids = []
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        self._lock = threading.RLock()

    def lock(self):
        return self._lock


def _make_smplx_person(pid: int, seed: int = 0) -> dict:
    rng = np.random.default_rng(seed)
    return {"pid": pid, "v3d": rng.normal(size=(10475, 3)).astype(np.float32)}


def test_publisher_smplx_source_emits_osc() -> None:
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_smplx = [_make_smplx_person(7)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    actions = [c for c in bridge.send_action.call_args_list]
    assert len(actions) == 1
    assert actions[0].kwargs.get("pid", actions[0].args[0]) == 7
    bridge.send_enter.assert_called_with(pid=7)


def test_publisher_falls_back_to_mediapipe_body3d() -> None:
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_body3d = [[(0.1 * i, 0.2 * i, 0.3 * i) for i in range(33)]]
    state.persons_body_ids = [42]
    state.pose_last_t = 1.0
    pub._tick(t_now=0.0)
    bridge.send_action.assert_called_once()
    bridge.send_enter.assert_called_with(pid=42)


def test_publisher_purges_lost_pid() -> None:
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_smplx = [_make_smplx_person(1)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    bridge.reset_mock()
    state.persons_smplx = []
    state.smplx_last_t = 2.0
    state.persons_body3d = []
    pub._tick(t_now=1.0)
    bridge.send_leave.assert_called_with(pid=1)


def test_publisher_no_double_emit_same_timestamp() -> None:
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_smplx = [_make_smplx_person(1)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    bridge.reset_mock()
    pub._tick(t_now=1.0)  # same smplx_last_t
    bridge.send_action.assert_not_called()


def test_publisher_uses_face_lips_for_mouth_open() -> None:
    """mouth_open from MediaPipe lip landmarks (idx 13 and 14) must be ~1.0."""
    from unittest.mock import patch
    from data_only_viz.action_head_pub import ActionHeadPublisher, MEDIAPIPE_LIP_UPPER_INNER, MEDIAPIPE_LIP_LOWER_INNER
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    # Build a fake face landmark list: at least 15 landmarks.
    # idx 13 = upper inner (y=0), idx 14 = lower inner (y=1), rest zeros.
    face_kps = [(0.0, 0.0, 0.0)] * 15
    face_kps[MEDIAPIPE_LIP_UPPER_INNER] = (0.0, 0.0, 0.0)
    face_kps[MEDIAPIPE_LIP_LOWER_INNER] = (1.0, 0.0, 0.0)  # 1m apart in x
    state.persons_face = [face_kps]
    state.persons_face_ids = [0]

    captured_mouth: list[float] = []
    original_step = pub.head.step

    def spy_step(pid, j3d, expr=None, mouth_open=0.0, hands_kp=None):
        captured_mouth.append(mouth_open)
        return original_step(pid, j3d, expr=expr, mouth_open=mouth_open, hands_kp=hands_kp)

    pub.head.step = spy_step  # type: ignore[method-assign]

    state.persons_smplx = [_make_smplx_person(0)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    assert len(captured_mouth) == 1
    assert abs(captured_mouth[0] - 1.0) < 1e-5


def test_publisher_passes_hands_kp_to_step() -> None:
    """hands_kp of shape (42, 3) must be passed to head.step."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    # Two 21-kp hand arrays (left + right) for pid=0.
    rng = np.random.default_rng(7)
    left_kps = rng.normal(size=(21, 3)).astype(np.float32)
    right_kps = rng.normal(size=(21, 3)).astype(np.float32)
    # persons_hands flat list: [left, right], ids both 0 (same pid).
    state.persons_hands = [left_kps, right_kps]
    state.persons_hands_ids = [0, 0]

    captured_hands: list = []
    original_step = pub.head.step

    def spy_step(pid, j3d, expr=None, mouth_open=0.0, hands_kp=None):
        captured_hands.append(hands_kp)
        return original_step(pid, j3d, expr=expr, mouth_open=mouth_open, hands_kp=hands_kp)

    pub.head.step = spy_step  # type: ignore[method-assign]

    state.persons_smplx = [_make_smplx_person(0)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    assert len(captured_hands) == 1
    assert captured_hands[0] is not None
    assert captured_hands[0].shape == (42, 3)
