"""Tests for /pose/action and /pose/kin OSC routes."""
from __future__ import annotations

from unittest.mock import MagicMock

import numpy as np


def test_send_action_formats_5_args() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_action(pid=7, label_idx=2,
                  probs=np.array([0.1, 0.2, 0.7], dtype=np.float32),
                  t_now=0.0, force=True)
    b._client.send_message.assert_called_once()
    address, args = b._client.send_message.call_args.args
    assert address == "/pose/action"
    assert args[0] == 7
    assert args[1] == 2
    assert all(isinstance(v, float) for v in args[2:5])
    assert abs(sum(args[2:5]) - 1.0) < 1e-5


def test_send_kin_formats_4_args() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_kin(pid=3, kin=np.array([0.5, 1.2, -0.3], dtype=np.float32),
               t_now=0.0, force=True)
    b._client.send_message.assert_called_once()
    address, args = b._client.send_message.call_args.args
    assert address == "/pose/kin"
    assert args[0] == 3
    assert len(args) == 4
    assert abs(args[1] - 0.5) < 1e-6
    assert abs(args[2] - 1.2) < 1e-6
    assert abs(args[3] - (-0.3)) < 1e-6


def test_send_lifecycle_enter_leave() -> None:
    from data_only_viz.pose_bridge import PoseSoundBridge
    b = PoseSoundBridge()
    b._client = MagicMock()
    b.send_enter(pid=4)
    b.send_leave(pid=4)
    calls = [c.args[0] for c in b._client.send_message.call_args_list]
    assert "/pose/enter" in calls
    assert "/pose/leave" in calls
