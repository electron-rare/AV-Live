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


def _pub_envs(monkeypatch, finger_piano: str, pinch_enable: str):
    """Build a publisher with both gates set independently."""
    monkeypatch.setenv("FINGER_PIANO", finger_piano)
    monkeypatch.setenv("PINCH_ENABLE", pinch_enable)
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.02")
    monkeypatch.setenv("FINGER_STRIKE_REFRACTORY_MS", "120")
    from data_only_viz.action_head_pub import ActionHeadPublisher
    pub = ActionHeadPublisher.__new__(ActionHeadPublisher)
    pub.state = _FakeState()
    pub.bridge = MagicMock()
    pub._init_finger_piano()
    return pub


def test_emit_pinch_fires_when_pinch_enabled(monkeypatch):
    # PINCH_ENABLE on, FINGER_PIANO off -> pinches still emit (decoupled).
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    pub._pinch_det = MagicMock()
    pub._pinch_det.step.return_value = [MagicMock(hand=0, finger=1)]
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_pinch(0.0)
    assert pub.bridge.send_pinch.called


def test_emit_pinch_off_when_pinch_disabled_even_with_finger_piano(monkeypatch):
    # Decouple: FINGER_PIANO on but PINCH_ENABLE off -> no pinch emitted.
    pub = _pub_envs(monkeypatch, finger_piano="1", pinch_enable="0")
    pub._pinch_det = MagicMock()
    pub._pinch_det.step.return_value = [MagicMock(hand=0, finger=1)]
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_pinch(0.0)
    assert not pub.bridge.send_pinch.called


def test_emit_fingers_off_when_only_pinch_enabled(monkeypatch):
    # Decouple: PINCH_ENABLE on, FINGER_PIANO off -> air-piano stays silent.
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    pub.state.persons_hands = [_hand(0.40)]
    pub._emit_fingers(0.00)
    pub.state.persons_hands = [_hand(0.46)]
    pub._emit_fingers(0.04)
    assert not pub.bridge.send_finger.called


def test_pinch_gate_env_plumbing(monkeypatch):
    monkeypatch.setenv("PINCH_EXT_RATIO", "1.5")
    monkeypatch.setenv("PINCH_EXT_MIN", "3")
    monkeypatch.setenv("PINCH_DEBOUNCE_FRAMES", "5")
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    assert pub._pinch_det.ext_ratio == 1.5
    assert pub._pinch_det.ext_min == 3
    assert pub._pinch_det.debounce_frames == 5


def test_pinch_gate_env_defaults_are_strict(monkeypatch):
    # Live defaults: gate ON (2 extended fingers) + 3-frame debounce.
    for k in ("PINCH_EXT_RATIO", "PINCH_EXT_MIN", "PINCH_DEBOUNCE_FRAMES"):
        monkeypatch.delenv(k, raising=False)
    pub = _pub_envs(monkeypatch, finger_piano="0", pinch_enable="1")
    assert pub._pinch_det.ext_ratio == 1.35
    assert pub._pinch_det.ext_min == 2
    assert pub._pinch_det.debounce_frames == 3
