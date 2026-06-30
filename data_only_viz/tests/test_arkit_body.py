"""Task 3: decode_skeleton2D round-trip tests.

Wire layout (TAG_SKELETON2D = 6):
    91 joints * (x: f32 BE, y: f32 BE) = 728 bytes of floats
    + 91 validity bytes
    = 819 bytes total
"""
import struct

from data_only_viz.scripts.iphone_usb_bridge import decode_skeleton2D, JOINT_COUNT


def test_decode_skeleton2d_roundtrip():
    floats = []
    for i in range(JOINT_COUNT):
        floats += [i * 0.001, i * 0.002]
    payload = struct.pack(">" + "f" * (JOINT_COUNT * 2), *floats)
    payload += bytes(1 if i % 2 == 0 else 0 for i in range(JOINT_COUNT))
    out = decode_skeleton2D(payload)
    assert out is not None and len(out) == JOINT_COUNT
    assert abs(out[10][0] - 0.010) < 1e-5 and out[10][2] is True
    assert out[11][2] is False


def test_decode_skeleton2d_wrong_length_returns_none():
    assert decode_skeleton2D(b"\x00" * 10) is None
    assert decode_skeleton2D(b"\x00" * 818) is None
    assert decode_skeleton2D(b"\x00" * 820) is None
    assert decode_skeleton2D(b"") is None


# ---------------------------------------------------------------------------
# Task 4: ARKit → MediaPipe-33 body builders
# ---------------------------------------------------------------------------
import numpy as np
from data_only_viz.arkit_joint_map import arkit_body_2d, ARKIT91_TO_MP33


def test_arkit_body_2d_maps_slots():
    arr = np.zeros((91, 2), dtype=np.float32)
    for ai, _mp in ARKIT91_TO_MP33:
        arr[ai] = [0.3 + ai * 0.001, 0.4]
    body = arkit_body_2d(arr)
    assert len(body) == 33
    # a mapped slot is confident; an unmapped face slot is not
    mapped_mp = ARKIT91_TO_MP33[0][1]
    assert body[mapped_mp].c > 0.5
    assert body[1].c < 0.5    # MP slot 1 (eye) has no ARKit source


def test_arkit_body_3d_maps_slots():
    from data_only_viz.arkit_joint_map import arkit_body_3d
    arr = np.zeros((91, 3), dtype=np.float32)
    for ai, _mp in ARKIT91_TO_MP33:
        arr[ai] = [float(ai) * 0.01, float(ai) * 0.02, float(ai) * 0.03]
    body = arkit_body_3d(arr)
    assert len(body) == 33
    mapped_mp = ARKIT91_TO_MP33[0][1]
    assert body[mapped_mp].c > 0.5
    assert body[1].c < 0.5
