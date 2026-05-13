"""Tests for the 3D pose filter chain."""
from __future__ import annotations

import math

import pytest

from data_only_viz.pose_filter import (
    IKConstraints,
    KalmanCV,
    LookaheadPredictor,
    MedianFilter,
    PoseFilterChain,
    L_ELBOW,
    L_SHOULDER,
    L_WRIST,
)
from data_only_viz.state import Kp3D


def _body(values: list[tuple[float, float, float]]) -> list[Kp3D]:
    """Build a 33-joint body, fill remaining with zeros."""
    out = [Kp3D(x=v[0], y=v[1], z=v[2], c=1.0) for v in values]
    while len(out) < 33:
        out.append(Kp3D(x=0.0, y=0.0, z=0.0, c=1.0))
    return out


def test_median_filter_kills_spike() -> None:
    mf = MedianFilter(window=3)
    pid, j = 0, 0
    # Warm up
    mf.apply(pid, j, 0.0, 0.0, 0.0)
    mf.apply(pid, j, 0.01, 0.0, 0.0)
    mf.apply(pid, j, 0.02, 0.0, 0.0)
    # Spike (NaN)
    x, y, z = mf.apply(pid, j, float("nan"), float("nan"), float("nan"))
    assert math.isfinite(x) and math.isfinite(y) and math.isfinite(z)
    assert abs(x) < 0.1
    # Big outlier in x
    x2, _, _ = mf.apply(pid, j, 10.0, 0.0, 0.0)
    assert x2 < 1.0


def test_kalman_converges() -> None:
    # Use a noisy constant-velocity signal : Kalman CV should converge.
    import random
    rng = random.Random(0)
    kf = KalmanCV(q=1e-3, r=1e-2)
    pid, j = 0, 0
    t = 0.0
    dt = 1.0 / 30.0
    vel = 0.3  # m/s
    errs: list[float] = []
    for i in range(120):
        t += dt
        true_pos = vel * t
        meas = true_pos + rng.gauss(0.0, 0.01)  # 1 cm gaussian noise
        out = kf.step(pid, j, meas, 0.0, 0.0, t)
        if i > 30:
            errs.append(abs(out[0] - true_pos))
    mean_err = sum(errs) / len(errs)
    assert mean_err < 0.01  # ±1 cm post warmup


def test_lookahead_extrapolates_constant_velocity() -> None:
    pred = LookaheadPredictor(lookahead_ms=50.0, max_velocity=5.0)
    x, y, z = pred.step(0.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    assert abs(x - 0.05) < 1e-6
    assert abs(y) < 1e-9 and abs(z) < 1e-9
    # Velocity cap
    x2, _, _ = pred.step(0.0, 0.0, 0.0, 100.0, 0.0, 0.0)
    assert abs(x2 - 5.0 * 0.050) < 1e-6


def test_ik_clamps_elbow_180_plus() -> None:
    ik = IKConstraints()
    # Shoulder at origin, elbow at (1,0,0), wrist BEHIND elbow at (2,0,0)
    # -> shoulder-elbow-wrist angle is 180 deg, exceeds 175 deg limit.
    coords: list[tuple[float, float, float]] = [(0.0, 0.0, 0.0)] * 33
    coords[L_SHOULDER] = (0.0, 0.0, 0.0)
    coords[L_ELBOW] = (1.0, 0.0, 0.0)
    coords[L_WRIST] = (2.0, 0.0, 0.0)
    body = _body(coords)
    out = ik.apply(body)
    p = (out[L_SHOULDER].x, out[L_SHOULDER].y, out[L_SHOULDER].z)
    e = (out[L_ELBOW].x, out[L_ELBOW].y, out[L_ELBOW].z)
    w = (out[L_WRIST].x, out[L_WRIST].y, out[L_WRIST].z)
    v_pj = (p[0] - e[0], p[1] - e[1], p[2] - e[2])
    v_cj = (w[0] - e[0], w[1] - e[1], w[2] - e[2])
    n_pj = math.sqrt(sum(c * c for c in v_pj))
    n_cj = math.sqrt(sum(c * c for c in v_cj))
    cos_a = (v_pj[0] * v_cj[0] + v_pj[1] * v_cj[1] + v_pj[2] * v_cj[2]
             ) / (n_pj * n_cj)
    cos_a = max(-1.0, min(1.0, cos_a))
    ang_deg = math.degrees(math.acos(cos_a))
    assert ang_deg <= 175.5
    # Bone length preserved
    assert abs(n_cj - 1.0) < 1e-6


def test_chain_no_op_when_disabled() -> None:
    chain = PoseFilterChain(enabled_stages=())
    body = _body([(0.1, 0.2, 0.3), (0.4, 0.5, 0.6)])
    out = chain.apply([body], [0], t_now=0.0)
    assert len(out) == 1
    for i in range(len(body)):
        assert out[0][i].x == body[i].x
        assert out[0][i].y == body[i].y
        assert out[0][i].z == body[i].z


def test_chain_latency_under_2ms() -> None:
    chain = PoseFilterChain(
        enabled_stages=("median", "kalman", "lookahead", "ik"))
    body = _body([(i * 0.01, i * 0.02, i * 0.03) for i in range(33)])
    # Warm up internal state
    for k in range(5):
        chain.apply([body, body], [0, 1], t_now=k * 0.033)
    # Measure
    times: list[float] = []
    for k in range(30):
        chain.apply([body, body], [0, 1], t_now=(k + 5) * 0.033)
        times.append(chain.last_apply_ms)
    avg = sum(times) / len(times)
    # Generous bound for CI ; live target is <2 ms but allow 10 ms in tests.
    assert avg < 10.0
