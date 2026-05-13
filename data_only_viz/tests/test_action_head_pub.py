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
