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


def test_numpy_row_landmarks_finite_features():
    """Landmarks as numpy rows (indexable [x, y, ...]) must yield finite cx/cy/openness."""
    import numpy as np
    arr = np.zeros((21, 3), dtype=np.float32)
    # replicate _hand(0.5, 0.5, span=0.20) geometry via index access
    arr[:] = [0.5, 0.5, 0.0]
    arr[0] = [0.5, 0.55, 0.0]   # wrist
    arr[9] = [0.5, 0.45, 0.0]   # middle_mcp → size 0.10
    arr[4] = [0.4, 0.5, 0.0]    # thumb_tip
    arr[20] = [0.6, 0.5, 0.0]   # pinky_tip → span 0.20
    ext = HandFeatureExtractor()
    out = ext.step([arr])        # must not raise
    hand = out["L"] or out["R"]
    assert hand is not None
    assert math.isfinite(hand["cx"])
    assert math.isfinite(hand["cy"])
    assert math.isfinite(hand["openness"])
    assert hand["openness"] > 0.8  # span/size = 2.0, same as test_open_hand


def _fist_hand(tip_ext):
    """All 4 finger MCPs at center; each fingertip placed tip_ext*size away
    (so the per-finger tip->MCP ratio == tip_ext). size (wrist->mcp9) = 0.10."""
    cx, cy = 0.5, 0.5
    pts = [LM(cx, cy) for _ in range(21)]
    pts[0] = LM(cx, cy + 0.10)                # wrist -> size 0.10
    for mcp in (5, 9, 13, 17):
        pts[mcp] = LM(cx, cy)
    for tip in (8, 12, 16, 20):
        pts[tip] = LM(cx + tip_ext * 0.10, cy)
    pts[4] = LM(cx - 0.05, cy)                # thumb
    return pts


def test_fist_all_fingers_curled():
    out = HandFeatureExtractor().step([_fist_hand(0.20)])   # tips at knuckles
    assert (out["L"] or out["R"])["fist"] > 0.9


def test_open_hand_is_not_a_fist():
    out = HandFeatureExtractor().step([_fist_hand(0.80)])   # fingers extended
    assert (out["L"] or out["R"])["fist"] < 0.1


def test_one_extended_finger_breaks_the_fist():
    h = _fist_hand(0.20)                                    # all curled...
    h[8] = LM(0.5 + 0.80 * 0.10, 0.5)                       # ...except the index
    out = HandFeatureExtractor().step([h])
    assert (out["L"] or out["R"])["fist"] < 0.1            # min over fingers


def test_swap_routes_inverted_chirality_to_user_slots():
    """C1 pin: with the inverted-source swap ON (HAND_SWAP_LR default),
    a physical LEFT hand arriving labeled chir=1 must land in feature
    slot L — consistent with the pinch/strike gesture path."""
    ext = HandFeatureExtractor()
    left_hand = _hand(0.30, 0.5, span=0.20)   # user's left (source says 1)
    right_hand = _hand(0.70, 0.5, span=0.06)  # user's right (source says 0)
    out = ext.step([left_hand, right_hand], [1, 0], swap=True)
    assert out["L"] is not None and out["R"] is not None
    assert out["L"]["cx"] == pytest.approx(0.30, abs=0.01)   # left hand in L
    assert out["R"]["cx"] == pytest.approx(0.70, abs=0.01)


def test_no_swap_keeps_source_chirality():
    ext = HandFeatureExtractor()
    a = _hand(0.30, 0.5, span=0.20)
    b = _hand(0.70, 0.5, span=0.06)
    out = ext.step([a, b], [1, 0], swap=False)
    assert out["L"]["cx"] == pytest.approx(0.70, abs=0.01)   # chir 0 -> L
    assert out["R"]["cx"] == pytest.approx(0.30, abs=0.01)
