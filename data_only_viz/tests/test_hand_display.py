"""Unit tests for hand_display geometry helpers.

All tests use tiny synthetic hands — no Metal, no pyobjc, no hardware required.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import pytest

from data_only_viz.hand_display import hand_plausible, hand_size, segment_ok


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
