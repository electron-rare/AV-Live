"""Tests for PoseSoundBridge.send_finger."""
from __future__ import annotations

from unittest.mock import MagicMock

from data_only_viz.finger_strike import StrikeEvent
from data_only_viz.pose_bridge import PoseSoundBridge


def _bridge() -> PoseSoundBridge:
    b = PoseSoundBridge()
    b._client = MagicMock()      # stub the UDP client
    return b


def test_send_finger_emits_expected_osc():
    b = _bridge()
    ev = StrikeEvent(hand=1, finger=2, strike_speed=0.5, z=0.1,
                     tipx=0.7, tipy=0.6)
    b.send_finger(ev)
    b._client.send_message.assert_called_once()
    addr, args = b._client.send_message.call_args[0]
    assert addr == "/pose/finger"
    assert args[0] == 0           # pid
    assert args[1] == 1           # hand
    assert args[2] == 2           # finger
    assert abs(args[3] - 0.5) < 1e-6
    assert len(args) == 7
    # Verify z, tipx, tipy values
    assert abs(args[4] - 0.1) < 1e-6     # z
    assert abs(args[5] - 0.7) < 1e-6     # tipx
    assert abs(args[6] - 0.6) < 1e-6     # tipy
    # types matter for OSC tags / the SC ~fpResolve reader
    assert isinstance(args[0], int) and not isinstance(args[0], bool)
    assert isinstance(args[1], int) and isinstance(args[2], int)
    assert all(isinstance(a, float) for a in args[3:7])
