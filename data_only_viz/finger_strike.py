"""Air-piano finger strike detection from raw MediaPipe hand joints.

Mirrors hand_features.py conventions (L/R slotting by cx, finite-guarded
coordinate extraction). A "strike" is a fast downward motion of a fingertip
RELATIVE to its base knuckle, so translating the whole hand does not fire all
fingers. Output feeds the OSC /pose/finger route consumed by SuperCollider.
"""
from __future__ import annotations

from dataclasses import dataclass

from data_only_viz.hand_features import _clamp, _coord, _finite

# MediaPipe 21-kp hand: fingertip and base-knuckle indices per finger
# (thumb, index, middle, ring, pinky). Thumb base = ThumbMP (2).
FINGERTIPS: tuple[int, ...] = (4, 8, 12, 16, 20)
FINGER_BASES: tuple[int, ...] = (2, 5, 9, 13, 17)


@dataclass
class StrikeEvent:
    hand: int          # 0 = left slot (leftmost cx), 1 = right slot
    finger: int        # 0..4 = thumb, index, middle, ring, pinky
    strike_speed: float
    z: float
    tipx: float
    tipy: float


class _FingerState:
    __slots__ = ("prev_rel", "armed", "last_t")

    def __init__(self) -> None:
        self.prev_rel: float | None = None
        self.armed: bool = True
        self.last_t: float = -1e9


class FingerStrikeDetector:
    def __init__(self, vel_thresh: float = 0.02, refractory_ms: float = 120.0,
                 speed_scale: float = 0.10, history_slots: int = 2) -> None:
        self.vel_thresh = vel_thresh
        self.refractory_s = refractory_ms / 1000.0
        self.speed_scale = max(1e-6, speed_scale)
        # state[slot][finger]
        self._state = [[_FingerState() for _ in range(5)]
                       for _ in range(history_slots)]

    def _slot_hands(self, hands: list) -> list:
        """Validate and order hands leftmost-first (slot 0 = L), like
        HandFeatureExtractor. Returns up to 2 (cx, landmarks) ordered."""
        cand = []
        for lm in hands:
            try:
                if lm is None or len(lm) < 21:
                    continue
            except TypeError:
                continue
            xs = [_finite(_coord(p, "x", 0), 0.5) for p in lm[:21]]
            cx = _clamp(sum(xs) / len(xs), 0.0, 1.0)
            cand.append((cx, lm))
        cand.sort(key=lambda c: c[0])
        return cand[:len(self._state)]

    def step(self, hands: list, t_now: float) -> list[StrikeEvent]:
        ordered = self._slot_hands(hands)
        present = set(range(len(ordered)))
        events: list[StrikeEvent] = []
        for slot, (_cx, lm) in enumerate(ordered):
            for f in range(5):
                tip = lm[FINGERTIPS[f]]
                base = lm[FINGER_BASES[f]]
                tip_y = _finite(_coord(tip, "y", 1), 0.5)
                base_y = _finite(_coord(base, "y", 1), 0.5)
                rel = tip_y - base_y          # +down (image y grows downward)
                st = self._state[slot][f]
                if st.prev_rel is None:
                    st.prev_rel = rel
                    continue
                vel = rel - st.prev_rel       # +down velocity per frame
                st.prev_rel = rel
                if vel < 0.0:                 # lifting -> rearm
                    st.armed = True
                if (vel > self.vel_thresh and st.armed
                        and (t_now - st.last_t) >= self.refractory_s):
                    st.armed = False
                    st.last_t = t_now
                    events.append(StrikeEvent(
                        hand=slot, finger=f,
                        strike_speed=_clamp(vel / self.speed_scale, 0.0, 1.0),
                        z=_finite(_coord(tip, "z", 2, 0.0), 0.0),
                        tipx=_finite(_coord(tip, "x", 0), 0.5),
                        tipy=tip_y,
                    ))
        # reset slots not present this tick so re-entry does not spike
        for slot in range(len(self._state)):
            if slot not in present:
                for f in range(5):
                    self._state[slot][f].prev_rel = None
                    self._state[slot][f].armed = True
        return events
