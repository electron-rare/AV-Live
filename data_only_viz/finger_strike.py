"""Air-piano finger strike detection from raw MediaPipe hand joints.

Mirrors hand_features.py conventions (L/R slotting by cx, finite-guarded
coordinate extraction). A "strike" is a fast downward motion of a fingertip
RELATIVE to its base knuckle, so translating the whole hand does not fire all
fingers. Output feeds the OSC /pose/finger route consumed by SuperCollider.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

from data_only_viz.hand_features import _clamp, _coord, _finite

# MediaPipe 21-kp hand: fingertip and base-knuckle indices per finger
# (thumb, index, middle, ring, pinky). Thumb base = ThumbMP (2).
FINGERTIPS: tuple[int, ...] = (4, 8, 12, 16, 20)
FINGER_BASES: tuple[int, ...] = (2, 5, 9, 13, 17)

# Pinch: thumb tip vs the 4 opposable finger tips (index..pinky).
THUMB_TIP: int = 4
WRIST: int = 0
MIDDLE_MCP: int = 9
PINCH_TIPS: tuple[int, ...] = (8, 12, 16, 20)


def order_hands_by_cx(hands: list, max_slots: int) -> list:
    """Return up to max_slots hand-landmark lists ordered leftmost-first
    (slot 0 = L), matching HandFeatureExtractor / FingerStrikeDetector."""
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
    return [lm for _cx, lm in cand[:max_slots]]


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


@dataclass
class PinchEvent:
    hand: int          # 0 = left slot (leftmost cx), 1 = right slot
    finger: int        # 1..4 = index, middle, ring, pinky (thumb is trigger)
    state: int = 1     # 1 = engage edge, 0 = release edge


class _PinchState:
    __slots__ = ("engaged", "last_t", "qual")

    def __init__(self) -> None:
        self.engaged: bool = False
        self.last_t: float = -1e9
        self.qual: int = 0        # consecutive qualifying frames (debounce)


class PinchDetector:
    """Edge-triggered thumb-to-finger pinch with hysteresis.

    Fires one PinchEvent when thumb tip contacts a finger tip (distance,
    normalized by hand size, drops below ratio_on). Re-arms only after the
    distance rises back above ratio_off, so one pinch = one event.
    """

    def __init__(self, ratio_on: float = 0.45, ratio_off: float = 0.65,
                 refractory_ms: float = 250.0, history_slots: int = 2,
                 margin: float = 0.20, ext_ratio: float = 1.35,
                 ext_min: int = 0, debounce_frames: int = 1) -> None:
        self.ratio_on = ratio_on
        self.ratio_off = ratio_off
        self.refractory_s = refractory_ms / 1000.0
        # Only the single nearest fingertip may engage, and only if it is at
        # least `margin` (in size-normalized units) nearer than the runner-up.
        # Rejects the adjacent-finger ambiguity when fingers curl together.
        self.margin = margin
        # Open-hand gate: the winner may engage only when at least ext_min
        # of the 3 non-pinching fingers are extended (tip-to-wrist distance
        # above ext_ratio hand-sizes). Rejects relaxed-hand/fist false
        # pinches during full-body play. ext_min=0 disables the gate; the
        # live defaults come from the PINCH_EXT_* env vars (action_head_pub),
        # constructor defaults preserve legacy behavior.
        self.ext_ratio = ext_ratio
        self.ext_min = int(ext_min)
        # Engage fires only after debounce_frames consecutive qualifying
        # frames; release stays immediate. 1 = no debounce. (Enforced in
        # step(); wired fully by the debounce task.)
        self.debounce_frames = max(1, int(debounce_frames))
        self._state = [[_PinchState() for _ in range(4)]
                       for _ in range(history_slots)]

    def step(self, hands: list, t_now: float) -> list[PinchEvent]:
        ordered = order_hands_by_cx(hands, len(self._state))
        present = set(range(len(ordered)))
        events: list[PinchEvent] = []
        for slot, lm in enumerate(ordered):
            tx = _finite(_coord(lm[THUMB_TIP], "x", 0), 0.5)
            ty = _finite(_coord(lm[THUMB_TIP], "y", 1), 0.5)
            wx = _finite(_coord(lm[WRIST], "x", 0), 0.5)
            wy = _finite(_coord(lm[WRIST], "y", 1), 0.5)
            mx = _finite(_coord(lm[MIDDLE_MCP], "x", 0), 0.5)
            my = _finite(_coord(lm[MIDDLE_MCP], "y", 1), 0.5)
            size = math.hypot(mx - wx, my - wy)
            size = size if size > 1e-4 else 1e-4
            ratios = []
            exts = []
            for tip_idx in PINCH_TIPS:
                fx = _finite(_coord(lm[tip_idx], "x", 0), 0.5)
                fy = _finite(_coord(lm[tip_idx], "y", 1), 0.5)
                ratios.append(math.hypot(fx - tx, fy - ty) / size)
                exts.append(math.hypot(fx - wx, fy - wy) / size)
            # closest-wins + margin: pick the single nearest fingertip, and treat
            # it as a pinch only if it is clearly nearer than the runner-up.
            order = sorted(range(4), key=lambda j: ratios[j])
            nearest, runner = order[0], order[1]
            # open-hand gate: a deliberate pinch keeps the other fingers
            # extended; a fist/relaxed hand has them curled at the wrist.
            open_ok = self.ext_min <= 0 or sum(
                1 for j in range(4)
                if j != nearest and exts[j] >= self.ext_ratio
            ) >= self.ext_min
            winner = nearest if (
                ratios[nearest] < self.ratio_on
                and (ratios[runner] - ratios[nearest]) >= self.margin
                and open_ok
            ) else -1
            for i in range(4):
                st = self._state[slot][i]
                if st.engaged:
                    # release when this finger opens, or another finger took over.
                    if i != winner or ratios[i] > self.ratio_off:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
                elif i == winner and (t_now - st.last_t) >= self.refractory_s:
                    # engage only after debounce_frames consecutive qualifying
                    # frames; release below stays edge-immediate.
                    st.qual += 1
                    if st.qual >= self.debounce_frames:
                        st.engaged = True
                        st.last_t = t_now
                        st.qual = 0
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=1))
                else:
                    st.qual = 0
        for slot in range(len(self._state)):
            if slot not in present:
                for i in range(4):
                    st = self._state[slot][i]
                    st.qual = 0
                    if st.engaged:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
        return events
