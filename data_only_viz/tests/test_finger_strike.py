"""Tests for FingerStrikeDetector (air-piano strike detection)."""
from __future__ import annotations

from data_only_viz.finger_strike import (
    FingerStrikeDetector,
    StrikeEvent,
    FINGERTIPS,
    FINGER_BASES,
)


def _hand(tip_y_by_finger: dict[int, float], base_y: float = 0.4,
          cx: float = 0.3) -> list[list[float]]:
    """Build a 21-landmark hand. Every base knuckle sits at base_y; each
    fingertip sits at base_y unless overridden in tip_y_by_finger (keyed by
    finger 0..4). x is set near cx so L/R slotting is deterministic."""
    lm = [[cx, base_y, 0.0] for _ in range(21)]
    for f, base_idx in enumerate(FINGER_BASES):
        lm[base_idx] = [cx, base_y, 0.0]
    for f, tip_idx in enumerate(FINGERTIPS):
        ty = tip_y_by_finger.get(f, base_y)
        lm[tip_idx] = [cx, ty, 0.0]
    return lm


def test_downward_spike_fires_exactly_one_strike():
    det = FingerStrikeDetector(vel_thresh=0.02, refractory_ms=120.0)
    # frame 0: neutral (primes prev), index tip level with base
    det.step([_hand({1: 0.40})], t_now=0.00)
    # frame 1: index tip drops 0.06 below -> downward velocity 0.06 > thresh
    e1 = det.step([_hand({1: 0.46})], t_now=0.04)
    # frame 2: tip stays down -> velocity ~0, must NOT refire
    e2 = det.step([_hand({1: 0.46})], t_now=0.08)
    strikes = e1 + e2
    assert len(strikes) == 1
    assert strikes[0].finger == 1
    assert strikes[0].hand == 0
    assert strikes[0].strike_speed > 0.0


def test_whole_hand_translation_does_not_fire():
    det = FingerStrikeDetector(vel_thresh=0.02)
    out = []
    # tip and base move down together each frame -> relative y constant
    for i, by in enumerate((0.40, 0.50, 0.60, 0.70)):
        out += det.step([_hand({1: by}, base_y=by)], t_now=i * 0.04)
    assert out == []


def test_refractory_blocks_second_strike():
    det = FingerStrikeDetector(vel_thresh=0.02, refractory_ms=120.0)
    det.step([_hand({1: 0.40})], t_now=0.00)          # prime
    a = det.step([_hand({1: 0.46})], t_now=0.02)      # strike 1
    det.step([_hand({1: 0.40})], t_now=0.04)          # lift -> rearm
    b = det.step([_hand({1: 0.46})], t_now=0.06)      # within 120 ms -> blocked
    assert len(a) == 1
    assert b == []


def test_strike_speed_scales_with_velocity():
    soft = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    hard = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    soft.step([_hand({1: 0.40})], t_now=0.0)
    hard.step([_hand({1: 0.40})], t_now=0.0)
    s = soft.step([_hand({1: 0.44})], t_now=0.04)   # delta 0.04
    h = hard.step([_hand({1: 0.50})], t_now=0.04)   # delta 0.10
    assert h[0].strike_speed > s[0].strike_speed
