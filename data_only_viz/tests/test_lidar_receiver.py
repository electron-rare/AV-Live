"""Unit tests for the iPhone LiDAR TCP frame decoder."""
from __future__ import annotations

import struct

import numpy as np
import pytest


def _encode_frame(points: np.ndarray, timestamp_ns: int) -> bytes:
    """Mimic the iPhone-side encoder for round-trip testing."""
    n = points.shape[0]
    body = struct.pack(">Q", timestamp_ns) + struct.pack(">I", n) + points.astype("<f4").tobytes()
    header = struct.pack(">I", len(body))
    return header + body


def test_decode_lidar_frame_roundtrip() -> None:
    from data_only_viz.lidar_receiver import LidarFrame, decode_frame

    pts = np.array([[0.1, 0.2, 0.3], [-1.0, 2.0, 5.5]], dtype=np.float32)
    payload = _encode_frame(pts, timestamp_ns=1_700_000_000_000_000_000)

    body = payload[4:]
    frame = decode_frame(body)

    assert isinstance(frame, LidarFrame)
    assert frame.timestamp_ns == 1_700_000_000_000_000_000
    np.testing.assert_allclose(frame.points, pts, atol=1e-6)


def test_decode_lidar_frame_rejects_truncated() -> None:
    from data_only_viz.lidar_receiver import decode_frame

    pts = np.array([[1.0, 2.0, 3.0]], dtype=np.float32)
    body = (
        struct.pack(">Q", 0) +
        struct.pack(">I", 1) +
        pts.astype("<f4").tobytes()[:8]  # truncated
    )
    with pytest.raises(ValueError, match="truncated"):
        decode_frame(body)


def test_decode_lidar_frame_rejects_zero_vertex_count() -> None:
    from data_only_viz.lidar_receiver import decode_frame

    body = struct.pack(">Q", 0) + struct.pack(">I", 0)
    with pytest.raises(ValueError, match="vertex_count"):
        decode_frame(body)


import socket
import threading
import time


@pytest.fixture
def unused_tcp_port() -> int:
    """Bind to port 0 to grab a free port from the OS, then release it."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def _serve_one_frame(port: int, frame_bytes: bytes) -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", port))
    srv.listen(1)
    conn, _ = srv.accept()
    conn.sendall(frame_bytes)
    time.sleep(0.1)
    conn.close()
    srv.close()


def test_reader_grabs_latest_frame(unused_tcp_port: int) -> None:
    from data_only_viz.lidar_receiver import LidarTCPReader

    pts = np.array([[1.0, 2.0, 3.0]], dtype=np.float32)
    frame = _encode_frame(pts, timestamp_ns=42)
    t = threading.Thread(target=_serve_one_frame, args=(unused_tcp_port, frame), daemon=True)
    t.start()
    time.sleep(0.05)

    reader = LidarTCPReader(host="127.0.0.1", port=unused_tcp_port, connect_timeout_s=2.0)
    reader.start()
    deadline = time.monotonic() + 2.0
    latest = None
    while time.monotonic() < deadline:
        latest = reader.latest()
        if latest is not None:
            break
        time.sleep(0.02)
    reader.stop()
    t.join(timeout=1.0)

    assert latest is not None
    assert latest.timestamp_ns == 42
    np.testing.assert_allclose(latest.points, pts, atol=1e-6)


def test_reader_returns_none_before_first_frame(unused_tcp_port: int) -> None:
    from data_only_viz.lidar_receiver import LidarTCPReader

    reader = LidarTCPReader(host="127.0.0.1", port=unused_tcp_port, connect_timeout_s=0.05)
    # Do not start it; latest() must be None.
    assert reader.latest() is None
