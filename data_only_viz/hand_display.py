"""Pure geometry helpers for hand overlay filtering.

No Metal, no numpy, no pyobjc — safe to unit-test anywhere.
"""
from __future__ import annotations

import math
from typing import Protocol


class _HasXYC(Protocol):
    x: float
    y: float
    c: float


def hand_size(kp: list[_HasXYC]) -> float:
    """Euclidean distance wrist(0) -> middle-MCP(9) in normalised image units."""
    w = kp[0]
    m = kp[9]
    return math.hypot(m.x - w.x, m.y - w.y)


def hand_plausible(
    kp: list[_HasXYC],
    conf_min: float = 0.3,
    size_min: float = 0.02,
    size_max: float = 0.5,
) -> bool:
    """Return True if the hand landmark list looks like a real hand.

    Rejects:
    - fewer than 21 landmarks
    - size (wrist->middle-MCP) outside [size_min, size_max]
    - mean confidence below conf_min
    """
    if len(kp) < 21:
        return False
    size = hand_size(kp)
    if size < size_min or size > size_max:
        return False
    mean_c = sum(p.c for p in kp) / len(kp)
    if mean_c < conf_min:
        return False
    return True


def segment_ok(
    A: _HasXYC,
    B: _HasXYC,
    size: float,
    conf_min: float = 0.3,
    max_bone_ratio: float = 1.2,
) -> bool:
    """Return True if the bone segment between A and B is plausible.

    Rejects:
    - min endpoint confidence below conf_min
    - bone length exceeding max_bone_ratio * size
    """
    if min(A.c, B.c) < conf_min:
        return False
    bone_len = math.hypot(B.x - A.x, B.y - A.y)
    if bone_len > max_bone_ratio * size:
        return False
    return True
