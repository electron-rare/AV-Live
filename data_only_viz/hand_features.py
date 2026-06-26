"""Turn MediaPipe hand landmarks into a compact expressive feature vector.

Mirrors the kinematics pattern of action_head.FeatureExtractor: a small ring
buffer per hand slot, finite-guarded, clamped to declared ranges. Output feeds
both the OSC /pose/hands route (audio) and the Metal renderer uniforms (visual).
"""
from __future__ import annotations
import math
from collections import deque

WRIST, THUMB_TIP, MIDDLE_MCP, PINKY_TIP = 0, 4, 9, 20

NEUTRAL_HAND = {"cx": 0.5, "cy": 0.5, "openness": 0.0, "speed": 0.0}

# openness calibration: (span/size) maps fist~0.3 -> 0, open~2.0 -> 1
_OPEN_LO, _OPEN_HI = 0.5, 2.0


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
    def __init__(self, history: int = 5):
        self._history = max(2, history)
        # two screen slots: 0 = leftmost (L), 1 = rightmost (R)
        self._buf = [deque(maxlen=self._history), deque(maxlen=self._history)]

    def _features(self, lm: list) -> dict:
        xs = [_finite(_coord(p, "x", 0), 0.5) for p in lm[:21]]
        ys = [_finite(_coord(p, "y", 1), 0.5) for p in lm[:21]]
        cx = _clamp(sum(xs) / len(xs), 0.0, 1.0)
        cy = _clamp(sum(ys) / len(ys), 0.0, 1.0)
        size = math.hypot(xs[MIDDLE_MCP] - xs[WRIST], ys[MIDDLE_MCP] - ys[WRIST])
        size = size if size > 1e-4 else 1e-4
        span = math.hypot(xs[THUMB_TIP] - xs[PINKY_TIP],
                          ys[THUMB_TIP] - ys[PINKY_TIP])
        openness = _clamp((span / size - _OPEN_LO) / (_OPEN_HI - _OPEN_LO),
                          0.0, 1.0)
        return {"cx": cx, "cy": cy, "openness": openness}

    def _speed(self, slot: int, cx: float, cy: float) -> float:
        buf = self._buf[slot]
        spd = 0.0
        if buf:
            px, py = buf[-1]
            spd = math.hypot(cx - px, cy - py)
        buf.append((cx, cy))
        return _clamp(spd, 0.0, 1.0)

    def step(self, hands: list) -> dict:
        feats = []
        for lm in hands:
            try:
                valid = lm is not None and len(lm) >= 21
            except TypeError:
                continue
            if valid:
                feats.append(self._features(lm))
        if not feats:
            self._buf[0].clear()
            self._buf[1].clear()
            return {"L": None, "R": None, "dist": 0.0}
        feats.sort(key=lambda f: f["cx"])           # leftmost first
        left = feats[0]
        right = feats[-1] if len(feats) > 1 else None
        left["speed"] = self._speed(0, left["cx"], left["cy"])
        out_l = left
        out_r = None
        dist = 0.0
        if right is not None:
            right["speed"] = self._speed(1, right["cx"], right["cy"])
            out_r = right
            dist = _clamp(math.hypot(right["cx"] - left["cx"],
                                     right["cy"] - left["cy"]), 0.0, 1.0)
        else:
            self._buf[1].clear()
        return {"L": out_l, "R": out_r, "dist": dist}
