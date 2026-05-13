"""Tests for /pose3d/* OSC routes emitted to AVLiveBody."""
from __future__ import annotations

from dataclasses import dataclass
from unittest.mock import MagicMock


@dataclass
class _Kp3D:
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


def test_send_body3d_emits_count_and_33_kp() -> None:
    b = _make_bridge()
    # One person, 33 keypoints with deterministic xyz.
    body = [_Kp3D(x=0.01 * i, y=-0.02 * i, z=0.03 * i, c=1.0)
            for i in range(33)]
    b.send_body3d([body], [7], t_now=0.0, force=True)

    calls = b._avbody.send_message.call_args_list
    assert calls[0].args == ("/pose3d/count", [1])
    kp_calls = [c for c in calls if c.args[0] == "/pose3d/kp"]
    assert len(kp_calls) == 33
    # Format : [pid, idx, x, y, z, c]
    first = kp_calls[0].args[1]
    assert first[0] == 7
    assert first[1] == 0
    assert abs(first[2] - 0.0) < 1e-6
    assert abs(first[4] - 0.0) < 1e-6
    # idx ordering strictly 0..32
    idxs = [c.args[1][1] for c in kp_calls]
    assert idxs == list(range(33))
    # Last kp z should be 0.03 * 32
    last = kp_calls[-1].args[1]
    assert abs(last[4] - 0.03 * 32) < 1e-6


def test_send_body3d_empty_emits_count_zero() -> None:
    b = _make_bridge()
    b.send_body3d([], [], t_now=0.0, force=True)
    calls = b._avbody.send_message.call_args_list
    assert len(calls) == 1
    assert calls[0].args == ("/pose3d/count", [0])


def test_send_body3d_multi_person() -> None:
    b = _make_bridge()
    body_a = [_Kp3D(x=1.0) for _ in range(33)]
    body_b = [_Kp3D(x=2.0) for _ in range(33)]
    b.send_body3d([body_a, body_b], [10, 11], t_now=0.0, force=True)
    calls = b._avbody.send_message.call_args_list
    assert calls[0].args == ("/pose3d/count", [2])
    kp_calls = [c for c in calls if c.args[0] == "/pose3d/kp"]
    assert len(kp_calls) == 66
    assert kp_calls[0].args[1][0] == 10
    assert kp_calls[33].args[1][0] == 11


def test_send_with_body3d_kwargs_dispatches() -> None:
    """Top-level send() routes body3d kwargs to /pose3d."""
    b = _make_bridge()
    body = [_Kp3D(x=0.5, y=0.5, c=1.0) for _ in range(33)]
    body3d = [_Kp3D(x=0.1, y=0.2, z=0.3) for _ in range(33)]
    b.send([body], [0], 1.0,
           persons_body3d=[body3d], persons_body3d_ids=[0])
    av_addrs = {c.args[0] for c in b._avbody.send_message.call_args_list}
    assert "/pose3d/count" in av_addrs
    assert "/pose3d/kp" in av_addrs
