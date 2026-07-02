"""Pure (no-device) unit tests for iphone_usb_source helpers.

Tests _to_annexb and _decode_hands without any hardware or network connection.
"""
import struct

import pytest

from data_only_viz.iphone_usb_source import _to_annexb, _decode_hands, _HAND_BYTES


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
