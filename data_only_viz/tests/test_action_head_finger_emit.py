"""ActionHeadPublisher emits /pose/finger when FINGER_PIANO is enabled."""
from __future__ import annotations

import threading
import pytest
from unittest.mock import MagicMock

from data_only_viz.finger_strike import FINGERTIPS, FINGER_BASES


class _FakeState:
    def __init__(self) -> None:
        self.persons_hands = []
        self.mirror_2d = False
        self._lock = threading.RLock()

    def lock(self):
        return self._lock


class _Kp:
    """Landmark with .x .y .c attrs and index fallback for _coord."""
    __slots__ = ("x", "y", "z", "c")

    def __init__(self, x: float, y: float, z: float = 0.0, c: float = 1.0) -> None:
        self.x, self.y, self.z, self.c = x, y, z, c

    def __getitem__(self, i: int) -> float:
        return (self.x, self.y, self.z)[i]

    def __len__(self) -> int:
        return 3


def _hand(index_tip_y: float, base_y: float = 0.4, c: float = 1.0):
    lm = [_Kp(0.3, base_y, 0.0, c) for _ in range(21)]
    lm[0] = _Kp(0.3, base_y + 0.15, 0.0, c)   # wrist 0.15 below center -> hand_size 0.15
    lm[9] = _Kp(0.3, base_y, 0.0, c)            # middle-MCP at center -> size 0.15 > near_min
    lm[FINGERTIPS[1]] = _Kp(0.3, index_tip_y, 0.0, c)
    lm[FINGER_BASES[1]] = _Kp(0.3, base_y, 0.0, c)
    # Spread index-MCP(5) and pinky-MCP(17) AFTER FINGER_BASES[1]=5 assignment
    # so lm[5] is not overwritten. facing = 0.12/0.15 = 0.8 >= face_min=0.5.
    # Only x changes; y=base_y is preserved so FingerStrikeDetector base_y is correct.
    lm[5] = _Kp(0.3 - 0.06, base_y, 0.0, c)
    lm[17] = _Kp(0.3 + 0.06, base_y, 0.0, c)
    return lm


def _pub(monkeypatch, enabled: bool):
    monkeypatch.setenv("FINGER_PIANO", "1" if enabled else "0")
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.02")
    monkeypatch.setenv("FINGER_STRIKE_REFRACTORY_MS", "120")
    # Instant establishment so legacy strike/pinch tests need no warmup ticks.
    monkeypatch.setenv("HAND_PERSIST_FRAMES", "1")
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
    # Instant establishment so legacy tests need no warmup ticks.
    monkeypatch.setenv("HAND_PERSIST_FRAMES", "1")
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
    assert pub._pinch_det.ext_min == 1   # 1 since 2026-07-02 (inner-finger fix)
    assert pub._pinch_det.debounce_frames == 3


# ---------------------------------------------------------------------------
# Item 1a: mirror_2d coherence — _emit_hands passes mirror to extractor
# ---------------------------------------------------------------------------

def _make_hand_row(cx: float, c: float = 1.0) -> list:
    """21 _Kp landmarks with enough geometry for features."""
    lm = [_Kp(cx, 0.5, 0.0, c) for _ in range(21)]
    lm[0] = _Kp(cx, 0.6, 0.0, c)   # wrist
    lm[9] = _Kp(cx, 0.45, 0.0, c)  # middle-MCP -> hand_size 0.15 > near threshold
    return lm


def test_emit_hands_mirror_2d_flips_cx_slot_assignment(monkeypatch):
    """With state.mirror_2d=True, the cx fallback in _emit_hands assigns
    the RIGHT-screen hand to the L slot — coherent with the mirrored renderer."""
    from data_only_viz.hand_features import HandFeatureExtractor
    pub = _pub(monkeypatch, enabled=False)
    pub._hand_ext = HandFeatureExtractor()   # not set by _pub/_init_finger_piano

    h_low_cx  = _make_hand_row(0.2)   # screen-left
    h_high_cx = _make_hand_row(0.8)   # screen-right
    pub.state.persons_hands = [h_low_cx, h_high_cx]
    # No chirality -> cx fallback path
    # (persons_hands_chirality absent -> getattr returns None -> [] -> None)

    # Without mirror: screen-left (cx=0.2) -> slot L
    pub.state.mirror_2d = False
    pub._emit_hands(0.0)
    feats_plain = pub.state.hand_feats
    assert feats_plain["L"] is not None
    assert feats_plain["L"]["cx"] == pytest.approx(0.2, abs=0.05)

    # With mirror: cx fallback flips -> screen-right (cx=0.8) -> slot L
    pub.state.mirror_2d = True
    pub._emit_hands(0.0)
    feats_mirror = pub.state.hand_feats
    assert feats_mirror["L"] is not None
    assert feats_mirror["L"]["cx"] == pytest.approx(0.8, abs=0.05)


# ---------------------------------------------------------------------------
# Gesture input validation tests (spec: a, b, c, e, f)
# ---------------------------------------------------------------------------

def _pub_gate(monkeypatch, persist_frames: int = 3, conf_min: str = "0.45"):
    """Build a publisher with explicit gate params, finger + pinch enabled."""
    monkeypatch.setenv("FINGER_PIANO", "1")
    monkeypatch.setenv("PINCH_ENABLE", "1")
    monkeypatch.setenv("FINGER_STRIKE_VEL", "0.001")   # very sensitive
    monkeypatch.setenv("FINGER_STRIKE_REFRACTORY_MS", "0")
    monkeypatch.setenv("HAND_PERSIST_FRAMES", str(persist_frames))
    monkeypatch.setenv("HAND_CONF_MIN", conf_min)
    from data_only_viz.action_head_pub import ActionHeadPublisher
    pub = ActionHeadPublisher.__new__(ActionHeadPublisher)
    pub.state = _FakeState()
    pub.bridge = MagicMock()
    pub._init_finger_piano()
    return pub


def test_gesture_gate_blocks_low_confidence_hand(monkeypatch):
    """(a) c=0.1 < HAND_CONF_MIN=0.45: plausibility gate blocks hand before detectors."""
    pub = _pub_gate(monkeypatch, persist_frames=1, conf_min="0.45")
    low_hand = _hand(0.40, c=0.1)
    for _ in range(10):
        pub.state.persons_hands = [low_hand]
        pub._emit_fingers(0.0)
        pub._emit_pinch(0.0)
    assert not pub.bridge.send_finger.called
    assert not pub.bridge.send_pinch.called


def test_gesture_gate_plausible_hand_needs_min_frames(monkeypatch):
    """(b) Plausible hand feeds gestures only after HAND_PERSIST_FRAMES ticks."""
    pub = _pub_gate(monkeypatch, persist_frames=3)
    good = _hand(0.40)  # c=1.0, plausible

    # Ticks 1 and 2: gate count < min_frames → hand not established → no slot
    for _ in range(2):
        pub.state.persons_hands = [good]
        pub._emit_fingers(0.0)
    assert not pub.bridge.send_finger.called

    # Tick 3: established; move finger to trigger a strike
    pub.state.persons_hands = [good]
    pub._emit_fingers(0.0)     # prime with hand in slot
    pub.state.persons_hands = [_hand(0.50)]
    pub._emit_fingers(0.1)
    assert pub.bridge.send_finger.called


def test_gesture_gate_1_frame_ghost_never_fires(monkeypatch):
    """(c) A confident ghost appearing for only 1-2 frames never triggers anything."""
    pub = _pub_gate(monkeypatch, persist_frames=3)
    ghost = _hand(0.40)  # c=1.0 but short-lived

    # One-frame flash then absence
    pub.state.persons_hands = [ghost]
    pub._emit_fingers(0.0)
    pub.state.persons_hands = []
    pub._emit_fingers(0.1)
    assert not pub.bridge.send_finger.called

    # Two-frame flash then absence
    pub.state.persons_hands = [ghost]
    pub._emit_fingers(0.2)
    pub._emit_fingers(0.3)   # count=2 still < 3
    pub.state.persons_hands = []
    pub._emit_fingers(0.4)
    assert not pub.bridge.send_finger.called


def test_gesture_gate_mediapipe_hand_passes_through(monkeypatch):
    """(e) MediaPipe c=1.0 hand passes plausibility gate and fires gestures normally."""
    pub = _pub_gate(monkeypatch, persist_frames=1, conf_min="0.45")
    mp_hand = _hand(0.40)   # c=1.0, models MediaPipe c=1.0 landmark
    pub.state.persons_hands = [mp_hand]
    pub._emit_fingers(0.00)          # prime (established on first tick: min_frames=1)
    pub.state.persons_hands = [_hand(0.50)]
    pub._emit_fingers(0.10)          # strike
    assert pub.bridge.send_finger.called


def test_gesture_gate_chirality_aligned_after_plausibility_mask(monkeypatch):
    """(f) Invalid(idx=0) + valid(idx=1, chir=1) → only right slot filled."""
    import time as _time
    monkeypatch.setenv("HAND_PERSIST_FRAMES", "1")
    monkeypatch.setenv("HAND_CONF_MIN", "0.45")
    monkeypatch.setenv("FINGER_SOURCE", "iphone")
    monkeypatch.setenv("FINGER_PIANO", "0")
    monkeypatch.setenv("PINCH_ENABLE", "0")
    from data_only_viz.action_head_pub import ActionHeadPublisher

    class _FakeStateIphone(_FakeState):
        def __init__(self) -> None:
            super().__init__()
            self.persons_hands_iphone: list = []
            self.persons_hands_iphone_t: float = 0.0
            self.persons_hands_chirality: list = []

    pub = ActionHeadPublisher.__new__(ActionHeadPublisher)
    pub.state = _FakeStateIphone()
    pub.bridge = MagicMock()
    pub._init_finger_piano()

    invalid = _hand(0.40, c=0.1)   # low-conf → filtered by plausibility gate
    valid   = _hand(0.40, c=1.0)   # passes gate

    pub.state.persons_hands_iphone = [invalid, valid]
    pub.state.persons_hands_chirality = [0, 1]   # invalid=left, valid=right
    pub.state.persons_hands_iphone_t = _time.perf_counter()

    slotted = pub._step_stab()

    # invalid (chir=0) was removed before route_hands; valid (chir=1) → slot R
    assert slotted[0] is None      # left slot empty
    assert slotted[1] is not None  # right slot has valid hand
