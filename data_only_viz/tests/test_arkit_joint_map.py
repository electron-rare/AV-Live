"""ARKit 91 joints → MediaPipe Pose 33 mapping integrity."""
from data_only_viz.arkit_joint_map import (
    ARKIT91_TO_MP33, ARKIT_PELVIS_IDX, MP33_NUM_LANDMARKS,
)


def test_mapping_is_tuple_of_pairs():
    assert isinstance(ARKIT91_TO_MP33, tuple)
    assert len(ARKIT91_TO_MP33) > 0
    for pair in ARKIT91_TO_MP33:
        assert isinstance(pair, tuple)
        assert len(pair) == 2


def test_mapping_indices_in_range():
    for arkit_idx, mp33_idx in ARKIT91_TO_MP33:
        assert 0 <= arkit_idx < 91, f"arkit idx out of range: {arkit_idx}"
        assert 0 <= mp33_idx < MP33_NUM_LANDMARKS, \
            f"mp33 idx out of range: {mp33_idx}"


def test_pelvis_index_valid():
    assert 0 <= ARKIT_PELVIS_IDX < 91


def test_no_duplicate_mp33_targets():
    """Each MediaPipe slot must be written by at most one ARKit joint."""
    mp33_seen = set()
    for _, mp33_idx in ARKIT91_TO_MP33:
        assert mp33_idx not in mp33_seen, \
            f"mp33 slot {mp33_idx} mapped twice"
        mp33_seen.add(mp33_idx)
