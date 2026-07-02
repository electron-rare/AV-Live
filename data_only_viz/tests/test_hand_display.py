"""Unit tests for hand_display geometry helpers.

All tests use tiny synthetic hands — no Metal, no pyobjc, no hardware required.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import pytest

from data_only_viz.hand_display import (
    hand_plausible,
    hand_size,
    segment_ok,
    panel_rect,
    panel_segments,
    panel_frame,
    PANEL_SIDE,
    PANEL_MARGIN,
    PANEL_INNER,
)


# ---------------------------------------------------------------------------
# Minimal keypoint stub
# ---------------------------------------------------------------------------

@dataclass
class Kp:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0
    c: float = 1.0


def _make_hand(
    wrist_x: float = 0.5,
    wrist_y: float = 0.5,
    size: float = 0.1,
    c: float = 1.0,
    n: int = 21,
) -> list[Kp]:
    """Build a synthetic 21-landmark hand.

    Landmark 0 = wrist, landmark 9 = middle-MCP at distance `size` along x.
    All other landmarks are scattered uniformly between wrist and MCP.
    """
    kps: list[Kp] = []
    for i in range(n):
        # Spread landmarks roughly from wrist (0) to slightly past MCP (9)
        t = i / max(n - 1, 1)
        kps.append(Kp(x=wrist_x + t * size, y=wrist_y, z=0.0, c=c))
    # Ensure wrist and MCP are exactly placed so hand_size is deterministic
    kps[0] = Kp(x=wrist_x, y=wrist_y, z=0.0, c=c)
    kps[9] = Kp(x=wrist_x + size, y=wrist_y, z=0.0, c=c)
    return kps


# ---------------------------------------------------------------------------
# hand_size
# ---------------------------------------------------------------------------

def test_hand_size_simple():
    kp = _make_hand(wrist_x=0.3, wrist_y=0.4, size=0.15)
    assert math.isclose(hand_size(kp), 0.15, rel_tol=1e-6)


# ---------------------------------------------------------------------------
# hand_plausible — acceptance
# ---------------------------------------------------------------------------

def test_normal_mediapipe_hand_passes():
    """CRITICAL: c=1.0 MediaPipe hand at normal size must pass gate unchanged."""
    kp = _make_hand(size=0.12, c=1.0)
    assert hand_plausible(kp) is True


def test_plausible_boundary_size_min_exact():
    """Size exactly at size_min (0.02) should be accepted."""
    kp = _make_hand(size=0.02, c=1.0)
    assert hand_plausible(kp) is True


def test_plausible_boundary_size_max_exact():
    """Size exactly at size_max (0.5) should be accepted."""
    kp = _make_hand(size=0.5, c=1.0)
    assert hand_plausible(kp) is True


# ---------------------------------------------------------------------------
# hand_plausible — rejections
# ---------------------------------------------------------------------------

def test_fewer_than_21_landmarks_rejected():
    kp = _make_hand(size=0.1, c=1.0, n=20)
    assert hand_plausible(kp) is False


def test_tiny_hand_rejected():
    """size=0.005 < size_min=0.02 → reject."""
    kp = _make_hand(size=0.005, c=1.0)
    assert hand_plausible(kp) is False


def test_huge_hand_rejected():
    """size=0.8 > size_max=0.5 → reject."""
    kp = _make_hand(size=0.8, c=1.0)
    assert hand_plausible(kp) is False


def test_low_conf_hand_rejected():
    """mean(c)=0.1 < conf_min=0.3 → reject."""
    kp = _make_hand(size=0.1, c=0.1)
    assert hand_plausible(kp) is False


def test_borderline_conf_just_below_rejected():
    """mean(c) just under conf_min (0.29) → reject."""
    kp = _make_hand(size=0.1, c=0.29)
    assert hand_plausible(kp) is False


def test_borderline_conf_at_threshold_accepted():
    """mean(c) = conf_min (0.3) → accept."""
    kp = _make_hand(size=0.1, c=0.3)
    assert hand_plausible(kp) is True


# ---------------------------------------------------------------------------
# segment_ok
# ---------------------------------------------------------------------------

def test_normal_bone_passes():
    """A normal short bone at c=1.0 must pass."""
    size = 0.1
    A = Kp(x=0.5, y=0.5, c=1.0)
    B = Kp(x=0.55, y=0.5, c=1.0)  # bone_len = 0.05 < 1.2 * 0.1 = 0.12
    assert segment_ok(A, B, size) is True


def test_spike_segment_rejected():
    """Bone length 2× hand size exceeds max_bone_ratio=1.2 → reject."""
    size = 0.1
    A = Kp(x=0.5, y=0.5, c=1.0)
    B = Kp(x=0.5 + 2 * size, y=0.5, c=1.0)  # bone_len = 0.2 > 0.12
    assert segment_ok(A, B, size) is False


def test_low_conf_endpoint_a_rejected():
    """Endpoint A has c=0.1 < conf_min=0.3 → reject."""
    size = 0.1
    A = Kp(x=0.5, y=0.5, c=0.1)
    B = Kp(x=0.55, y=0.5, c=1.0)
    assert segment_ok(A, B, size) is False


def test_low_conf_endpoint_b_rejected():
    """Endpoint B has c=0.2 < conf_min=0.3 → reject."""
    size = 0.1
    A = Kp(x=0.5, y=0.5, c=1.0)
    B = Kp(x=0.55, y=0.5, c=0.2)
    assert segment_ok(A, B, size) is False


def test_bone_exactly_at_ratio_limit_accepted():
    """Bone length exactly max_bone_ratio * size should be accepted (<=)."""
    size = 0.1
    bone_len = 1.2 * size  # exactly at limit
    A = Kp(x=0.5, y=0.5, c=1.0)
    B = Kp(x=0.5 + bone_len, y=0.5, c=1.0)
    # bone_len == 1.2 * size → not strictly greater, should pass
    assert segment_ok(A, B, size) is True


def test_mediapipe_hand_all_bones_pass():
    """CRITICAL invariant: for c=1.0 normal-size MediaPipe hand, ALL bones pass
    segment_ok (none treated as spikes given hand_size=0.12)."""
    kp = _make_hand(size=0.12, c=1.0)
    size = hand_size(kp)
    assert hand_plausible(kp) is True
    # All adjacent pairs in [0..20] should pass segment_ok
    # (spacing between consecutive kps = size/20 << 1.2 * size)
    failures = []
    for i in range(len(kp) - 1):
        if not segment_ok(kp[i], kp[i + 1], size):
            failures.append(i)
    assert failures == [], f"Segments failed segment_ok: {failures}"


# ---------------------------------------------------------------------------
# 2D hand helper: spans a proper bbox with both x and y extent
# ---------------------------------------------------------------------------

def _make_hand_2d(
    cx: float = 0.5,
    cy: float = 0.5,
    half_w: float = 0.05,
    half_h: float = 0.05,
    c: float = 1.0,
) -> list[Kp]:
    """21 landmarks filling bbox [cx±half_w, cy±half_h].

    kp[0] = wrist at (cx-half_w, cy+half_h)  — bottom-left of bbox
    kp[9] = MCP   at (cx+half_w, cy-half_h)  — top-right of bbox
    All other kp are spread uniformly across the bbox via a diagonal.
    hand_size = dist(kp[0], kp[9]) = 2 * sqrt(half_w² + half_h²).
    """
    n = 21
    kps: list[Kp] = []
    for i in range(n):
        t = i / (n - 1)
        kps.append(Kp(
            x=cx - half_w + t * 2 * half_w,
            y=cy - half_h + t * 2 * half_h,
            z=0.0,
            c=c,
        ))
    # Override wrist and MCP so bbox spans full [cx-half_w..cx+half_w, cy-half_h..cy+half_h]
    kps[0] = Kp(x=cx - half_w, y=cy + half_h, z=0.0, c=c)  # bottom-left
    kps[9] = Kp(x=cx + half_w, y=cy - half_h, z=0.0, c=c)  # top-right
    return kps


# Minimal bone list for panel tests: wrist(0) → middle-MCP(9)
_SIMPLE_BONES: list[tuple[int, int]] = [(0, 9)]


# ---------------------------------------------------------------------------
# panel_rect
# ---------------------------------------------------------------------------

def test_panel_rect_left_x0_anchor():
    """Left panel x0 == PANEL_MARGIN."""
    x0, _y0, _x1, _y1 = panel_rect("left", aspect=1.0)
    assert math.isclose(x0, PANEL_MARGIN, rel_tol=1e-6)


def test_panel_rect_right_x1_anchor():
    """Right panel x1 == 1 - PANEL_MARGIN."""
    _x0, _y0, x1, _y1 = panel_rect("right", aspect=1.0)
    assert math.isclose(x1, 1.0 - PANEL_MARGIN, rel_tol=1e-6)


def test_panel_rect_vertically_centered():
    """Panel vertical center is at 0.5."""
    _x0, y0, _x1, y1 = panel_rect("left", aspect=1.0)
    assert math.isclose((y0 + y1) / 2.0, 0.5, rel_tol=1e-6)


def test_panel_rect_square_in_pixels_landscape():
    """With 16:9 aspect ratio, normalized width × aspect == normalized height."""
    aspect = 16.0 / 9.0
    x0, y0, x1, y1 = panel_rect("left", aspect=aspect)
    norm_w = x1 - x0
    norm_h = y1 - y0
    # pixel_w = norm_w * view_w = norm_w * aspect * view_h == norm_h * view_h = pixel_h
    assert math.isclose(norm_w * aspect, norm_h, rel_tol=1e-6)


# ---------------------------------------------------------------------------
# panel_segments
# ---------------------------------------------------------------------------

def test_panel_segments_implausible_returns_empty():
    """hand_plausible fails → panel_segments returns []."""
    kp = _make_hand(size=0.005, c=1.0)  # size < size_min=0.02 → implausible
    result = panel_segments(kp, "left", _SIMPLE_BONES, aspect=1.0, mirror=False)
    assert result == []


def test_panel_segments_inside_inner_rect():
    """All output segment endpoints lie inside the inner panel rect."""
    kp = _make_hand_2d(cx=0.5, cy=0.5, half_w=0.04, half_h=0.08, c=1.0)
    x0, y0, x1, y1 = panel_rect("left", aspect=1.0)
    pw, ph = x1 - x0, y1 - y0
    ix0 = x0 + PANEL_INNER * pw
    ix1 = x1 - PANEL_INNER * pw
    iy0 = y0 + PANEL_INNER * ph
    iy1 = y1 - PANEL_INNER * ph
    segs = panel_segments(kp, "left", _SIMPLE_BONES, aspect=1.0, mirror=False)
    assert segs, "expected at least one segment"
    eps = 1e-9
    for ax, ay, bx, by in segs:
        assert ix0 - eps <= ax <= ix1 + eps, f"ax={ax} outside [{ix0}, {ix1}]"
        assert ix0 - eps <= bx <= ix1 + eps, f"bx={bx} outside [{ix0}, {ix1}]"
        assert iy0 - eps <= ay <= iy1 + eps, f"ay={ay} outside [{iy0}, {iy1}]"
        assert iy0 - eps <= by <= iy1 + eps, f"by={by} outside [{iy0}, {iy1}]"


def test_panel_segments_aspect_preserved():
    """A hand 2× taller than wide in pixel space maps to 2× taller than wide in panel.

    With aspect=1.0 (square screen), pixel ratio == normalized ratio.
    The hand has half_h = 2*half_w, so pixel bbox is 2× taller than wide.
    After uniform pixel-space scaling the output segment's |Δy|/|Δx| must also be 2.
    """
    half_w, half_h = 0.04, 0.08  # kh=0.16, kw=0.08 → ratio 2
    kp = _make_hand_2d(cx=0.5, cy=0.5, half_w=half_w, half_h=half_h, c=1.0)
    segs = panel_segments(kp, "left", _SIMPLE_BONES, aspect=1.0, mirror=False)
    assert len(segs) == 1, f"expected 1 segment, got {len(segs)}"
    ax, ay, bx, by = segs[0]
    dx = abs(bx - ax)
    dy = abs(by - ay)
    assert dx > 1e-9 and dy > 1e-9, "segment must have both x and y extent"
    ratio = dy / dx  # pixel ratio (= normalized ratio at aspect=1)
    assert math.isclose(ratio, 2.0, rel_tol=1e-3), f"expected pixel ratio 2.0, got {ratio}"


def test_panel_segments_mirror_flips_x():
    """mirror=True flips X within the panel relative to mirror=False."""
    kp = _make_hand_2d(cx=0.5, cy=0.5, half_w=0.04, half_h=0.04, c=1.0)
    # kp[0] at bottom-left (kx_min), kp[9] at top-right (kx_max)
    segs_normal = panel_segments(kp, "left", _SIMPLE_BONES, aspect=1.0, mirror=False)
    segs_mirror = panel_segments(kp, "left", _SIMPLE_BONES, aspect=1.0, mirror=True)
    assert len(segs_normal) == 1
    assert len(segs_mirror) == 1
    ax0, _ay0, bx0, _by0 = segs_normal[0]
    ax1, _ay1, bx1, _by1 = segs_mirror[0]
    # kp[0].x < kp[9].x → without mirror: ax < bx; with mirror: ax > bx
    assert ax0 < bx0, "without mirror: wrist (kx_min) should project left of MCP (kx_max)"
    assert ax1 > bx1, "with mirror: X is flipped so wrist projects right of MCP"


# ---------------------------------------------------------------------------
# panel_frame
# ---------------------------------------------------------------------------

def test_panel_frame_returns_four_segments():
    """panel_frame returns exactly 4 segments."""
    segs = panel_frame("left", aspect=1.0)
    assert len(segs) == 4


def test_panel_frame_traces_rect():
    """Every endpoint of each frame segment is a corner of the panel rect."""
    aspect = 1.0
    x0, y0, x1, y1 = panel_rect("left", aspect)
    corners = [(x0, y0), (x0, y1), (x1, y0), (x1, y1)]
    segs = panel_frame("left", aspect)
    for ax, ay, bx, by in segs:
        for ex, ey in [(ax, ay), (bx, by)]:
            on_corner = any(
                math.isclose(ex, cx, abs_tol=1e-9) and math.isclose(ey, cy, abs_tol=1e-9)
                for cx, cy in corners
            )
            assert on_corner, f"Endpoint ({ex:.4f}, {ey:.4f}) not a corner of panel rect"
