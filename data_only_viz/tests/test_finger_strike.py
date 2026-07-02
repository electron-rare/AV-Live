"""Tests for FingerStrikeDetector (air-piano strike detection)."""
from __future__ import annotations

from data_only_viz.finger_strike import (
    FingerStrikeDetector,
    PinchDetector,
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
    det.step([_hand({1: 0.40}), None], t_now=0.00)
    # frame 1: index tip drops 0.06 below -> downward velocity 0.06 > thresh
    e1 = det.step([_hand({1: 0.46}), None], t_now=0.04)
    # frame 2: tip stays down -> velocity ~0, must NOT refire
    e2 = det.step([_hand({1: 0.46}), None], t_now=0.08)
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
        out += det.step([_hand({1: by}, base_y=by), None], t_now=i * 0.04)
    assert out == []


def test_refractory_blocks_second_strike():
    det = FingerStrikeDetector(vel_thresh=0.02, refractory_ms=120.0)
    det.step([_hand({1: 0.40}), None], t_now=0.00)          # prime
    a = det.step([_hand({1: 0.46}), None], t_now=0.02)      # strike 1
    det.step([_hand({1: 0.40}), None], t_now=0.04)          # lift -> rearm
    b = det.step([_hand({1: 0.46}), None], t_now=0.06)      # within 120 ms -> blocked
    assert len(a) == 1
    assert b == []


def test_strike_speed_scales_with_velocity():
    soft = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    hard = FingerStrikeDetector(vel_thresh=0.02, speed_scale=0.10)
    soft.step([_hand({1: 0.40}), None], t_now=0.0)
    hard.step([_hand({1: 0.40}), None], t_now=0.0)
    s = soft.step([_hand({1: 0.44}), None], t_now=0.04)   # delta 0.04
    h = hard.step([_hand({1: 0.50}), None], t_now=0.04)   # delta 0.10
    assert h[0].strike_speed > s[0].strike_speed


def _pinch_hand(thumb_xy, index_xy):
    """21-kp hand with fixed wrist & middle-MCP (hand size = 0.3). Middle/
    ring/pinky tips are parked far from the thumb so only the thumb-index
    pair can pinch."""
    lm = [[0.5, 0.5, 0.0] for _ in range(21)]
    lm[0] = [0.5, 0.8, 0.0]                       # WRIST
    lm[9] = [0.5, 0.5, 0.0]                       # MIDDLE_MCP -> size 0.3
    lm[4] = [thumb_xy[0], thumb_xy[1], 0.0]       # THUMB_TIP
    lm[8] = [index_xy[0], index_xy[1], 0.0]       # INDEX_TIP
    lm[12] = [0.9, 0.5, 0.0]                      # MIDDLE_TIP (far)
    lm[16] = [0.9, 0.6, 0.0]                      # RING_TIP (far)
    lm[20] = [0.9, 0.7, 0.0]                      # LITTLE_TIP (far)
    return lm


_OPEN = ((0.2, 0.5), (0.8, 0.5))     # thumb-index dist 0.6 -> ratio 2.0
_PINCH = ((0.5, 0.5), (0.52, 0.5))   # dist 0.02 -> ratio 0.067


def test_pinch_fires_on_thumb_index_contact():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65)
    assert det.step([_pinch_hand(*_OPEN), None], 0.0) == []
    ev = det.step([_pinch_hand(*_PINCH), None], 0.1)
    assert len(ev) == 1
    assert ev[0].finger == 1     # index = finger 1
    assert ev[0].hand == 0


def test_pinch_does_not_refire_while_held():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    a = det.step([_pinch_hand(*_PINCH), None], 0.1)   # fire
    b = det.step([_pinch_hand(*_PINCH), None], 0.2)   # still held -> no refire
    assert len(a) == 1
    assert b == []


def test_pinch_rearms_after_release():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    a = det.step([_pinch_hand(*_PINCH), None], 0.1)   # fire
    det.step([_pinch_hand(*_OPEN), None], 0.2)        # release (ratio > off)
    c = det.step([_pinch_hand(*_PINCH), None], 0.3)   # pinch again -> fire
    assert len(a) == 1
    assert len(c) == 1


def test_pinch_refractory_blocks():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=200)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    a = det.step([_pinch_hand(*_PINCH), None], 0.05)  # fire t=0.05
    det.step([_pinch_hand(*_OPEN), None], 0.08)       # release
    b = det.step([_pinch_hand(*_PINCH), None], 0.10)  # within 200 ms -> blocked
    assert len(a) == 1
    assert b == []


def test_pinch_engage_release_emits_both_edges():
    """Engage emits state=1; subsequent open emits state=0 (same finger)."""
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    engage = det.step([_pinch_hand(*_PINCH), None], 0.1)   # engage edge
    release = det.step([_pinch_hand(*_OPEN), None], 0.2)   # release edge
    assert len(engage) == 1 and engage[0].state == 1
    assert len(release) == 1 and release[0].state == 0
    assert release[0].hand == 0 and release[0].finger == 1


def test_pinch_hand_disappear_emits_release():
    """When an engaged hand disappears, a release edge is synthesised."""
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    engage = det.step([_pinch_hand(*_PINCH), None], 0.1)   # engage
    release = det.step([None, None], 0.2)                   # hand gone
    assert len(engage) == 1 and engage[0].state == 1
    assert len(release) == 1 and release[0].state == 0


def _pinch_hand_multi(thumb_xy, tips):
    """21-kp hand (size 0.3); `tips` maps finger 0..3 (index/middle/ring/pinky)
    -> (x,y) for that fingertip. Unlisted fingertips are parked far from thumb."""
    lm = [[0.5, 0.5, 0.0] for _ in range(21)]
    lm[0] = [0.5, 0.8, 0.0]                       # WRIST
    lm[9] = [0.5, 0.5, 0.0]                       # MIDDLE_MCP -> size 0.3
    lm[4] = [thumb_xy[0], thumb_xy[1], 0.0]       # THUMB_TIP
    far = [(0.9, 0.5), (0.9, 0.6), (0.9, 0.7), (0.9, 0.8)]
    for i, idx in enumerate((8, 12, 16, 20)):     # PINCH_TIPS
        x, y = tips.get(i, far[i])
        lm[idx] = [x, y, 0.0]
    return lm


def test_pinch_closest_finger_wins():
    # index ratio ~0.067, middle ratio ~0.33 -> margin 0.27 >= 0.20 -> index only.
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand_multi((0.5, 0.5), {}), None], 0.0)             # open
    ev = det.step([_pinch_hand_multi((0.5, 0.5),
                                     {0: (0.52, 0.5), 1: (0.60, 0.5)}), None], 0.1)
    assert len(ev) == 1
    assert ev[0].finger == 1 and ev[0].state == 1                 # index only


def test_pinch_ambiguous_adjacent_fires_nothing():
    # index ratio ~0.067, middle ratio ~0.10 -> margin 0.033 < 0.20 -> no winner.
    # (both are below ratio_on, so the OLD per-finger logic would fire both.)
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0)
    det.step([_pinch_hand_multi((0.5, 0.5), {}), None], 0.0)             # open
    ev = det.step([_pinch_hand_multi((0.5, 0.5),
                                     {0: (0.52, 0.5), 1: (0.53, 0.5)}), None], 0.1)
    assert ev == []


def _relaxed_hand():
    """Relaxed/fist hand: thumb touches the index tip, but middle/ring/
    pinky are curled near the wrist (NOT extended). The runner-up tip is
    far from the thumb so the closest-wins margin passes -- only the
    extension gate can reject this hand."""
    lm = [[0.5, 0.5, 0.0] for _ in range(21)]
    lm[0] = [0.5, 0.8, 0.0]        # WRIST
    lm[9] = [0.5, 0.5, 0.0]        # MIDDLE_MCP -> hand size 0.3
    lm[4] = [0.45, 0.55, 0.0]      # THUMB_TIP
    lm[8] = [0.47, 0.55, 0.0]      # INDEX_TIP: ratio 0.067 (pinch-close)
    lm[12] = [0.60, 0.62, 0.0]     # MIDDLE_TIP curled (ext ~0.69)
    lm[16] = [0.62, 0.65, 0.0]     # RING_TIP curled (ext ~0.64)
    lm[20] = [0.64, 0.68, 0.0]     # LITTLE_TIP curled (ext ~0.62)
    return lm


def test_relaxed_hand_rejected_by_extension_gate():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=2)
    out = []
    for i in range(10):
        out += det.step([_relaxed_hand(), None], i * 0.033)
    assert out == []


def test_open_hand_pinch_passes_extension_gate():
    # _pinch_hand parks middle/ring/little far from the wrist
    # (ext 1.67 / 1.49 / 1.37, all >= 1.35) -> 3 extended >= ext_min 2.
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=2)
    det.step([_pinch_hand(*_OPEN), None], 0.0)
    ev = det.step([_pinch_hand(*_PINCH), None], 0.1)
    assert len(ev) == 1 and ev[0].state == 1 and ev[0].finger == 1


def test_extension_gate_defeat_reproduces_old_behavior():
    # ext_min=0 disables the gate: the relaxed hand fires like today.
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        ext_min=0)
    ev = det.step([_relaxed_hand(), None], 0.1)
    assert len(ev) == 1 and ev[0].state == 1


def test_debounce_delays_engage_to_nth_frame():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_OPEN), None], 0.00)
    a = det.step([_pinch_hand(*_PINCH), None], 0.10)   # qualifying 1
    b = det.step([_pinch_hand(*_PINCH), None], 0.13)   # qualifying 2
    c = det.step([_pinch_hand(*_PINCH), None], 0.16)   # qualifying 3 -> engage
    assert a == [] and b == []
    assert len(c) == 1 and c[0].state == 1 and c[0].finger == 1


def test_debounce_jitter_resets_counter():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_PINCH), None], 0.00)       # qualifying 1
    det.step([_pinch_hand(*_PINCH), None], 0.03)       # qualifying 2
    det.step([_pinch_hand(*_OPEN), None], 0.06)        # jitter -> counter resets
    a = det.step([_pinch_hand(*_PINCH), None], 0.09)   # qualifying 1 again
    b = det.step([_pinch_hand(*_PINCH), None], 0.12)   # qualifying 2
    assert a == [] and b == []


def test_release_immediate_after_debounced_engage():
    det = PinchDetector(ratio_on=0.45, ratio_off=0.65, refractory_ms=0,
                        debounce_frames=3)
    det.step([_pinch_hand(*_PINCH), None], 0.00)
    det.step([_pinch_hand(*_PINCH), None], 0.03)
    eng = det.step([_pinch_hand(*_PINCH), None], 0.06)  # 3rd frame -> engage
    rel = det.step([_pinch_hand(*_OPEN), None], 0.09)   # very next frame
    assert len(eng) == 1 and eng[0].state == 1
    assert len(rel) == 1 and rel[0].state == 0
