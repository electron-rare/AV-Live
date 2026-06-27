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


def _make_hands_payload(hands: list[list[tuple[float, float, float]]]) -> bytes:
    """Build a synthetic HandsPayload matching the wire layout.

    count:u8, then per hand: chirality:u8 (1=right) + 21 × (x,y,z) big-endian f32.
    """
    out = bytearray()
    out += bytes([len(hands)])
    for hand_kps in hands:
        out += bytes([1])          # chirality = right
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
    assert _decode_hands(bytes([0])) == []


def test_decode_hands_two_hands_length_and_coords():
    hand_a = [(float(i) * 0.1, float(i) * 0.2, float(i) * 0.05) for i in range(21)]
    hand_b = [(1.0 - float(i) * 0.03, 0.5, float(i) * 0.01) for i in range(21)]
    payload = _make_hands_payload([hand_a, hand_b])
    result = _decode_hands(payload)
    assert isinstance(result, list)
    assert len(result) == 2
    for hand in result:
        assert len(hand) == 21
    # x/y spot-checks for hand A
    assert abs(result[0][0].x - hand_a[0][0]) < 1e-5
    assert abs(result[0][5].y - hand_a[5][1]) < 1e-5
    # x/y spot-checks for hand B
    assert abs(result[1][3].x - hand_b[3][0]) < 1e-5
    assert abs(result[1][20].y - hand_b[20][1]) < 1e-5


def test_decode_hands_one_hand():
    kps = [(0.1 * i, 0.2 * i, 0.0) for i in range(21)]
    result = _decode_hands(_make_hands_payload([kps]))
    assert isinstance(result, list)
    assert len(result) == 1
    assert len(result[0]) == 21


def test_decode_hands_truncated_does_not_raise():
    hand_kps = [(0.1, 0.2, 0.3)] * 21
    full = _make_hands_payload([hand_kps, hand_kps])
    # Truncate to half — second hand will be incomplete
    truncated = full[:len(full) // 2]
    # Must not raise
    result = _decode_hands(truncated)
    assert isinstance(result, (list, type(None)))
