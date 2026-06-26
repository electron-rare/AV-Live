import math
import pytest
from data_only_viz.hand_features import HandFeatureExtractor, NEUTRAL_HAND


class LM:
    """Minimal landmark stub (PoseKp-shaped)."""
    def __init__(self, x, y, z=0.0, c=1.0):
        self.x, self.y, self.z, self.c = x, y, z, c


def _hand(cx, cy, span):
    """21 landmarks centered at (cx,cy); thumb/pinky separated by `span`.

    Index 0 wrist, 4 thumb_tip, 9 middle_mcp, 20 pinky_tip.
    hand_size (wrist->middle_mcp) fixed at 0.10 so openness ~ span/size.
    """
    pts = [LM(cx, cy) for _ in range(21)]
    pts[0] = LM(cx, cy + 0.05)          # wrist below center
    pts[9] = LM(cx, cy - 0.05)          # middle_mcp above -> size 0.10
    pts[4] = LM(cx - span / 2, cy)      # thumb_tip
    pts[20] = LM(cx + span / 2, cy)     # pinky_tip
    return pts


def test_open_hand_high_openness():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.20)])  # span/size = 2.0
    hand = out["L"] or out["R"]
    assert hand["openness"] > 0.8


def test_fist_low_openness():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.03)])  # span/size = 0.3
    hand = out["L"] or out["R"]
    assert hand["openness"] < 0.2


def test_static_hand_zero_speed():
    ext = HandFeatureExtractor()
    h = _hand(0.5, 0.5, span=0.1)
    ext.step([h])
    out = ext.step([h])
    hand = out["L"] or out["R"]
    assert hand["speed"] == pytest.approx(0.0, abs=1e-6)


def test_moving_hand_positive_speed():
    ext = HandFeatureExtractor()
    ext.step([_hand(0.2, 0.5, span=0.1)])
    out = ext.step([_hand(0.6, 0.5, span=0.1)])
    hand = out["L"] or out["R"]
    assert hand["speed"] > 0.0


def test_left_right_by_screen_x():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.8, 0.5, span=0.1), _hand(0.2, 0.5, span=0.1)])
    assert out["L"]["cx"] < out["R"]["cx"]      # L is leftmost on screen
    assert out["dist"] > 0.0


def test_single_hand_zero_dist():
    ext = HandFeatureExtractor()
    out = ext.step([_hand(0.5, 0.5, span=0.1)])
    assert out["dist"] == 0.0


def test_no_hands_returns_none():
    ext = HandFeatureExtractor()
    out = ext.step([])
    assert out["L"] is None and out["R"] is None and out["dist"] == 0.0


def test_nan_landmark_falls_back_no_exception():
    ext = HandFeatureExtractor()
    h = _hand(0.5, 0.5, span=0.1)
    h[0] = LM(float("nan"), float("nan"))
    out = ext.step([h])           # must not raise
    hand = out["L"] or out["R"]
    assert math.isfinite(hand["cx"]) and math.isfinite(hand["openness"])
