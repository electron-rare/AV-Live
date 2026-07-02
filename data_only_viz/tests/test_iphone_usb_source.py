"""Pure (no-device) unit tests for iphone_usb_source helpers.

Tests _to_annexb, _decode_hands, and apply_skeleton_joints without any
hardware or network connection.
"""
import struct

import numpy as np
import pytest

from data_only_viz.iphone_usb_source import (
    _to_annexb, _decode_hands, _HAND_BYTES,
    apply_skeleton_joints, _ARKIT_JOINTS,
)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _avcc(nals: list[bytes]) -> bytes:
    """Build an AVCC-style buffer with 4-byte big-endian length prefixes."""
    out = bytearray()
    for nal in nals:
        out += struct.pack(">I", len(nal)) + nal
    return bytes(out)


def _make_hands_payload(
    hands: list[list[tuple[float, float, float]]],
    chiralities: list[int] | None = None,
) -> bytes:
    """Build a synthetic HandsPayload matching the wire layout.

    count:u8, then per hand: chirality:u8 (1=right) + 21 × (x,y,z) big-endian f32.
    chiralities[i] sets the chirality byte for hand i (default 1=right for all).
    """
    out = bytearray()
    out += bytes([len(hands)])
    for i, hand_kps in enumerate(hands):
        chir = chiralities[i] if chiralities is not None else 1
        out += bytes([chir])
        for x, y, z in hand_kps:
            out += struct.pack(">fff", x, y, z)
    return bytes(out)


# ---------------------------------------------------------------------------
# _to_annexb
# ---------------------------------------------------------------------------

def test_to_annexb_two_nals():
    nal1 = b"\x67\x01\x02\x03"    # SPS-like
    nal2 = b"\x41\xAB\xCD"
    avcc = _avcc([nal1, nal2])
    result = _to_annexb(avcc)
    # First unit: Annex-B start code + nal1
    assert result[:4] == b"\x00\x00\x00\x01"
    assert result[4:4 + len(nal1)] == nal1
    # Second unit: Annex-B start code + nal2
    rest = result[4 + len(nal1):]
    assert rest[:4] == b"\x00\x00\x00\x01"
    assert rest[4:4 + len(nal2)] == nal2
    assert len(result) == 4 + len(nal1) + 4 + len(nal2)


def test_to_annexb_payload_bytes_preserved():
    nal = bytes(range(32))
    result = _to_annexb(_avcc([nal]))
    assert result[4:] == nal


def test_to_annexb_empty():
    assert _to_annexb(b"") == b""


def test_to_annexb_truncated_nal_is_dropped():
    # Length prefix claims 10 bytes but only 3 are present
    buf = struct.pack(">I", 10) + b"\x00" * 3
    result = _to_annexb(buf)
    assert result == b""


def test_to_annexb_single_nal():
    nal = b"\x65\xB8"
    result = _to_annexb(_avcc([nal]))
    assert result == b"\x00\x00\x00\x01" + nal


# ---------------------------------------------------------------------------
# _decode_hands
# ---------------------------------------------------------------------------

def test_decode_hands_empty_payload():
    assert _decode_hands(b"") is None


def test_decode_hands_count_zero():
    assert _decode_hands(bytes([0])) == ([], [])


def test_decode_hands_two_hands_length_and_coords():
    hand_a = [(float(i) * 0.1, float(i) * 0.2, float(i) * 0.05) for i in range(21)]
    hand_b = [(1.0 - float(i) * 0.03, 0.5, float(i) * 0.01) for i in range(21)]
    payload = _make_hands_payload([hand_a, hand_b])
    result = _decode_hands(payload)
    assert isinstance(result, tuple)
    hands, chirality = result
    assert isinstance(hands, list)
    assert len(hands) == 2
    assert len(chirality) == 2
    for hand in hands:
        assert len(hand) == 21
    # x/y spot-checks for hand A
    assert abs(hands[0][0].x - hand_a[0][0]) < 1e-5
    assert abs(hands[0][5].y - hand_a[5][1]) < 1e-5
    # x/y spot-checks for hand B
    assert abs(hands[1][3].x - hand_b[3][0]) < 1e-5
    assert abs(hands[1][20].y - hand_b[20][1]) < 1e-5


def test_decode_hands_one_hand():
    kps = [(0.1 * i, 0.2 * i, 0.0) for i in range(21)]
    result = _decode_hands(_make_hands_payload([kps]))
    assert isinstance(result, tuple)
    hands, chirality = result
    assert isinstance(hands, list)
    assert len(hands) == 1
    assert len(hands[0]) == 21
    assert len(chirality) == 1


def test_decode_hands_truncated_does_not_raise():
    hand_kps = [(0.1, 0.2, 0.3)] * 21
    full = _make_hands_payload([hand_kps, hand_kps])
    # Truncate to half — second hand will be incomplete
    truncated = full[:len(full) // 2]
    # Must not raise; result is either None or a (hands, chirality) tuple
    result = _decode_hands(truncated)
    assert result is None or isinstance(result, tuple)


# ---------------------------------------------------------------------------
# Task A: confidence + chirality (new tests added for TDD)
# ---------------------------------------------------------------------------

def test_decode_hands_count_zero_returns_tuple():
    """count=0 payload must return ([], []), not a bare []."""
    result = _decode_hands(bytes([0]))
    assert result == ([], [])


def test_decode_hands_chirality_and_confidence_roundtrip():
    """Two hands with chirality [0,1] and in-range z values round-trip correctly.

    .c must equal clamp(z, 0, 1); .z must equal raw wire z.
    """
    hand_a = [(0.1 * i, 0.2 * i, 0.7) for i in range(21)]  # z=0.7 in range
    hand_b = [(0.05 * i, 0.1 * i, 0.3) for i in range(21)]  # z=0.3 in range
    payload = _make_hands_payload([hand_a, hand_b], chiralities=[0, 1])
    result = _decode_hands(payload)
    assert result is not None
    hands, chirality = result
    assert chirality == [0, 1]
    assert len(hands) == 2
    # hand A: z=0.7 → .z=0.7 raw, .c=0.7 clamped (same, in range)
    assert abs(hands[0][0].z - 0.7) < 1e-5
    assert abs(hands[0][0].c - 0.7) < 1e-5
    # hand B: z=0.3 → .z=0.3 raw, .c=0.3 clamped (same, in range)
    assert abs(hands[1][0].z - 0.3) < 1e-5
    assert abs(hands[1][0].c - 0.3) < 1e-5


def test_decode_hands_confidence_clamped_out_of_range():
    """z outside [0,1] clamps in .c but stays raw in .z."""
    hand_low = [(0.5, 0.5, -0.2)] * 21   # z below 0
    hand_high = [(0.5, 0.5, 1.7)] * 21   # z above 1
    payload = _make_hands_payload([hand_low, hand_high])
    result = _decode_hands(payload)
    assert result is not None
    hands, _ = result
    # hand_low: raw z preserved, c clamped to 0
    assert abs(hands[0][0].z - (-0.2)) < 1e-5
    assert hands[0][0].c == 0.0
    # hand_high: raw z preserved, c clamped to 1
    assert abs(hands[1][0].z - 1.7) < 1e-5
    assert hands[1][0].c == 1.0


# ---------------------------------------------------------------------------
# apply_skeleton_joints — B4 tearing fix (chantier 2)
# ---------------------------------------------------------------------------

def _make_all_valid_joints(value: float = 0.1) -> list[tuple[float, float, float, bool]]:
    """Return _ARKIT_JOINTS tuples all marked valid with a constant value."""
    return [(value, value, value, True)] * _ARKIT_JOINTS


def _make_joints_with_mask(
    values: "list[tuple[float, float, float]]",
    valid_mask: "list[bool]",
) -> list[tuple[float, float, float, bool]]:
    """Zip (x,y,z) values with a validity mask into the joints wire format."""
    return [(x, y, z, v) for (x, y, z), v in zip(values, valid_mask)]


def test_apply_skeleton_joints_fresh_pid_returns_correct_shape():
    """prev=None → zeros array of shape (_ARKIT_JOINTS, 3), dtype float32."""
    joints = [(0.0, 0.0, 0.0, False)] * _ARKIT_JOINTS
    result = apply_skeleton_joints(None, joints)
    assert result.shape == (_ARKIT_JOINTS, 3)
    assert result.dtype == np.float32
    assert (result == 0).all()


def test_apply_skeleton_joints_returns_new_array_each_call():
    """Each call returns a different array object — never the same reference.

    This is the core identity guarantee for the B4 tearing fix: readers that
    captured a reference to arr1 continue to see a consistent arr1 even while
    the writer has moved on to arr2.
    """
    joints1 = _make_all_valid_joints(0.1)
    arr1 = apply_skeleton_joints(None, joints1)

    joints2 = _make_all_valid_joints(0.9)
    arr2 = apply_skeleton_joints(arr1, joints2)

    assert arr2 is not arr1


def test_apply_skeleton_joints_preserves_values_not_valid_this_frame():
    """Joints with valid=False in update 2 keep their values from update 1.

    Update 1 sets all joints to their index value.  Update 2 marks only
    joint 0 as valid with a new value.  Joints 1..N-1 must be unchanged.
    """
    # Update 1: every joint valid, joint i has x=float(i)
    joints1 = [(float(i), 0.0, 0.0, True) for i in range(_ARKIT_JOINTS)]
    arr1 = apply_skeleton_joints(None, joints1)

    # Update 2: only joint 0 valid (new value), rest invalid
    vals2 = [(99.0, 99.0, 99.0)] * _ARKIT_JOINTS
    mask2 = [i == 0 for i in range(_ARKIT_JOINTS)]
    joints2 = _make_joints_with_mask(vals2, mask2)
    arr2 = apply_skeleton_joints(arr1, joints2)

    # Joint 0: overwritten by update 2
    assert abs(arr2[0, 0] - 99.0) < 1e-5

    # Joints 1..N-1: preserved from update 1
    for i in range(1, _ARKIT_JOINTS):
        assert abs(arr2[i, 0] - float(i)) < 1e-5, f"joint {i} not preserved"


def test_apply_skeleton_joints_valid_joints_applied():
    """Valid joints from update 2 overwrite the previous values correctly."""
    joints1 = _make_all_valid_joints(0.0)
    arr1 = apply_skeleton_joints(None, joints1)

    joints2 = [(1.0, 2.0, 3.0, True)] * _ARKIT_JOINTS
    arr2 = apply_skeleton_joints(arr1, joints2)

    assert abs(arr2[5, 0] - 1.0) < 1e-5
    assert abs(arr2[5, 1] - 2.0) < 1e-5
    assert abs(arr2[5, 2] - 3.0) < 1e-5


def test_apply_skeleton_joints_wrong_shape_prev_discarded():
    """prev_arr with wrong shape is discarded and output starts from zeros."""
    wrong_shape = np.ones((10, 3), dtype=np.float32)
    joints = [(0.5, 0.5, 0.5, True)] * _ARKIT_JOINTS
    result = apply_skeleton_joints(wrong_shape, joints)
    assert result.shape == (_ARKIT_JOINTS, 3)
    assert abs(result[0, 0] - 0.5) < 1e-5


def test_apply_skeleton_joints_does_not_mutate_prev():
    """apply_skeleton_joints must never modify the array passed as prev_arr."""
    joints1 = _make_all_valid_joints(1.0)
    arr1 = apply_skeleton_joints(None, joints1)
    arr1_copy = arr1.copy()

    joints2 = _make_all_valid_joints(2.0)
    apply_skeleton_joints(arr1, joints2)

    # arr1 must be byte-for-byte identical to what it was before the call
    np.testing.assert_array_equal(arr1, arr1_copy)


# ---------------------------------------------------------------------------
# VIDEO_ROTATE normalized-point counterpart
# ---------------------------------------------------------------------------

def test_rotate_norm_xy_matches_rot90():
    from data_only_viz.iphone_usb_source import rotate_norm_xy
    # np.rot90 k=1 (ccw): original (x, y) lands at (y, 1-x)
    assert rotate_norm_xy(0.2, 0.7, "ccw") == pytest.approx((0.7, 0.8))
    # cw (k=3): (x, y) -> (1-y, x)
    assert rotate_norm_xy(0.2, 0.7, "cw") == pytest.approx((0.3, 0.2))
    assert rotate_norm_xy(0.2, 0.7, "180") == pytest.approx((0.8, 0.3))
    assert rotate_norm_xy(0.2, 0.7, "none") == (0.2, 0.7)
    assert rotate_norm_xy(0.2, 0.7, "garbage") == (0.2, 0.7)
