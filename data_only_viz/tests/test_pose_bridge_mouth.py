"""Tests for /pose/mouth OSC route."""
from __future__ import annotations

from unittest.mock import MagicMock


def test_send_mouth_address_and_args() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b._vdmx = None
    b.send_mouth(pid=5, mouth_open=0.42)
    b._client.send_message.assert_called_once()
    address, args = b._client.send_message.call_args.args
    assert address == "/pose/mouth"
    assert args[0] == 5
    assert isinstance(args[0], int)
    assert abs(args[1] - 0.42) < 1e-6
    assert isinstance(args[1], float)


def test_send_mouth_vj_mirror() -> None:
    """VJ mirror receives the same address and args."""
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b._vdmx = MagicMock()
    b.send_mouth(pid=1, mouth_open=0.75)
    vj_call = b._vdmx.send_message.call_args.args
    assert vj_call[0] == "/pose/mouth"
    assert vj_call[1][0] == 1
    assert abs(vj_call[1][1] - 0.75) < 1e-6


def test_send_mouth_zero_and_one_clamp() -> None:
    """Boundary values: 0.0 and 1.0 are forwarded without change."""
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b._vdmx = None
    b.send_mouth(pid=0, mouth_open=0.0)
    _, args0 = b._client.send_message.call_args.args
    assert args0[1] == 0.0

    b._client.reset_mock()
    b.send_mouth(pid=0, mouth_open=1.0)
    _, args1 = b._client.send_message.call_args.args
    assert args1[1] == 1.0
