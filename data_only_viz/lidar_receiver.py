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


import logging
import socket
import threading
from typing import Optional

_LOG = logging.getLogger(__name__)
_LEN_PREFIX = struct.Struct(">I")


class LidarTCPReader:
    """Background TCP reader producing a single-slot latest-frame mailbox.

    Reconnects on transient failures with linear backoff up to 5s.
    """

    def __init__(self, host: str, port: int, connect_timeout_s: float = 2.0) -> None:
        self._host = host
        self._port = port
        self._connect_timeout_s = connect_timeout_s
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._latest: Optional[LidarFrame] = None
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(target=self._run, name="lidar-tcp", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=2.0)
            self._thread = None

    def latest(self) -> Optional[LidarFrame]:
        with self._lock:
            return self._latest

    def _run(self) -> None:
        backoff_s = 0.5
        while not self._stop.is_set():
            try:
                with socket.create_connection((self._host, self._port), timeout=self._connect_timeout_s) as sock:
                    sock.settimeout(1.0)
                    backoff_s = 0.5
                    self._read_loop(sock)
            except (OSError, ValueError) as exc:
                _LOG.warning("lidar reader: %s; reconnecting in %.1fs", exc, backoff_s)
                if self._stop.wait(backoff_s):
                    return
                backoff_s = min(backoff_s * 2.0, 5.0)

    def _read_loop(self, sock: socket.socket) -> None:
        while not self._stop.is_set():
            header = self._recv_exact(sock, _LEN_PREFIX.size)
            if header is None:
                return
            (length,) = _LEN_PREFIX.unpack(header)
            if length <= 0 or length > 8_000_000:  # sanity cap: 8 MB per frame
                raise ValueError(f"implausible frame length {length}")
            body = self._recv_exact(sock, length)
            if body is None:
                return
            frame = decode_frame(body)
            with self._lock:
                self._latest = frame

    def _recv_exact(self, sock: socket.socket, n: int) -> Optional[bytes]:
        buf = bytearray(n)
        view = memoryview(buf)
        got = 0
        while got < n:
            if self._stop.is_set():
                return None
            try:
                k = sock.recv_into(view[got:])
            except socket.timeout:
                continue
            if k == 0:
                return None
            got += k
        return bytes(buf)
