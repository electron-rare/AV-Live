"""ActionHeadPublisher emits /pose/finger when FINGER_PIANO is enabled."""
from __future__ import annotations

import threading
from unittest.mock import MagicMock

from data_only_viz.finger_strike import FINGERTIPS, FINGER_BASES


class _FakeState:
    def __init__(self) -> None:
        self.persons_hands = []
        self._lock = threading.RLock()

    def lock(self):
        return self._lock


def _hand(index_tip_y: float, base_y: float = 0.4):
    lm = [[0.3, base_y, 0.0] for _ in range(21)]
    lm[FINGERTIPS[1]] = [0.3, index_tip_y, 0.0]
    lm[FINGER_BASES[1]] = [0.3, base_y, 0.0]
    return lm


def _pub(monkeypatch, enabled: bool):
    monkeypatch.setenv("FINGER_PIANO", "1" if enabled else "0")
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.02")
    monkeypatch.setenv("FINGER_STRIKE_REFRACTORY_MS", "120")
    from data_only_viz.action_head_pub import ActionHeadPublisher
    # bypass __init__ heavy ckpt load: construct then set only what we touch
    pub = ActionHeadPublisher.__new__(ActionHeadPublisher)
    pub.state = _FakeState()
    pub.bridge = MagicMock()
    pub._init_finger_piano()       # helper that reads env + builds detector
    return pub


def test_emit_fingers_fires_when_enabled(monkeypatch):
    pub = _pub(monkeypatch, enabled=True)
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_fingers(0.00)                 # prime
    pub.state.persons_hands = [_hand(0.46)] # downward strike
    pub._emit_fingers(0.04)
    assert pub.bridge.send_finger.called


def test_emit_fingers_noop_when_disabled(monkeypatch):
    pub = _pub(monkeypatch, enabled=False)
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_fingers(0.00)
    pub.state.persons_hands = [_hand(0.46)]
    pub._emit_fingers(0.04)
    assert not pub.bridge.send_finger.called
