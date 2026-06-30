"""Pure ARKit skeleton -> line segment builder."""
from data_only_viz.arkit_skeleton import arkit_segments, bones_from_parents


def test_bones_skip_root():
    parents = [-1, 0, 1]
    assert bones_from_parents(parents) == [(1, 0), (2, 1)]


def test_bones_skip_out_of_range():
    parents = [-1, 0, 99]  # 99 has no joint
    assert bones_from_parents(parents) == [(1, 0)]


def test_segments_basic():
    arr2d = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
    valid = [True, True, True]
    parents = [-1, 0, 1]
    segs = arkit_segments(arr2d, valid, parents)
    assert segs == [(0.5, 0.5, 0.0, 0.0), (1.0, 1.0, 0.5, 0.5)]


def test_segments_drop_invalid_endpoint():
    arr2d = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
    valid = [True, False, True]  # joint 1 invalid
    parents = [-1, 0, 1]
    # bone (1,0) drops (1 invalid); bone (2,1) drops (1 invalid)
    assert arkit_segments(arr2d, valid, parents) == []


def test_segments_valid_none_keeps_all():
    arr2d = [(0.0, 0.0), (0.5, 0.5)]
    parents = [-1, 0]
    assert arkit_segments(arr2d, None, parents) == [(0.5, 0.5, 0.0, 0.0)]
