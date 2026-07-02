"""Turn MediaPipe hand landmarks into a compact expressive feature vector.

Mirrors the kinematics pattern of action_head.FeatureExtractor: a small ring
buffer per hand slot, finite-guarded, clamped to declared ranges. Output feeds
both the OSC /pose/hands route (audio) and the Metal renderer uniforms (visual).
"""
from __future__ import annotations
import math
from collections import deque

WRIST, THUMB_TIP, MIDDLE_MCP, PINKY_TIP = 0, 4, 9, 20

# index/middle/ring/pinky tips + their MCP knuckles, for the "all fingers
# curled" fist metric (thumb excluded — a fist curls the four fingers).
_FINGER_TIPS = (8, 12, 16, 20)
_FINGER_MCPS = (5, 9, 13, 17)

NEUTRAL_HAND = {"cx": 0.5, "cy": 0.5, "openness": 0.0, "speed": 0.0, "fist": 0.0}

# openness calibration: (span/size) maps fist~0.3 -> 0, open~2.0 -> 1
_OPEN_LO, _OPEN_HI = 0.5, 2.0
# fist calibration: per-finger tip->MCP distance / hand size. curled ~0.25,
# extended ~0.75. closedness = 1 at/below LO, 0 at/above HI.
_EXT_LO, _EXT_HI = 0.25, 0.75


def _finite(v: float, fallback: float) -> float:
    return v if isinstance(v, float) and math.isfinite(v) else fallback


def _coord(p, attr: str, idx: int, fallback: float = 0.5) -> float:
    """Extract a coordinate from a landmark object or an indexable row."""
    if hasattr(p, attr):
        return float(getattr(p, attr))
    try:
        return float(p[idx])
    except (TypeError, IndexError):
        return fallback


def _clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else hi if v > hi else v


class HandFeatureExtractor:
    def __init__(self, history: int = 5, fist_enable: bool | None = None):
        self._history = max(2, history)
        # two routed slots (hand_slots.route_hands): 0 = user's left (L),
        # 1 = user's right (R); cx fallback when chirality is absent.
        self._buf = [deque(maxlen=self._history), deque(maxlen=self._history)]
        # Master fist kill-switch: user-disabled live 2026-07-02 (too many
        # false held-fist actions). fist stays 0.0 for BOTH hands whatever
        # the per-slot fist_enabled kwarg says. FIST_ENABLE=1 re-enables.
        # TODO: migrate the env read to VizConfig once config.py is free.
        if fist_enable is None:
            import os
            fist_enable = os.environ.get("FIST_ENABLE", "0") not in (
                "0", "", "false", "False",
            )
        self._fist_enable = fist_enable

    def _features(self, lm: list) -> dict:
        xs = [_finite(_coord(p, "x", 0), 0.5) for p in lm[:21]]
        ys = [_finite(_coord(p, "y", 1), 0.5) for p in lm[:21]]
        # cx/cy anchor = the WRIST (kp 0), not the landmark centroid: the
        # centroid shifts when fingers open/pinch, cross-talking gestures
        # into the X/Y voice mods. The wrist decouples them (user request
        # live 2026-07-02).
        cx = _clamp(xs[WRIST], 0.0, 1.0)
        cy = _clamp(ys[WRIST], 0.0, 1.0)
        size = math.hypot(xs[MIDDLE_MCP] - xs[WRIST], ys[MIDDLE_MCP] - ys[WRIST])
        size = size if size > 1e-4 else 1e-4
        span = math.hypot(xs[THUMB_TIP] - xs[PINKY_TIP],
                          ys[THUMB_TIP] - ys[PINKY_TIP])
        openness = _clamp((span / size - _OPEN_LO) / (_OPEN_HI - _OPEN_LO),
                          0.0, 1.0)
        # fist = 1.0 only when ALL four fingers are curled to the palm (min over
        # fingers): one extended finger drops it toward 0, so a true fist is
        # required rather than just a small thumb-pinky span.
        fist = 1.0
        for tip, mcp in zip(_FINGER_TIPS, _FINGER_MCPS):
            ext = math.hypot(xs[tip] - xs[mcp], ys[tip] - ys[mcp]) / size
            curled = _clamp(1.0 - (ext - _EXT_LO) / (_EXT_HI - _EXT_LO), 0.0, 1.0)
            fist = min(fist, curled)
        return {"cx": cx, "cy": cy, "openness": openness, "fist": fist}

    def _speed(self, slot: int, cx: float, cy: float) -> float:
        buf = self._buf[slot]
        spd = 0.0
        if buf:
            px, py = buf[-1]
            spd = math.hypot(cx - px, cy - py)
        buf.append((cx, cy))
        return _clamp(spd, 0.0, 1.0)

    def step(self, hands: list, chirality=None, swap: bool = False,
             fist_enabled: tuple = (True, True), mirror: bool = False) -> dict:
        from data_only_viz.hand_slots import route_hands
        # swap must mirror the gesture path (HAND_SWAP_LR) or per-voice
        # L/R mods contradict pinch/strike in the same performance.
        # mirror must match state.mirror_2d so the cx fallback slot assignment
        # stays coherent with the renderer panel layout on chirality dropout.
        left_lm, right_lm = route_hands(hands, chirality, swap=swap, mirror=mirror)

        if left_lm is None and right_lm is None:
            self._buf[0].clear()
            self._buf[1].clear()
            return {"L": None, "R": None, "dist": 0.0}

        out_l = None
        out_r = None

        if left_lm is not None:
            lf = self._features(left_lm)
            if not (self._fist_enable and fist_enabled[0]):
                lf["fist"] = 0.0
            lf["speed"] = self._speed(0, lf["cx"], lf["cy"])
            out_l = lf
        else:
            self._buf[0].clear()

        if right_lm is not None:
            rf = self._features(right_lm)
            if not (self._fist_enable and fist_enabled[1]):
                rf["fist"] = 0.0
            rf["speed"] = self._speed(1, rf["cx"], rf["cy"])
            out_r = rf
        else:
            self._buf[1].clear()

        dist = 0.0
        if out_l is not None and out_r is not None:
            dist = _clamp(
                math.hypot(out_r["cx"] - out_l["cx"], out_r["cy"] - out_l["cy"]),
                0.0, 1.0,
            )

        return {"L": out_l, "R": out_r, "dist": dist}
