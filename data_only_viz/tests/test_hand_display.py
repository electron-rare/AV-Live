"""Unit tests for hand_display geometry helpers.

All tests use tiny synthetic hands — no Metal, no pyobjc, no hardware required.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import pytest

from data_only_viz.hand_display import (
    HandPersistenceGate,
    arkit_2d_fresh,
    gauge_segments,
    gesture_quality,
    hand_facing,
    hand_plausible,
    hand_size,
    segment_ok,
    panel_rect,
    panel_segments,
    panel_frame,
    GAUGE_GAP,
    GAUGE_TICK_HALF,
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


# ---------------------------------------------------------------------------
# arkit_2d_fresh
# ---------------------------------------------------------------------------

def test_arkit_2d_fresh_empty_dict_is_false() -> None:
    """No pids → never fresh."""
    assert arkit_2d_fresh({}, now=1000.0) is False


def test_arkit_2d_fresh_single_fresh_pid() -> None:
    """A timestamp 0.5 s old with max_age=1.0 → fresh."""
    ts_by_pid = {0: 999.5}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0) is True


def test_arkit_2d_fresh_single_stale_pid() -> None:
    """A timestamp 2 s old with max_age=1.0 → stale."""
    ts_by_pid = {0: 998.0}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0) is False


def test_arkit_2d_fresh_exactly_at_max_age_is_stale() -> None:
    """age == max_age is NOT fresh (strict less-than)."""
    ts_by_pid = {0: 999.0}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0, max_age=1.0) is False


def test_arkit_2d_fresh_mix_stale_and_fresh() -> None:
    """At least one fresh pid makes the whole dict fresh."""
    ts_by_pid = {0: 990.0, 1: 999.8}  # pid 0 stale, pid 1 fresh
    assert arkit_2d_fresh(ts_by_pid, now=1000.0) is True


def test_arkit_2d_fresh_all_pids_stale() -> None:
    """All pids stale → False."""
    ts_by_pid = {0: 990.0, 1: 980.0}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0) is False


def test_arkit_2d_fresh_custom_max_age() -> None:
    """max_age=0.5 makes a 0.4 s old timestamp fresh."""
    ts_by_pid = {5: 999.6}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0, max_age=0.5) is True


def test_arkit_2d_fresh_custom_max_age_stale() -> None:
    """max_age=0.5 makes a 0.6 s old timestamp stale."""
    ts_by_pid = {5: 999.4}
    assert arkit_2d_fresh(ts_by_pid, now=1000.0, max_age=0.5) is False


# ---------------------------------------------------------------------------
# hand_plausible — wrist out-of-frame rejection
# ---------------------------------------------------------------------------

def test_plausible_wrist_out_of_frame_x_neg_rejected():
    """Wrist x < -0.1 → ghost anchor, reject."""
    kp = _make_hand(wrist_x=-0.2, wrist_y=0.5, size=0.12, c=1.0)
    assert hand_plausible(kp) is False


def test_plausible_wrist_out_of_frame_x_pos_rejected():
    """Wrist x > 1.1 → ghost anchor, reject."""
    kp = _make_hand(wrist_x=1.2, wrist_y=0.5, size=0.12, c=1.0)
    assert hand_plausible(kp) is False


def test_plausible_wrist_out_of_frame_y_rejected():
    """Wrist y < -0.1 → ghost anchor, reject."""
    kp = _make_hand(wrist_x=0.5, wrist_y=-0.15, size=0.12, c=1.0)
    assert hand_plausible(kp) is False


def test_plausible_wrist_at_exact_boundary_accepted():
    """Wrist at x=-0.1 is at the boundary — still accepted (inclusive)."""
    kp = _make_hand(wrist_x=-0.1, wrist_y=0.5, size=0.12, c=1.0)
    assert hand_plausible(kp) is True


# ---------------------------------------------------------------------------
# HandPersistenceGate
# ---------------------------------------------------------------------------

def test_gate_ghost_two_frames_never_draws():
    """A hand appearing only 2 times is never drawn (min_frames=3)."""
    gate = HandPersistenceGate(min_frames=3)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    assert gate.step([hand]) == [False]   # frame 1: count=1
    assert gate.step([hand]) == [False]   # frame 2: count=2


def test_gate_steady_hand_appears_at_third_frame():
    """A steady hand becomes drawable from the 3rd consecutive frame."""
    gate = HandPersistenceGate(min_frames=3)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    assert gate.step([hand]) == [False]   # frame 1
    assert gate.step([hand]) == [False]   # frame 2
    assert gate.step([hand]) == [True]    # frame 3: count=3 >= min_frames
    assert gate.step([hand]) == [True]    # frame 4: count=4, stays drawable


def test_gate_teleporting_hand_never_draws():
    """A hand that jumps >radius every frame never accumulates a track."""
    gate = HandPersistenceGate(min_frames=3, radius=0.15)
    for px in (0.1, 0.5, 0.9):  # each jump is 0.4 > radius=0.15
        hand = _make_hand(wrist_x=px, wrist_y=0.5)
        assert gate.step([hand]) == [False]


def test_gate_two_steady_hands_both_drawable():
    """Two hands that remain steady both become drawable at frame 3."""
    gate = HandPersistenceGate(min_frames=3)
    lh = _make_hand(wrist_x=0.3, wrist_y=0.5)
    rh = _make_hand(wrist_x=0.7, wrist_y=0.5)
    for _ in range(2):
        gate.step([lh, rh])
    result = gate.step([lh, rh])
    assert result == [True, True]


def test_gate_min_frames_one_immediate():
    """min_frames=1 makes any hand drawable on first appearance."""
    gate = HandPersistenceGate(min_frames=1)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    assert gate.step([hand]) == [True]


def test_gate_track_resets_after_absence():
    """A track that disappears for one frame must re-accumulate from scratch."""
    gate = HandPersistenceGate(min_frames=3)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    gate.step([hand])
    gate.step([hand])  # count=2, not yet drawable
    gate.step([])       # hand absent → track dropped
    # Reappears: back to count=1
    assert gate.step([hand]) == [False]


def test_gate_empty_input_returns_empty():
    """step([]) always returns []."""
    gate = HandPersistenceGate()
    assert gate.step([]) == []


def test_gate_greedy_no_double_assign():
    """Two hands close together: each matches its own track, not the same one."""
    gate = HandPersistenceGate(min_frames=2, radius=0.15)
    h1 = _make_hand(wrist_x=0.3, wrist_y=0.5)
    h2 = _make_hand(wrist_x=0.4, wrist_y=0.5)  # 0.1 apart, both within radius
    gate.step([h1, h2])
    result = gate.step([h1, h2])
    # Both should have count=2 >= min_frames=2
    assert result == [True, True]


# ---------------------------------------------------------------------------
# HandPersistenceGate — grace frames
# ---------------------------------------------------------------------------

def test_gate_grace_zero_is_strict():
    """grace=0 restores original strict behavior (1 miss drops the track)."""
    gate = HandPersistenceGate(min_frames=3, grace=0)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    for _ in range(3):
        gate.step([hand])  # establish count=3
    gate.step([])           # miss=1 > grace=0 → dropped
    assert gate.step([hand]) == [False]  # fresh count=1


def test_gate_grace_preserves_track_across_one_miss():
    """With grace=2, a 1-frame hole preserves the established count."""
    gate = HandPersistenceGate(min_frames=3, grace=2)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    for _ in range(3):
        gate.step([hand])  # establish count=3
    gate.step([])            # miss=1 ≤ grace → track survives
    result = gate.step([hand])  # matches surviving track: count=4
    assert result == [True]


def test_gate_grace_gap_frame_has_empty_result():
    """During a grace frame (no hands input), result list is empty."""
    gate = HandPersistenceGate(min_frames=3, grace=2)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    for _ in range(3):
        gate.step([hand])
    assert gate.step([]) == []  # no hands → result is []


def test_gate_grace_drops_after_grace_plus_one_misses():
    """After grace+1 consecutive misses the track is dropped."""
    gate = HandPersistenceGate(min_frames=3, grace=2)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    for _ in range(3):
        gate.step([hand])   # establish
    for _ in range(3):      # 3 misses: miss=1,2,3 → last one > grace=2 → dropped
        gate.step([])
    assert gate.step([hand]) == [False]  # fresh count=1


def test_gate_grace_ghost_stays_suppressed():
    """A ghost appearing 1 frame then disappearing never becomes drawable
    (count=1 < min_frames=3 even after being carried by grace)."""
    gate = HandPersistenceGate(min_frames=3, grace=2)
    hand = _make_hand(wrist_x=0.5, wrist_y=0.5)
    gate.step([hand])   # count=1
    gate.step([])        # miss=1 ≤ grace → track [0.5, 0.5, 1, 1] survives
    # Reappears: count increments to 2 (still not established)
    assert gate.step([hand]) == [False]


# ---------------------------------------------------------------------------
# hand_facing
# ---------------------------------------------------------------------------

def _make_facing_kp(wrist_x=0.5, wrist_y=0.7, size=0.15, spread=0.14) -> list[Kp]:
    """21-kp hand with index-MCP(5) and pinky-MCP(17) spread wide in x."""
    kp = _make_hand(wrist_x=wrist_x, wrist_y=wrist_y, size=size)
    kp[5] = Kp(x=wrist_x - spread / 2, y=wrist_y - size / 2)
    kp[17] = Kp(x=wrist_x + spread / 2, y=wrist_y - size / 2)
    return kp


def _make_sideon_kp(wrist_x=0.5, wrist_y=0.7, size=0.15) -> list[Kp]:
    """21-kp hand with index-MCP(5) and pinky-MCP(17) almost co-located."""
    kp = _make_hand(wrist_x=wrist_x, wrist_y=wrist_y, size=size)
    kp[5] = Kp(x=wrist_x, y=wrist_y - size / 2)
    kp[17] = Kp(x=wrist_x + 0.005, y=wrist_y - size / 2)
    return kp


def test_hand_facing_camera_above_threshold():
    """A palm facing the camera has a spread ratio >= 0.7."""
    kp = _make_facing_kp(size=0.15, spread=0.14)
    # facing = 0.14 / 0.15 ~ 0.93
    assert hand_facing(kp) >= 0.7


def test_hand_facing_side_on_below_threshold():
    """A side-on palm has a spread ratio < 0.4."""
    kp = _make_sideon_kp(size=0.15)
    # facing = 0.005 / 0.15 ~ 0.033
    assert hand_facing(kp) < 0.4


def test_hand_facing_zero_size_returns_zero():
    """Guard: when hand_size is ~0 (degenerate hand), returns 0.0."""
    kp = _make_hand(wrist_x=0.5, wrist_y=0.5, size=0.0)
    # Force wrist and MCP to the same position so hand_size = 0
    kp[0] = Kp(x=0.5, y=0.5)
    kp[9] = Kp(x=0.5, y=0.5)
    assert hand_facing(kp) == 0.0


def test_hand_facing_list_format():
    """hand_facing also accepts list-style kp ([x, y, z]) as used in hand_slots tests."""
    # Build a 21-element list-of-lists
    lm = [[0.5, 0.5, 0.0] for _ in range(21)]
    lm[0] = [0.5, 0.7, 0.0]    # wrist
    lm[9] = [0.5, 0.55, 0.0]   # middle-MCP, size = 0.15
    # Wide spread: index-MCP and pinky-MCP 0.14 apart in x
    lm[5] = [0.43, 0.62, 0.0]
    lm[17] = [0.57, 0.62, 0.0]
    f = hand_facing(lm)
    # facing = 0.14 / 0.15 ~ 0.93
    assert f >= 0.7


# ---------------------------------------------------------------------------
# gesture_quality
# ---------------------------------------------------------------------------

def _make_quality_hand(size: float = 0.10, facing: float = 0.7) -> list[Kp]:
    """21-kp hand with precise hand_size and hand_facing values.

    hand_size  = wrist(kp[0]) to middle-MCP(kp[9]) distance = size
    hand_facing = dist(kp[5], kp[17]) / hand_size = facing
    """
    kp = _make_hand(wrist_x=0.5, wrist_y=0.5, size=size, c=1.0)
    spread = facing * size
    mid_y = 0.5 - size / 2
    kp[5] = Kp(x=0.5 - spread / 2, y=mid_y)
    kp[17] = Kp(x=0.5 + spread / 2, y=mid_y)
    return kp


def test_quality_absent_hand_returns_zero():
    """hand=None → quality 0.0 regardless of other params."""
    assert gesture_quality(None, face_min=0.5, near_on=0.10) == 0.0


def test_quality_engaged_forces_one():
    """engaged=True → quality 1.0 regardless of hand geometry."""
    hand = _make_quality_hand(size=0.05, facing=0.1)  # far and side-on
    assert gesture_quality(hand, face_min=0.5, near_on=0.10, engaged=True) == 1.0


def test_quality_far_but_fully_facing():
    """Hand at near-threshold (size=0.5*near_on) but fully facing → 0.65.

    near_norm = 0.0 (at lower bound), facing_norm = 1.0 → 0.30 + 0.35 = 0.65.
    """
    face_min, near_on = 0.5, 0.10
    # size = 0.5 * near_on = 0.05 → near_norm = 0
    # facing = face_min = 0.5 → facing_norm = (0.5-0.25)/(0.5-0.25) = 1.0
    hand = _make_quality_hand(size=0.05, facing=face_min)
    q = gesture_quality(hand, face_min=face_min, near_on=near_on)
    assert math.isclose(q, 0.65, rel_tol=1e-6), f"expected 0.65, got {q}"


def test_quality_near_but_side_on():
    """Hand fully near (size=near_on) but side-on (facing=0.25) → 0.65.

    facing_norm = 0.0 (at lower bound), near_norm = 1.0 → 0.30 + 0.35 = 0.65.
    """
    face_min, near_on = 0.5, 0.10
    # size = near_on = 0.10 → near_norm = (0.10-0.05)/0.05 = 1.0
    # facing = 0.25 → facing_norm = (0.25-0.25)/0.25 = 0.0
    hand = _make_quality_hand(size=near_on, facing=0.25)
    q = gesture_quality(hand, face_min=face_min, near_on=near_on)
    assert math.isclose(q, 0.65, rel_tol=1e-6), f"expected 0.65, got {q}"


def test_quality_full_caps_at_one():
    """Hand well above near_on and facing threshold → quality = 1.0."""
    face_min, near_on = 0.5, 0.10
    hand = _make_quality_hand(size=0.20, facing=0.9)  # near_norm=1, facing_norm=1
    q = gesture_quality(hand, face_min=face_min, near_on=near_on)
    assert math.isclose(q, 1.0, rel_tol=1e-6), f"expected 1.0, got {q}"


def test_quality_monotonic_in_size():
    """For fixed full-facing, quality increases strictly with hand size."""
    face_min, near_on = 0.5, 0.10
    facing = face_min  # facing_norm = 1.0 at exactly face_min
    sizes = [0.5 * near_on, 0.75 * near_on, near_on]
    qs = [gesture_quality(_make_quality_hand(size=s, facing=facing),
                          face_min=face_min, near_on=near_on)
          for s in sizes]
    assert qs[0] < qs[1] < qs[2], f"not monotone: {qs}"


# ---------------------------------------------------------------------------
# gauge_segments
# ---------------------------------------------------------------------------

def test_gauge_segments_no_data_returns_two_dim_rails():
    """cx/cy=None → 2 rail segments (dim, no markers)."""
    segs = gauge_segments(None, None, "left", aspect=1.0)
    # Exactly 2 rails: one horizontal (X gauge), one vertical (Y gauge)
    assert len(segs) == 2, f"expected 2 rail segs, got {len(segs)}"
    confs = [s[4] for s in segs]
    assert all(c == 0.25 for c in confs), f"dim conf expected 0.25, got {confs}"
    pids = [s[5] for s in segs]
    assert all(p == 7 for p in pids), f"rail pid should be 7, got {pids}"


def test_gauge_segments_with_data_returns_rails_and_markers():
    """cx/cy provided → 2 rails + 2 X-marker ticks + 2 Y-marker ticks = 6 total."""
    segs = gauge_segments(0.5, 0.5, "left", aspect=1.0)
    assert len(segs) == 6, f"expected 6 segments (2 rail + 4 marker), got {len(segs)}"
    rail_segs = [s for s in segs if s[5] == 7]
    marker_segs = [s for s in segs if s[5] != 7]
    assert len(rail_segs) == 2 and len(marker_segs) == 4


def test_gauge_x_marker_centered_on_rail():
    """cx=0.5 → primary X marker tick is at x = (x0+x1)/2 of the panel."""
    x0, _y0, x1, _y1 = panel_rect("left", aspect=1.0)
    center_x = (x0 + x1) / 2.0
    segs = gauge_segments(0.5, 0.5, "left", aspect=1.0, content_pid=5)
    # X marker ticks are vertical segments (same x on both endpoints), pid != 7
    x_marker_segs = [s for s in segs
                     if s[5] != 7 and math.isclose(s[0], s[2], abs_tol=1e-9)]
    assert x_marker_segs, "no vertical X-marker ticks found"
    # The primary tick (minimum x) should land at center_x; the bold-offset
    # tick is at center_x + GAUGE_BOLD (a tiny offset for visual thickness).
    primary_x = min(s[0] for s in x_marker_segs)
    assert math.isclose(primary_x, center_x, rel_tol=1e-6), \
        f"primary X marker at {primary_x}, expected {center_x}"


def test_gauge_mirror_flips_x_marker():
    """mirror=True → X marker at 1-cx (mirrored position), cx unchanged for Y."""
    x0, _y0, x1, _y1 = panel_rect("left", aspect=1.0)
    cx = 0.3
    # Without mirror: marker at x0 + 0.3*(x1-x0)
    segs_norm = gauge_segments(cx, 0.5, "left", 1.0, mirror=False, content_pid=5)
    # With mirror: marker at x0 + 0.7*(x1-x0)
    segs_mirr = gauge_segments(cx, 0.5, "left", 1.0, mirror=True, content_pid=5)
    # Extract first X-marker tick (vertical segment, pid=5)
    def _x_tick_x(segs):
        for ax, ay, bx, by, c, p in segs:
            if p == 5 and math.isclose(ax, bx, rel_tol=1e-9):
                return ax
        return None
    xn = _x_tick_x(segs_norm)
    xm = _x_tick_x(segs_mirr)
    assert xn is not None and xm is not None
    expected_n = x0 + cx * (x1 - x0)
    expected_m = x0 + (1.0 - cx) * (x1 - x0)
    assert math.isclose(xn, expected_n, rel_tol=1e-6), f"normal: {xn} != {expected_n}"
    assert math.isclose(xm, expected_m, rel_tol=1e-6), f"mirror: {xm} != {expected_m}"


def test_gauge_y_rail_below_panel_x_rail():
    """X gauge rail y-coordinate is below the panel bottom edge."""
    _x0, _y0, _x1, y1 = panel_rect("left", aspect=1.0)
    segs = gauge_segments(0.5, 0.5, "left", 1.0)
    # Horizontal rail: ay == by (same y, spanning x)
    h_rail = [s for s in segs if math.isclose(s[1], s[3], rel_tol=1e-9)
              and s[5] == 7]
    assert h_rail, "no horizontal rail segment"
    rail_y = h_rail[0][1]
    assert rail_y > y1, f"X gauge rail y={rail_y} should be below panel y1={y1}"
    assert math.isclose(rail_y, y1 + GAUGE_GAP, rel_tol=1e-6)
