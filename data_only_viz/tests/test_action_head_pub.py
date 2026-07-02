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
        self.persons_face = []
        self.persons_face_ids = []
        self._lock = threading.RLock()

    def lock(self):
        return self._lock


def _make_smplx_person(pid: int, seed: int = 0) -> dict:
    """Build a legacy dict-format person (backward-compat test fixture)."""
    rng = np.random.default_rng(seed)
    return {"pid": pid, "v3d": rng.normal(size=(10475, 3)).astype(np.float32)}


def _make_real_smplx_person(pid: int, seed: int = 0):
    """Build a real SMPLXPerson dataclass (as emitted by multi_hmr_worker)."""
    from data_only_viz.state import SMPLXPerson
    rng = np.random.default_rng(seed)
    return SMPLXPerson(
        pid=pid,
        vertices_3d=rng.normal(size=(10475, 3)).astype(np.float32),
        expression=np.zeros(10, dtype=np.float32),
    )


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


# ---------------------------------------------------------------------------
# Task-3 tests: _emit_hands wired into _tick
# ---------------------------------------------------------------------------

def _fake_hand_21(seed: int = 0, c: float = 1.0):
    """Return a list of 21 landmark-like objects with .x .y .c attrs.

    Wrist (slot 0) at (0.3, 0.6) and middle-MCP (slot 9) at (0.3, 0.45)
    so hand_plausible passes: size=0.15 > 0.02, c=1.0 >= 0.45, in-frame.
    """
    import types
    rng = __import__("random").Random(seed)
    lm = [
        types.SimpleNamespace(x=rng.random() * 0.4 + 0.2,
                              y=rng.random() * 0.4 + 0.2, c=c)
        for _ in range(21)
    ]
    lm[0] = types.SimpleNamespace(x=0.3, y=0.6, c=c)    # wrist in frame
    lm[9] = types.SimpleNamespace(x=0.3, y=0.45, c=c)   # middle-MCP, size=0.15
    return lm


def test_emit_hands_called_once_per_tick_with_hands(monkeypatch) -> None:
    """`bridge.send_hands` must be called once per tick with L/R/dist keys."""
    monkeypatch.setenv("HAND_PERSIST_FRAMES", "1")  # instant establishment
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    state.persons_hands = [_fake_hand_21(0)]
    state.persons_smplx = [_make_smplx_person(0)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    bridge.send_hands.assert_called_once()
    feats, _t = bridge.send_hands.call_args[0]
    assert set(feats.keys()) >= {"L", "R", "dist"}
    # One hand present → L is populated, R is None
    assert feats["L"] is not None
    assert feats["R"] is None
    assert isinstance(feats["dist"], float)


def test_emit_hands_called_once_per_tick_empty() -> None:
    """`bridge.send_hands` still called once when persons_hands is empty."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    state.persons_hands = []
    state.persons_smplx = [_make_smplx_person(0)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    bridge.send_hands.assert_called_once()
    feats, _t = bridge.send_hands.call_args[0]
    assert set(feats.keys()) >= {"L", "R", "dist"}
    assert feats["L"] is None
    assert feats["R"] is None
    assert feats["dist"] == 0.0


def test_emit_hands_single_person_fallback_sends_once() -> None:
    """Single-person fallback (hands_present=True + left/right_hand_kp) → send_hands once."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    # No per-person hands list; exercise the single-person fallback branch.
    state.persons_hands = []
    state.hands_present = True
    state.left_hand_kp = _fake_hand_21(0)
    state.right_hand_kp = _fake_hand_21(1)
    state.persons_smplx = [_make_smplx_person(0)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    bridge.send_hands.assert_called_once()


def test_emit_hands_once_for_two_pids() -> None:
    """Two pids in persons_smplx → send_hands called exactly once, not once per pid."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    state.persons_smplx = [_make_smplx_person(0), _make_smplx_person(1)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)

    assert bridge.send_hands.call_count == 1


# ---------------------------------------------------------------------------
# B3 contract: real SMPLXPerson dataclass (multi_hmr_worker output)
# ---------------------------------------------------------------------------

def test_publisher_smplx_real_dataclass_emits_osc() -> None:
    """SMPLXPerson dataclass (vertices_3d, not v3d) must not raise AttributeError."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_smplx = [_make_real_smplx_person(7)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    actions = bridge.send_action.call_args_list
    assert len(actions) == 1
    assert actions[0].kwargs.get("pid", actions[0].args[0]) == 7
    bridge.send_enter.assert_called_with(pid=7)


def test_publisher_smplx_real_dataclass_expression_used() -> None:
    """Expression from SMPLXPerson.expression (ndarray) must not crash."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    p = _make_real_smplx_person(0)
    p.expression = np.ones(10, dtype=np.float32) * 0.5
    state.persons_smplx = [p]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    bridge.send_action.assert_called_once()


def test_publisher_dict_format_still_works() -> None:
    """Legacy dict format {"pid": ..., "v3d": ...} must remain supported."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    state.persons_smplx = [_make_smplx_person(99)]
    state.smplx_last_t = 1.0
    pub._tick(t_now=0.0)
    actions = bridge.send_action.call_args_list
    assert len(actions) == 1
    assert actions[0].kwargs.get("pid", actions[0].args[0]) == 99


# ---------------------------------------------------------------------------
# Gesture validation: feature path requires established hands (spec test d)
# ---------------------------------------------------------------------------

def test_emit_hands_features_require_establishment(monkeypatch) -> None:
    """(d) _emit_hands yields None for hands not yet established, non-None after.

    Ghost = plausible hand present for 1-2 ticks only (never established).
    Real  = same plausible hand held for HAND_PERSIST_FRAMES ticks.
    """
    monkeypatch.setenv("HAND_PERSIST_FRAMES", "3")
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)

    good_hand = _fake_hand_21(0)
    state.persons_hands = [good_hand]
    state.persons_smplx = [_make_smplx_person(0)]

    # Ticks 1-2: hand count < 3 → not yet established → features are None
    for t in range(1, 3):
        state.smplx_last_t = float(t)
        pub._tick(t_now=float(t))
    feats_early, _ = bridge.send_hands.call_args_list[-1][0]
    assert feats_early["L"] is None   # not established yet

    # Tick 3: count reaches min_frames → established → features populated
    state.smplx_last_t = 3.0
    pub._tick(t_now=3.0)
    feats_est, _ = bridge.send_hands.call_args_list[-1][0]
    assert feats_est["L"] is not None  # now established


# ---------------------------------------------------------------------------
# Gesture slot status
# ---------------------------------------------------------------------------

def test_gesture_status_defaults_to_zero_with_no_hands() -> None:
    """With no hands, _update_gesture_slot_status() writes [0, 0]."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    state.gesture_slot_status = [99, 99]  # sentinel: should be overwritten
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    pub._update_gesture_slot_status()
    assert state.gesture_slot_status == [0, 0]


def test_gesture_status_armed_when_stab_active() -> None:
    """gesture_slot_status[slot]=2 when stabilizer output is non-None (arm state)."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    state.gesture_slot_status = [0, 0]
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    # Directly mark slot 0 as active in the stabilizer's output cache
    pub._stab._out[0] = object()
    pub._update_gesture_slot_status()
    assert state.gesture_slot_status[0] == 2, "armed slot must report status 2"
    assert state.gesture_slot_status[1] == 0, "idle slot must report status 0"


def test_gesture_status_engaged_when_pinch_active() -> None:
    """gesture_slot_status[slot]=3 when a pinch is engaged in that slot."""
    from data_only_viz.action_head_pub import ActionHeadPublisher
    state = _FakeState()
    state.gesture_slot_status = [0, 0]
    bridge = MagicMock()
    pub = ActionHeadPublisher(state, bridge, ckpt_path=None)
    pub._stab._out[1] = object()               # slot 1 armed
    pub._pinch_det._state[1][0].engaged = True  # slot 1 finger engaged
    pub._update_gesture_slot_status()
    assert state.gesture_slot_status[0] == 0, "slot 0: idle"
    assert state.gesture_slot_status[1] == 3, "slot 1: engaged pinch = status 3"
