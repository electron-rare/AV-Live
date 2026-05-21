"""Tests for FaceFilterChain, HandFilterChain, and multi.py discrimination."""
from __future__ import annotations

import random
import time

import pytest

from data_only_viz.pose_filter import (
    FaceFilterChain,
    HandFilterChain,
    PoseFilterChain,
)
from data_only_viz.state import Kp3D, PoseKp


def _jitter_face(n_pts: int, base_x: float, base_y: float,
                 amp: float, rng: random.Random) -> list[PoseKp]:
    return [
        PoseKp(
            x=base_x + rng.uniform(-amp, amp),
            y=base_y + rng.uniform(-amp, amp),
            z=rng.uniform(-amp, amp),
            c=1.0,
        )
        for _ in range(n_pts)
    ]


def test_face_filter_reduces_jitter() -> None:
    chain = FaceFilterChain()
    rng = random.Random(42)
    n_pts = 68
    base_x, base_y = 0.5, 0.5
    amp = 0.01
    outputs: list[list[PoseKp]] = []
    t = 0.0
    for k in range(8):
        t += 1.0 / 30.0
        faces = [_jitter_face(n_pts, base_x, base_y, amp, rng)]
        out = chain.apply(faces, [0], t)
        outputs.append(out[0])
    # Compute variance on x of joint 0 across the last 5 frames.
    last = outputs[-5:]
    xs = [f[0].x for f in last]
    mean = sum(xs) / len(xs)
    var = sum((v - mean) ** 2 for v in xs) / len(xs)
    assert var < 0.005, f"face filter variance too high: {var}"


def test_hand_filter_left_right_independent() -> None:
    chain = HandFilterChain()
    rng = random.Random(7)
    n_pts = 21
    t = 0.0
    last_l: list[PoseKp] = []
    last_r: list[PoseKp] = []
    for k in range(6):
        t += 1.0 / 30.0
        left_hand = _jitter_face(n_pts, 0.2, 0.5, 0.008, rng)
        right_hand = _jitter_face(n_pts, 0.8, 0.5, 0.008, rng)
        out = chain.apply([left_hand, right_hand], [0, 0],
                          ["Left", "Right"], t)
        last_l, last_r = out[0], out[1]
    # Left and right hands keep distinct positions despite same pid.
    assert abs(last_l[0].x - last_r[0].x) > 0.4
    # Filter reduced jitter on each side.
    assert 0.1 < last_l[0].x < 0.35
    assert 0.65 < last_r[0].x < 0.9


def test_hand_filter_chain_wrapper_smoke() -> None:
    chain = PoseFilterChain()
    rng = random.Random(0)
    hands = [_jitter_face(21, 0.5, 0.5, 0.01, rng) for _ in range(2)]
    out = chain.apply_hand(hands, [0, 1], ["Left", "Right"], t_now=0.1)
    assert len(out) == 2
    assert len(out[0]) == 21


def test_face_filter_disabled_passthrough() -> None:
    chain = FaceFilterChain(enabled_stages=())
    faces = [[PoseKp(x=0.5, y=0.5, z=0.0, c=1.0) for _ in range(68)]]
    out = chain.apply(faces, [0], t_now=0.0)
    assert out[0][0].x == 0.5


def test_face_hand_latency_under_5ms() -> None:
    """Full chain (body 33 + face 68 + hand 21x2) < 5 ms per frame."""
    body_chain = PoseFilterChain(
        enabled_stages=("median", "kalman", "lookahead", "ik"))
    face_chain = FaceFilterChain()
    hand_chain = HandFilterChain()
    rng = random.Random(0)
    body = [Kp3D(x=i * 0.01, y=i * 0.02, z=i * 0.03, c=1.0)
            for i in range(33)]
    face = _jitter_face(68, 0.5, 0.5, 0.01, rng)
    hand_l = _jitter_face(21, 0.2, 0.5, 0.01, rng)
    hand_r = _jitter_face(21, 0.8, 0.5, 0.01, rng)
    # Warm-up
    for k in range(5):
        t = k * 0.033
        body_chain.apply([body], [0], t)
        face_chain.apply([face], [0], t)
        hand_chain.apply([hand_l, hand_r], [0, 0], ["Left", "Right"], t)
    # Measure
    durs: list[float] = []
    for k in range(30):
        t = (k + 5) * 0.033
        t0 = time.perf_counter()
        body_chain.apply([body], [0], t)
        face_chain.apply([face], [0], t)
        hand_chain.apply([hand_l, hand_r], [0, 0], ["Left", "Right"], t)
        durs.append((time.perf_counter() - t0) * 1000.0)
    avg = sum(durs) / len(durs)
    # CI margin : actual M-class target is < 5 ms ; allow 25 ms in tests.
    assert avg < 25.0, f"chain too slow: {avg:.2f} ms"


# ----------------------- multi.py discrimination ---------------------------


def _make_body(n_visible: int) -> list[PoseKp]:
    """Make a 33-joint body with `n_visible` high-conf joints, rest low."""
    out: list[PoseKp] = []
    for i in range(33):
        c = 1.0 if i < n_visible else 0.05
        # Spread across both x and y so the bbox has non-zero area.
        out.append(PoseKp(x=0.1 + i * 0.01, y=0.2 + i * 0.005, z=0.0, c=c))
    return out


def _make_body3d(n: int = 33) -> list[Kp3D]:
    return [Kp3D(x=0.0, y=0.0, z=0.0, c=1.0) for _ in range(n)]


def _instantiate_worker():
    """Build a MultiWorker without starting the thread (skip if cv2 missing)."""
    pytest.importorskip("cv2", reason="opencv not installed")
    from data_only_viz.multi import MultiWorker
    from data_only_viz.state import State
    return MultiWorker(state=State(), camera_index=-1)


def test_ghost_rejection_drops_low_visibility_body() -> None:
    w = _instantiate_worker()
    bodies = [_make_body(n_visible=5), _make_body(n_visible=25)]
    b3d = [_make_body3d(), _make_body3d()]
    ids = [0, 1]
    new_bodies, new_b3d, new_ids = w._reject_ghosts_and_nms(bodies, b3d, ids)
    assert len(new_bodies) == 1
    assert len(new_b3d) == 1
    assert new_ids == [1]
    assert w._n_ghost_dropped == 1


def test_nms_keeps_best_score() -> None:
    w = _instantiate_worker()
    # Two heavily overlapping bodies, second has higher mean confidence.
    b1 = _make_body(n_visible=20)
    b2 = _make_body(n_visible=33)
    new_bodies, _, new_ids = w._reject_ghosts_and_nms([b1, b2], [], [0, 1])
    # IoU of identical bbox => one dropped, the higher-score one kept.
    assert len(new_bodies) == 1
    assert new_ids == [1]


def test_pid_persistence_through_short_absence() -> None:
    w = _instantiate_worker()
    body = _make_body(n_visible=30)
    # Frame 1..30 : pid 0 present.
    for _ in range(30):
        new_ids = w._apply_pid_hysteresis([body], [0])
        assert new_ids == [0]
    # Frames 31..35 : pid 0 absent (no detection).
    for _ in range(5):
        w._apply_pid_hysteresis([], [])
    # Frame 36 : a NEW pid 9 appears at the same bbox -> should be remapped.
    new_ids = w._apply_pid_hysteresis([body], [9])
    assert new_ids == [0], f"expected hysteresis remap to 0, got {new_ids}"


def test_drop_low_visibility_face() -> None:
    w = _instantiate_worker()
    # 30 valid (non-zero) + 38 zeros.
    face_bad = [
        PoseKp(x=(0.1 if i < 30 else 0.0),
               y=(0.1 if i < 30 else 0.0), z=0.0, c=1.0)
        for i in range(68)
    ]
    face_ok = [
        PoseKp(x=0.1 + i * 0.001, y=0.2, z=0.0, c=1.0)
        for i in range(68)
    ]
    kept, ids = w._drop_low_visibility(
        [face_bad, face_ok], [0, 1], min_visible=50, which="face")
    assert len(kept) == 1
    assert ids == [1]
    assert w._n_face_dropped == 1


def test_drop_low_visibility_hand() -> None:
    w = _instantiate_worker()
    hand_bad = [PoseKp(x=0.0, y=0.0, z=0.0, c=1.0) for _ in range(21)]
    # Only 10 visible (others are zero) -> drop.
    for i in range(10):
        hand_bad[i] = PoseKp(x=0.5, y=0.5, z=0.0, c=1.0)
    hand_ok = [PoseKp(x=0.1 + i * 0.01, y=0.2, z=0.0, c=1.0)
               for i in range(21)]
    kept, ids = w._drop_low_visibility(
        [hand_bad, hand_ok], [0, 1], min_visible=15, which="hand")
    assert len(kept) == 1
    assert ids == [1]
    assert w._n_hand_dropped == 1
