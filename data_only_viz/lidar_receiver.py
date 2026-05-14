"""TCP receiver for iPhone ARBodyTracker LiDAR ARMeshAnchor stream.

Wire format (per frame, after the 4-byte big-endian length prefix consumed
by the socket reader):

    [uint64 BE timestamp_ns]
    [uint32 BE vertex_count]
    [float32 LE x y z] * vertex_count

The decoder is pure and side-effect-free so it can be unit-tested without a
socket. The socket reader lives in a separate class (LidarTCPReader) so its
threading model is independently testable.
"""
from __future__ import annotations

import struct
from dataclasses import dataclass

import numpy as np

_HEADER = struct.Struct(">QI")  # timestamp_ns, vertex_count


@dataclass(frozen=True)
class LidarFrame:
    """One decoded LiDAR frame from the iPhone."""

    timestamp_ns: int
    points: np.ndarray  # shape (N, 3), float32, ARKit world frame (meters)


def decode_frame(body: bytes) -> LidarFrame:
    """Decode a frame body (length prefix already stripped)."""
    if len(body) < _HEADER.size:
        raise ValueError(f"truncated frame: header needs {_HEADER.size} bytes, got {len(body)}")
    timestamp_ns, vertex_count = _HEADER.unpack_from(body, 0)
    if vertex_count == 0:
        raise ValueError("vertex_count must be > 0")
    expected = _HEADER.size + vertex_count * 12
    if len(body) < expected:
        raise ValueError(f"truncated frame: need {expected} bytes for {vertex_count} verts, got {len(body)}")
    raw = body[_HEADER.size : expected]
    pts = np.frombuffer(raw, dtype="<f4").reshape(vertex_count, 3).astype(np.float32, copy=True)
    return LidarFrame(timestamp_ns=int(timestamp_ns), points=pts)
