"""Pure geometry helpers for hand overlay filtering and panel rendering.

No Metal, no numpy, no pyobjc — safe to unit-test anywhere.
"""
from __future__ import annotations

import math
from typing import Protocol


# ---------------------------------------------------------------------------
# Panel layout constants
# ---------------------------------------------------------------------------

#: Panel square size in normalized HEIGHT units.  A panel occupies
#: PANEL_SIDE * view_height pixels on both axes (square in pixel space).
PANEL_SIDE: float = 0.30

#: Gap between the screen edge and the near edge of the panel (normalized).
PANEL_MARGIN: float = 0.02

#: Fraction of each panel dimension removed from every side to form the
#: inner rect used as the drawing area for hand wireframes.
PANEL_INNER: float = 0.10


class _HasXYC(Protocol):
    x: float
    y: float
    c: float


def arkit_2d_fresh(ts_by_pid: dict, now: float, max_age: float = 1.0) -> bool:
    """Return True if any pid has a timestamp younger than *max_age* seconds.

    Args:
        ts_by_pid: mapping pid -> perf_counter timestamp (from
                   ``State.persons_arkit_2d_t``).
        now:       current ``time.perf_counter()`` value.
        max_age:   staleness threshold in seconds (exclusive: age < max_age).

    Returns:
        True if at least one entry satisfies ``now - ts < max_age``.
        False if the dict is empty or every entry is stale.
    """
    for ts in ts_by_pid.values():
        if (now - ts) < max_age:
            return True
    return False


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
    - wrist (kp[0]) outside [-0.1, 1.1] in x or y (out-of-frame ghost anchor)
    - size (wrist->middle-MCP) outside [size_min, size_max]
    - mean confidence below conf_min
    """
    if len(kp) < 21:
        return False
    w = kp[0]
    if not (-0.1 <= w.x <= 1.1 and -0.1 <= w.y <= 1.1):
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


# ---------------------------------------------------------------------------
# Panel helpers
# ---------------------------------------------------------------------------

def panel_rect(side: str, aspect: float) -> tuple[float, float, float, float]:
    """Normalized [0,1] screen rect of the hand side panel.

    The panel is square in pixel space:
      pixel_width  = norm_width  * view_width  = (PANEL_SIDE / aspect) * aspect * view_height
                   = PANEL_SIDE * view_height  = pixel_height.

    Args:
        side:   "left" or "right".
        aspect: view width / view height (> 0).

    Returns:
        (x0, y0, x1, y1) in normalized [0,1] coords, y down, origin top-left.
    """
    norm_w = PANEL_SIDE / aspect   # normalized width  (square in pixel space)
    norm_h = PANEL_SIDE            # normalized height
    y0 = 0.5 - norm_h / 2.0
    y1 = 0.5 + norm_h / 2.0
    if side == "left":
        x0 = PANEL_MARGIN
        x1 = PANEL_MARGIN + norm_w
    else:  # "right"
        x1 = 1.0 - PANEL_MARGIN
        x0 = x1 - norm_w
    return x0, y0, x1, y1


def panel_frame(side: str, aspect: float) -> list[tuple[float, float, float, float]]:
    """Four border segments tracing the panel rect (clock-wise, starting top).

    Returns:
        List of (ax, ay, bx, by) in normalized [0,1] screen coords, y down.
    """
    x0, y0, x1, y1 = panel_rect(side, aspect)
    return [
        (x0, y0, x1, y0),  # top edge   (left→right)
        (x1, y0, x1, y1),  # right edge (top→bottom)
        (x1, y1, x0, y1),  # bottom edge (right→left)
        (x0, y1, x0, y0),  # left edge   (bottom→top)
    ]


def panel_segments(
    kp: list[_HasXYC],
    side: str,
    bones: list[tuple[int, int]],
    aspect: float,
    mirror: bool = True,
    conf_min: float = 0.3,
) -> list[tuple[float, float, float, float]]:
    """Map hand landmarks into a side panel using uniform pixel-space scale.

    The hand bounding box is fit into the inner panel rect (panel rect shrunk
    by PANEL_INNER fraction on each side) with a uniform pixel-space scale —
    meaning the pixel aspect ratio of the hand is preserved regardless of the
    view aspect ratio.

    Scale derivation:
        s = min(inner_pixel_w / bbox_pixel_w,  inner_pixel_h / bbox_pixel_h)
          = min(iw / kw,  ih / kh)
      where iw/kw are normalized-coord ratios whose view dimensions cancel.
    Moving Δkp.x in kp-x corresponds to Δkp.x * s in normalized screen x, and
    Δkp.y in kp-y corresponds to Δkp.y * s in normalized screen y — preserving
    the original pixel ratio between any two segment endpoints.

    When mirror=True, X is flipped within the panel so the zoomed hand matches
    the mirrored video background (i.e. the panel always shows a "front view").

    Args:
        kp:       21+ keypoints with .x, .y (normalized image coords, y down), .c.
        side:     "left" or "right".
        bones:    List of (index_a, index_b) pairs defining which keypoints to connect.
        aspect:   view width / view height.
        mirror:   If True, flip X within the panel.
        conf_min: Minimum confidence for hand_plausible and segment_ok checks.

    Returns:
        List of (ax, ay, bx, by) in normalized [0,1] screen coords, y down.
        Returns [] if hand_plausible(kp) fails.
    """
    if not hand_plausible(kp, conf_min=conf_min):
        return []

    x0, y0, x1, y1 = panel_rect(side, aspect)
    pw = x1 - x0
    ph = y1 - y0

    # Inner rect: shrink by PANEL_INNER fraction on every side
    ix0 = x0 + PANEL_INNER * pw
    ix1 = x1 - PANEL_INNER * pw
    iy0 = y0 + PANEL_INNER * ph
    iy1 = y1 - PANEL_INNER * ph
    iw = ix1 - ix0
    ih = iy1 - iy0

    # Keypoint bounding box in normalized image coords
    kx_min = min(p.x for p in kp)
    kx_max = max(p.x for p in kp)
    ky_min = min(p.y for p in kp)
    ky_max = max(p.y for p in kp)
    kw = kx_max - kx_min
    kh = ky_max - ky_min

    if kw == 0.0 and kh == 0.0:
        return []

    # Uniform pixel-space scale factor (view dimensions cancel in the ratio)
    if kw > 0.0 and kh > 0.0:
        s = min(iw / kw, ih / kh)
    elif kw > 0.0:
        s = iw / kw
    else:
        s = ih / kh

    # Centre the scaled hand bbox inside the inner rect
    offset_x = (iw - kw * s) / 2.0
    offset_y = (ih - kh * s) / 2.0

    def _map(p: _HasXYC) -> tuple[float, float]:
        rel_x = (kx_max - p.x) if mirror else (p.x - kx_min)
        nx = ix0 + offset_x + rel_x * s
        ny = iy0 + offset_y + (p.y - ky_min) * s
        return nx, ny

    sz = hand_size(kp)
    result: list[tuple[float, float, float, float]] = []
    for a, b in bones:
        if a >= len(kp) or b >= len(kp):
            continue
        A = kp[a]
        B = kp[b]
        if not segment_ok(A, B, sz, conf_min=conf_min):
            continue
        ax, ay = _map(A)
        bx, by = _map(B)
        result.append((ax, ay, bx, by))

    return result


# ---------------------------------------------------------------------------
# Hand temporal persistence gate
# ---------------------------------------------------------------------------

class HandPersistenceGate:
    """Suppress ghost hand detections that only flash for 1-2 frames.

    Tracks each hand by wrist position (landmark 0).  A hand is only
    drawable once the same wrist position has been matched for
    *min_frames* consecutive calls.  A track that goes unmatched for even
    one frame is immediately dropped (resets the consecutive count).

    min_frames=1 disables gating: every incoming hand is drawable on the
    first call (useful for the single-person MediaPipe fallback path).
    """

    def __init__(self, min_frames: int = 3, radius: float = 0.15) -> None:
        self._min_frames = min_frames
        self._radius = radius
        # Each track: [wrist_x, wrist_y, consecutive_count]
        self._tracks: list[list] = []

    def step(self, hands: list) -> list[bool]:
        """Update tracks and return a draw flag per hand.

        Args:
            hands: list of 21-landmark hand objects; landmark 0 is the wrist
                   and must expose .x and .y attributes.

        Returns:
            list[bool] of length len(hands).  True = this hand has been
            seen at the same position for at least min_frames consecutive
            calls and should be drawn.
        """
        result: list[bool] = [False] * len(hands)
        new_tracks: list[list] = []
        used: set[int] = set()

        for h_idx, hand in enumerate(hands):
            wx = hand[0].x
            wy = hand[0].y

            # Find the nearest existing track within radius (greedy).
            best_dist = float("inf")
            best_t = -1
            for t_idx, (tx, ty, _count) in enumerate(self._tracks):
                if t_idx in used:
                    continue
                d = math.hypot(wx - tx, wy - ty)
                if d < best_dist and d < self._radius:
                    best_dist = d
                    best_t = t_idx

            if best_t >= 0:
                used.add(best_t)
                new_count = self._tracks[best_t][2] + 1
                new_tracks.append([wx, wy, new_count])
                result[h_idx] = new_count >= self._min_frames
            else:
                # New track — starts at count 1.
                new_tracks.append([wx, wy, 1])
                result[h_idx] = 1 >= self._min_frames

        # Unmatched tracks are dropped (not carried into new_tracks).
        self._tracks = new_tracks
        return result
