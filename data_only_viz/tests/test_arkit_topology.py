"""AVLiveWire topology payload round-trip (mirror of Swift TopologyPayload)."""
from data_only_viz.arkit_topology import decode_topology, encode_topology


def test_round_trip():
    names = ["root_joint", "hips_joint", "left_arm_joint"]
    parents = [-1, 0, 1]
    payload = encode_topology(names, parents)
    out = decode_topology(payload)
    assert out is not None
    got_names, got_parents = out
    assert got_names == names
    assert got_parents == parents


def test_empty():
    payload = encode_topology([], [])
    out = decode_topology(payload)
    assert out == ([], [])


def test_rejects_truncated():
    # Claims 3 joints, provides no body.
    assert decode_topology(b"\x00\x03") is None


def test_rejects_too_short():
    assert decode_topology(b"\x00") is None
