"""Build line segments from a full ARKit skeleton + parent topology.

Pure functions, no Metal/state dependency, so they are unit-testable.
The renderer feeds the resulting (ax, ay, bx, by) tuples straight into
the GPU line buffer.
"""
from __future__ import annotations

import math


def bones_from_parents(parents: list[int]) -> list[tuple[int, int]]:
    """(child, parent) pairs for every joint with a valid parent."""
    n = len(parents)
    return [(i, p) for i, p in enumerate(parents) if 0 <= p < n]


def arkit_segments(arr2d, valid, parents, max_len: float = 0.5, bounds: float = 0.1):
    """Return (ax, ay, bx, by) for each bone with both endpoints valid.

    arr2d:   indexable of (x, y) normalized [0,1], length == len(parents).
    valid:   indexable of bool (length == len(parents)) or None to keep all.
    parents: parent index per joint (-1 = root).
    max_len: maximum bone length in normalized units; bones longer than this
             are skipped (garbage coords during ARKit tracking loss).
             Caveat: on an extreme close-up (subject filling the frame) a
             legit bone can approach 0.5 — raise ARKIT_BONE_MAX live if
             the skeleton visibly loses bones when very near the camera.
    bounds:  margin outside [0,1] that is still accepted; endpoints outside
             [-bounds, 1+bounds] in x or y are rejected.
    """
    n = len(parents)
    lo = -bounds
    hi = 1.0 + bounds
    segs: list[tuple[float, float, float, float]] = []
    for child, parent in bones_from_parents(parents):
        if child >= n or parent >= n:
            continue
        if valid is not None and (not valid[child] or not valid[parent]):
            continue
        ax, ay = float(arr2d[child][0]), float(arr2d[child][1])
        bx, by = float(arr2d[parent][0]), float(arr2d[parent][1])
        # Reject out-of-frame endpoints
        if not (lo <= ax <= hi and lo <= ay <= hi):
            continue
        if not (lo <= bx <= hi and lo <= by <= hi):
            continue
        # Reject implausibly long bones (tracking-loss garbage)
        if math.hypot(bx - ax, by - ay) > max_len:
            continue
        segs.append((ax, ay, bx, by))
    return segs
