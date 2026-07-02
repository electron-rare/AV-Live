"""Air-piano finger strike detection from pre-routed hand slots.

A "strike" is a fast downward motion of a fingertip RELATIVE to its base
knuckle, so translating the whole hand does not fire all fingers. Output feeds
the OSC /pose/finger route consumed by SuperCollider.

Consumers call route_hands() (hand_slots) once per tick and pass the resulting
2-element [left|None, right|None] list to FingerStrikeDetector.step() and
PinchDetector.step(). slot 0 = left hand (matrix "MG"), slot 1 = right.
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


@dataclass
class StrikeEvent:
    hand: int          # 0 = left slot, 1 = right slot
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

    def reset_slot(self, slot: int) -> None:
        """Clear per-finger prev_rel and re-arm for the given slot.

        Call this BEFORE step() when GestureSlotStabilizer.resumed_flags()
        reports a held -> real transition for that slot.  During a Vision hole
        the stabilizer replays the last hand (frozen coords, vel=0), but when
        the real hand returns within the hold window the first delta compresses
        several frames of motion into one large velocity spike, causing a
        phantom strike.  Clearing prev_rel makes the first real frame a
        no-op prime that restarts tracking from the new position.
        """
        for f in range(5):
            self._state[slot][f].prev_rel = None
            self._state[slot][f].armed = True

    def step(self, slotted: list, t_now: float) -> list[StrikeEvent]:
        """Process a pre-routed 2-slot hand list [left|None, right|None].

        Absent slots (None) reset their finger state so re-entry does not
        produce spurious velocity spikes.
        """
        events: list[StrikeEvent] = []
        for slot, lm in enumerate(slotted):
            if lm is None:
                for f in range(5):
                    self._state[slot][f].prev_rel = None
                    self._state[slot][f].armed = True
                continue
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
        return events


@dataclass
class PinchEvent:
    hand: int          # 0 = left slot, 1 = right slot
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
        # frames; release stays immediate. 1 = no debounce.
        self.debounce_frames = max(1, int(debounce_frames))
        self._state = [[_PinchState() for _ in range(4)]
                       for _ in range(history_slots)]

    def engaged_slots(self) -> tuple[bool, bool]:
        """Return (slot0_has_engaged_pinch, slot1_has_engaged_pinch)."""
        return (
            any(self._state[0][i].engaged for i in range(4)),
            any(self._state[1][i].engaged for i in range(4)),
        )

    def step(self, slotted: list, t_now: float) -> list[PinchEvent]:
        """Process a pre-routed 2-slot hand list [left|None, right|None].

        Absent slots synthesise release edges for any engaged fingers and
        reset debounce state.
        """
        events: list[PinchEvent] = []
        for slot, lm in enumerate(slotted):
            if lm is None:
                for i in range(4):
                    st = self._state[slot][i]
                    st.qual = 0
                    if st.engaged:
                        st.engaged = False
                        events.append(PinchEvent(hand=slot, finger=i + 1, state=0))
                continue
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
        return events
