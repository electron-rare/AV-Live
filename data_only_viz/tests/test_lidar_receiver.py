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
