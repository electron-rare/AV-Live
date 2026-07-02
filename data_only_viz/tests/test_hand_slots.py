"""Tests for hand_slots.route_hands."""
from __future__ import annotations

import pytest
from data_only_viz.hand_slots import route_hands


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _hand(cx: float = 0.5, size: float = 0.15) -> list:
    """21-landmark hand (list of [x, y, z]). Wrist at cx, middle-MCP 'size' above."""
    lm = [[cx, 0.5, 0.0] for _ in range(21)]
    lm[0] = [cx, 0.6, 0.0]           # wrist
    lm[9] = [cx, 0.6 - size, 0.0]    # middle-MCP -> hand_size == size
    return lm


def _small_hand(cx: float = 0.5) -> list:
    """Hand with size 0.02 (below default near_min 0.10)."""
    return _hand(cx=cx, size=0.02)


# ---------------------------------------------------------------------------
# Basic chirality routing
# ---------------------------------------------------------------------------

def test_chirality_routes_left_to_slot0():
    h_l = _hand(cx=0.8)   # camera-right = user's left (mirror)
    h_r = _hand(cx=0.2)
    result = route_hands([h_l, h_r], [0, 1])
    assert result[0] is h_l
    assert result[1] is h_r


def test_chirality_routes_right_to_slot1():
    h_r = _hand(cx=0.2)
    result = route_hands([h_r], [1])
    assert result[0] is None
    assert result[1] is h_r


def test_chirality_first_match_wins_per_slot():
    """Two hands with chirality==0: first wins, second dropped."""
    h1 = _hand(cx=0.3)
    h2 = _hand(cx=0.7)
    result = route_hands([h1, h2], [0, 0])
    assert result[0] is h1
    assert result[1] is None


# ---------------------------------------------------------------------------
# Chirality misaligned → cx fallback
# ---------------------------------------------------------------------------

def test_chirality_misaligned_uses_cx_fallback():
    h_l = _hand(cx=0.2)
    h_r = _hand(cx=0.8)
    # chirality length 1 != hands length 2 → misaligned
    result = route_hands([h_l, h_r], [0])
    # cx fallback: ascending cx order → cx=0.2 → slot 0, cx=0.8 → slot 1
    assert result[0] is h_l
    assert result[1] is h_r


def test_chirality_none_uses_cx_fallback():
    h_l = _hand(cx=0.2)
    h_r = _hand(cx=0.8)
    result = route_hands([h_l, h_r], None)
    assert result[0] is h_l
    assert result[1] is h_r


# ---------------------------------------------------------------------------
# mirror flips fallback order
# ---------------------------------------------------------------------------

def test_mirror_flips_cx_fallback_order():
    h_a = _hand(cx=0.2)   # low cx = screen-left normally
    h_b = _hand(cx=0.8)
    # Without mirror: slot0=cx0.2, slot1=cx0.8
    plain = route_hands([h_a, h_b])
    assert plain[0] is h_a
    # With mirror: flip cx → 1-0.2=0.8, 1-0.8=0.2 → sort ascending → cx0.8 goes slot0
    mirrored = route_hands([h_a, h_b], mirror=True)
    assert mirrored[0] is h_b
    assert mirrored[1] is h_a


# ---------------------------------------------------------------------------
# swap: inverts the CHIRALITY interpretation only (source chirality flipped);
# the cx fallback is screen-relative and must never be affected.
# ---------------------------------------------------------------------------

def test_swap_inverts_chirality_mapping():
    h_l = _hand(cx=0.8)  # Vision says left (chir=0) but source is inverted
    h_r = _hand(cx=0.2)  # Vision says right (chir=1)
    result = route_hands([h_l, h_r], [0, 1], swap=True)
    assert result[0] is h_r   # chir 1 -> left slot under swap
    assert result[1] is h_l   # chir 0 -> right slot under swap


def test_swap_does_not_alter_cx_fallback():
    """swap only concerns chirality; the cx fallback stays screen-relative."""
    h_a = _hand(cx=0.2)
    h_b = _hand(cx=0.8)
    result = route_hands([h_a, h_b], None, swap=True)
    assert result[0] is h_a   # unchanged: leftmost keeps slot 0
    assert result[1] is h_b


def test_swap_single_hand_moves_slot():
    """A lone chir==0 hand lands in slot 1 when swap is on."""
    h = _hand(cx=0.5)
    result = route_hands([h], [0], swap=True)
    assert result[0] is None
    assert result[1] is h


# ---------------------------------------------------------------------------
# near_min gate
# ---------------------------------------------------------------------------

def test_near_min_drops_small_hand():
    big = _hand(cx=0.3, size=0.15)
    small = _hand(cx=0.7, size=0.02)
    result = route_hands([big, small], near_min=0.10)
    assert result[0] is big
    assert result[1] is None   # too small


def test_near_min_preserves_big_slot():
    big = _hand(cx=0.5, size=0.20)
    result = route_hands([big], near_min=0.10)
    assert result[0] is big


def test_near_min_drops_both_when_all_small():
    s1 = _small_hand(cx=0.3)
    s2 = _small_hand(cx=0.7)
    result = route_hands([s1, s2], near_min=0.10)
    assert result == [None, None]


# ---------------------------------------------------------------------------
# Invalid hand filtering (alignment preserved)
# ---------------------------------------------------------------------------

def test_invalid_hand_skipped_chirality_alignment_preserved():
    """An invalid hand at index 0 must not shift chirality for index 1."""
    bad = None                        # invalid
    h_r = _hand(cx=0.5)
    # chirality: bad=0(ignored), h_r=1(right)
    result = route_hands([bad, h_r], [0, 1])
    assert result[0] is None
    assert result[1] is h_r


def test_short_hand_rejected():
    short = [[0.5, 0.5, 0.0]] * 10   # <21 landmarks
    h_ok = _hand(cx=0.5)
    result = route_hands([short, h_ok], [0, 1])
    assert result[0] is None          # short dropped
    assert result[1] is h_ok


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

def test_empty_hands_returns_none_pair():
    assert route_hands([]) == [None, None]


def test_single_hand_no_chirality_slot0():
    h = _hand(cx=0.5)
    result = route_hands([h])
    assert result[0] is h
    assert result[1] is None


def test_two_hands_chirality_all_left():
    """Both hands claim left; first gets slot 0, second is dropped."""
    h1 = _hand(cx=0.2)
    h2 = _hand(cx=0.8)
    result = route_hands([h1, h2], [0, 0])
    assert result[0] is h1
    assert result[1] is None


def test_result_always_length_2():
    for hands, chir in [
        ([], None),
        ([_hand()], None),
        ([_hand(), _hand(cx=0.8)], [0, 1]),
        ([_hand(), _hand(cx=0.8), _hand(cx=0.3)], [0, 1, 0]),
    ]:
        r = route_hands(hands, chir)
        assert len(r) == 2, f"expected 2 slots, got {len(r)} for {chir}"
