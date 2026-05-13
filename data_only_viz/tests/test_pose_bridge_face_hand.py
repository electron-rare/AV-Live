"""Tests for /face/* and /hand/* OSC routes emitted to AVLiveBody."""
from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import MagicMock


@dataclass
class _Kp:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0
    c: float = 1.0


def _make_bridge():
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b._avbody = MagicMock()
    return b


def test_send_face_emits_count_and_68_kp() -> None:
    from data_only_viz.pose_bridge import FACE_68_FROM_MP
    b = _make_bridge()
    # One face with 478 landmarks at deterministic coords.
    face = [_Kp(x=i / 478.0, y=1.0 - i / 478.0, z=0.01 * i, c=1.0)
            for i in range(478)]
    b.send_face([face], [3], t_now=0.0, force=True)

    calls = b._avbody.send_message.call_args_list
    # First call : /face/count <1>
    assert calls[0].args[0] == "/face/count"
    assert calls[0].args[1] == [1]
    # Then 68 /face/kp messages
    kp_calls = [c for c in calls if c.args[0] == "/face/kp"]
    assert len(kp_calls) == 68
    # Format : [pid, slot, x, y, z, c]
    first = kp_calls[0].args[1]
    assert first[0] == 3
    assert first[1] == 0
    assert isinstance(first[2], float)
    assert isinstance(first[3], float)
    assert isinstance(first[4], float)
    assert isinstance(first[5], float)
    # Slot ordering is strictly increasing 0..67
    slots = [c.args[1][1] for c in kp_calls]
    assert slots == list(range(68))
    # And the x coord of slot 0 matches mp_idx FACE_68_FROM_MP[0]
    mp0 = FACE_68_FROM_MP[0]
    assert abs(first[2] - mp0 / 478.0) < 1e-6


def test_send_face_empty_emits_count_zero() -> None:
    b = _make_bridge()
    b.send_face([], [], t_now=0.0, force=True)
    calls = b._avbody.send_message.call_args_list
    assert len(calls) == 1
    assert calls[0].args == ("/face/count", [0])


def test_send_hand_emits_count_and_21_kp() -> None:
    b = _make_bridge()
    hand_l = [_Kp(x=0.1, y=0.2, z=0.0, c=1.0) for _ in range(21)]
    hand_r = [_Kp(x=0.7, y=0.3, z=0.0, c=1.0) for _ in range(21)]
    # pid=2 -> left (even), pid=3 -> right (odd)
    b.send_hand([hand_l, hand_r], [2, 3], t_now=0.0, force=True)
    calls = b._avbody.send_message.call_args_list
    assert calls[0].args == ("/hand/count", [1, 1])
    kp_calls = [c for c in calls if c.args[0] == "/hand/kp"]
    assert len(kp_calls) == 42  # 21 * 2
    # First hand should be side=0 (left)
    assert kp_calls[0].args[1][1] == 0
    # 22nd kp call : start of right hand, side=1
    assert kp_calls[21].args[1][1] == 1


def test_send_throttles_below_period() -> None:
    """send_face called twice within < period emits only once."""
    b = _make_bridge()
    face = [_Kp(x=0.0, y=0.0) for _ in range(478)]
    b.send_face([face], [0], t_now=0.0, force=True)
    n_first = b._avbody.send_message.call_count
    # Second call without force AND inside throttle window : skipped.
    b._last_t = 9999.0  # pretend a body send just happened
    b.send_face([face], [0], t_now=9999.0 + 0.001, force=False)
    assert b._avbody.send_message.call_count == n_first


def test_send_with_face_hand_kwargs_dispatches() -> None:
    """Top-level send() routes face/hand kwargs to /face and /hand."""
    b = _make_bridge()
    body = [_Kp(x=0.5, y=0.5, c=1.0) for _ in range(33)]
    face = [_Kp(x=0.1, y=0.1, c=1.0) for _ in range(478)]
    hand = [_Kp(x=0.2, y=0.2, c=1.0) for _ in range(21)]
    b.send([body], [0], 1.0,
           persons_face=[face], persons_face_ids=[0],
           persons_hands=[hand], persons_hands_ids=[1])
    av_addrs = {c.args[0] for c in b._avbody.send_message.call_args_list}
    assert "/pose/count" in av_addrs
    assert "/face/count" in av_addrs
    assert "/face/kp" in av_addrs
    assert "/hand/count" in av_addrs
    assert "/hand/kp" in av_addrs
