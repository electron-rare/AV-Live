"""Pure ARKit skeleton -> line segment builder."""
from data_only_viz.arkit_skeleton import arkit_segments, bones_from_parents


def test_bones_skip_root():
    parents = [-1, 0, 1]
    assert bones_from_parents(parents) == [(1, 0), (2, 1)]


def test_bones_skip_out_of_range():
    parents = [-1, 0, 99]  # 99 has no joint
    assert bones_from_parents(parents) == [(1, 0)]


def test_segments_basic():
    # Realistic bone lengths < 0.5 (horizontal spine-like chain)
    arr2d = [(0.0, 0.0), (0.2, 0.0), (0.4, 0.0)]
    valid = [True, True, True]
    parents = [-1, 0, 1]
    segs = arkit_segments(arr2d, valid, parents)
    assert segs == [(0.2, 0.0, 0.0, 0.0), (0.4, 0.0, 0.2, 0.0)]


def test_segments_drop_invalid_endpoint():
    arr2d = [(0.0, 0.0), (0.2, 0.0), (0.4, 0.0)]
    valid = [True, False, True]  # joint 1 invalid
    parents = [-1, 0, 1]
    # bone (1,0) drops (1 invalid); bone (2,1) drops (1 invalid)
    assert arkit_segments(arr2d, valid, parents) == []


def test_segments_valid_none_keeps_all():
    arr2d = [(0.0, 0.0), (0.3, 0.0)]  # bone length 0.3 < max_len=0.5
    parents = [-1, 0]
    assert arkit_segments(arr2d, None, parents) == [(0.3, 0.0, 0.0, 0.0)]


# ---------------------------------------------------------------------------
# New filter tests (bounds + max_len)
# ---------------------------------------------------------------------------

def test_segments_out_of_bounds_endpoint_skipped():
    """Endpoint outside [-bounds, 1+bounds] → bone skipped."""
    # Joint 1 at x=-0.2 is outside [-0.1, 1.1]
    arr2d = [(0.5, 0.5), (-0.2, 0.5), (0.7, 0.5)]
    valid = [True, True, True]
    parents = [-1, 0, 1]
    # bone (1,0): joint 1 out of bounds → skip
    # bone (2,1): joint 1 out of bounds → skip
    segs = arkit_segments(arr2d, valid, parents, bounds=0.1)
    assert segs == []


def test_segments_overlong_bone_skipped():
    """Bone length > max_len → bone skipped."""
    # Bone from (0.0, 0.5) to (1.0, 0.5): length=1.0 > max_len=0.5
    arr2d = [(0.0, 0.5), (1.0, 0.5)]
    valid = [True, True]
    parents = [-1, 0]
    segs = arkit_segments(arr2d, valid, parents, max_len=0.5)
    assert segs == []


def test_segments_normal_skeleton_passes_with_defaults():
    """Realistic bones (length < 0.5, coords in [0,1]) pass all filters."""
    arr2d = [(0.5, 0.3), (0.5, 0.6), (0.5, 0.8)]  # vertical spine-like
    valid = [True, True, True]
    parents = [-1, 0, 1]
    segs = arkit_segments(arr2d, valid, parents)
    # Both bones length = 0.3 < max_len=0.5; all coords in [0,1] ⊂ [-0.1,1.1]
    assert len(segs) == 2
    assert segs[0] == (0.5, 0.6, 0.5, 0.3)
    assert segs[1] == (0.5, 0.8, 0.5, 0.6)


def test_segments_in_bounds_endpoint_passes():
    """Endpoint exactly at boundary (0.0, 1.0) is kept."""
    arr2d = [(0.5, 0.5), (0.5, 0.2)]  # bone length 0.3 < 0.5
    valid = [True, True]
    parents = [-1, 0]
    segs = arkit_segments(arr2d, valid, parents, bounds=0.1)
    assert len(segs) == 1


def test_segments_legacy_diagonal_bone_now_filtered():
    """Regression pin: the pre-filter test fixtures used a full-diagonal
    bone (0,0)->(0.5,0.5), length ~0.707. The max_len=0.5 default now
    REJECTS it — this is the intended behavior change of the v2 filter,
    made explicit here instead of silently retuning old fixtures."""
    arr2d = [(0.0, 0.0), (0.5, 0.5)]
    valid = [True, True]
    parents = [-1, 0]
    assert arkit_segments(arr2d, valid, parents) == []
    # ...and the env-tunable knob restores it for close-up shots.
    assert len(arkit_segments(arr2d, valid, parents, max_len=0.8)) == 1
