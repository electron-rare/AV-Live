"""Hand L/R slotting: route raw hands to a fixed [left|None, right|None] pair.

Chirality path (iPhone ARBodyTracker Vision): if `chirality` is aligned with
`hands` (same length), route chir==0 -> slot 0 (left), chir==1 -> slot 1 (right).
First match per slot wins; extras dropped.

Fallback (chirality absent/misaligned): sort valid hands by screen cx ascending
(flipped when mirror=True) and assign leftmost to slot 0, next to slot 1.

`swap=True`: inverts the chirality INTERPRETATION only (chir 0 -> right slot,
1 -> left slot). ARBodyTracker's Vision chirality arrives inverted vs the
user's mirrored view (observed live 2026-07-02), so HAND_SWAP_LR defaults to
1 in the consumers; set 0 if a future app build fixes chirality at the
source. The cx fallback is screen-relative and is never swapped.

`near_min > 0`: after routing, replace a slot with None when the hand's
wrist-to-middle-MCP distance (normalised) is below `near_min`.
"""
from __future__ import annotations

import math


# ---- micro-helpers (duplicated from hand_features to avoid circular import) ---

def _finite(v: float, fallback: float) -> float:
    return v if isinstance(v, float) and math.isfinite(v) else fallback


def _coord(p, attr: str, idx: int, fallback: float = 0.5) -> float:
    if hasattr(p, attr):
        return float(getattr(p, attr))
    try:
        return float(p[idx])
    except (TypeError, IndexError):
        return fallback


def _clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else hi if v > hi else v


def _hand_size(hand) -> float:
    """Wrist(0) -> middle-MCP(9) distance; works for both attr and list kp formats."""
    w = hand[0]
    m = hand[9]
    wx = _finite(_coord(w, "x", 0), 0.5)
    wy = _finite(_coord(w, "y", 1), 0.5)
    mx = _finite(_coord(m, "x", 0), 0.5)
    my = _finite(_coord(m, "y", 1), 0.5)
    return math.hypot(mx - wx, my - wy)


def _is_valid(hand) -> bool:
    try:
        return hand is not None and len(hand) >= 21
    except TypeError:
        return False


def route_hands(
    hands,
    chirality=None,
    *,
    mirror: bool = False,
    swap: bool = False,
    near_min: float = 0.0,
) -> list:  # always [left|None, right|None]
    """Route hands to a 2-element [left, right] slot list.

    Parameters
    ----------
    hands:     raw hand list (any length, may contain None / short entries).
    chirality: int list aligned 1-to-1 with `hands` (0=left, 1=right).
               None / wrong length -> cx fallback.
    mirror:    flip cx for the fallback path so screen-left stays slot 0.
    swap:      invert the chirality mapping (0 -> right, 1 -> left). Safety
               knob for a source whose Vision chirality arrives inverted.
               Never touches the cx fallback (already screen-relative).
    near_min:  replace a routed slot with None when hand_size < near_min.
    """
    chir_aligned = (
        chirality is not None
        and len(chirality) == len(hands)
        and len(chirality) > 0
    )

    # Build valid (chirality_value_or_None, hand) pairs — BEFORE filtering invalids
    # so chirality[i] stays paired with hands[i] even when hands[j] is skipped.
    valid_pairs: list[tuple] = []
    for i, hand in enumerate(hands):
        if not _is_valid(hand):
            continue
        c = chirality[i] if chir_aligned else None
        valid_pairs.append((c, hand))

    slots: list = [None, None]

    if chir_aligned and any(c is not None for c, _ in valid_pairs):
        # ---- Chirality path: chir 0 -> slot 0 (left), 1 -> slot 1 (right);
        # swap inverts the mapping when the source chirality is flipped ----
        for c, hand in valid_pairs:
            target = c if c in (0, 1) else None
            if target is not None and swap:
                target = 1 - target
            if target is not None and slots[target] is None:
                slots[target] = hand
    else:
        # ---- cx fallback: leftmost on screen -> slot 0 ----
        def _cx(h):
            xs = [_finite(_coord(p, "x", 0), 0.5) for p in h[:21]]
            raw = _clamp(sum(xs) / len(xs), 0.0, 1.0)
            return (1.0 - raw) if mirror else raw

        ordered = sorted((h for _, h in valid_pairs), key=_cx)
        if ordered:
            slots[0] = ordered[0]
        if len(ordered) >= 2:
            slots[1] = ordered[1]

    # ---- near_min gate (applied after routing, both paths) ----
    if near_min > 0.0:
        for i in range(2):
            if slots[i] is not None and _hand_size(slots[i]) < near_min:
                slots[i] = None

    return slots
