"""SMPLXTCPSender handles timeouts and reconnects without dying."""

import socket
from unittest.mock import MagicMock, patch

import pytest

from data_only_viz.smplx_osc_sender import SMPLXTCPSender


def _make_sender():
    s = SMPLXTCPSender.__new__(SMPLXTCPSender)
    s.host = "127.0.0.1"
    s.port = 57130
    s._sock = None
    s._last_warn = 0.0
    return s


def test_send_timeout_closes_socket():
    sender = _make_sender()
    fake_sock = MagicMock()
    fake_sock.sendall.side_effect = socket.timeout
    sender._sock = fake_sock

    ok = sender._send_or_close(b"\x00" * 8)
    assert ok is False
    assert sender._sock is None  # closed on timeout


def test_send_broken_pipe_closes_socket():
    sender = _make_sender()
    fake_sock = MagicMock()
    fake_sock.sendall.side_effect = BrokenPipeError
    sender._sock = fake_sock

    ok = sender._send_or_close(b"\x00" * 8)
    assert ok is False
    assert sender._sock is None


@patch("socket.socket")
def test_ensure_connected_sets_tcp_nodelay_and_timeout(mock_socket_cls):
    sender = _make_sender()
    fake_sock = MagicMock()
    mock_socket_cls.return_value = fake_sock

    sender._ensure_connected()

    fake_sock.setsockopt.assert_any_call(
        socket.IPPROTO_TCP, socket.TCP_NODELAY, 1
    )
    fake_sock.settimeout.assert_called_with(1.0)
