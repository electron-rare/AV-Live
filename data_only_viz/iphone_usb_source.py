"""IphoneUSBSource — a cv2-VideoCapture-shaped frame source backed by the
iPhone ARBodyTracker USB stream. Decodes the AVLiveWire HEVC video to BGR
frames for MediaPipe, and (Task 2) writes ARKit skeleton + Vision hands into
State. Substitutes for cv2.VideoCapture in multi.py under --iphone-usb."""
from __future__ import annotations

import logging
import socket
import struct
import threading
import time

try:
    import av
except ImportError:  # pragma: no cover — av missing is caught at runtime by caller
    av = None  # type: ignore[assignment]
import cv2
import numpy as np

from data_only_viz.scripts.iphone_usb_bridge import (
    connect_device, decode_skeleton, iter_frames, TAG_SKELETON,
)
from data_only_viz.state import PoseKp

TAG_VIDEO = 2
TAG_HANDS = 4
LOG = logging.getLogger("iphone_usb_source")

_HAND_BYTES = 1 + 21 * 12   # chirality:u8 + 21 × (x,y,z) × 4 bytes BE f32
_ARKIT_JOINTS = 91


def _make_point(x: float, y: float, z: float) -> PoseKp:
    """Wrap raw floats from the wire into a PoseKp landmark."""
    return PoseKp(x=x, y=y, z=z, c=1.0)


def _decode_hands(payload: bytes):
    """Decode TAG_HANDS payload → list[list[PoseKp]] (may be empty) or None.

    Wire layout: count:u8, then per hand: chirality:u8 (1=right) followed by
    21 × (x, y, z) big-endian f32. x,y are normalized image coords; z≈confidence.
    Returns None only on empty payload; an empty list when count==0.
    """
    if not payload:
        return None
    n = payload[0]
    if n == 0:
        return []
    off = 1
    hands: list[list[PoseKp]] = []
    for _ in range(n):
        if off + _HAND_BYTES > len(payload):
            break
        off += 1   # skip chirality byte (not used by HandFeatureExtractor)
        pts = struct.unpack(">" + "f" * 63, payload[off:off + 21 * 12])
        off += 21 * 12
        hand = [_make_point(pts[i * 3], pts[i * 3 + 1], pts[i * 3 + 2])
                for i in range(21)]
        hands.append(hand)
    return hands


def _to_annexb(data: bytes) -> bytes:
    out = bytearray(); i = 0
    while i + 4 <= len(data):
        n = int.from_bytes(data[i:i + 4], "big"); i += 4
        if i + n > len(data):
            break
        out += b"\x00\x00\x00\x01" + data[i:i + n]; i += n
    return bytes(out)


class IphoneUSBSource:
    def __init__(self, state=None, target_size=(640, 480),
                 write_hands: bool = True) -> None:
        self.state = state
        self.target_w, self.target_h = target_size
        self._write_hands = write_hands
        self._codec = av.codec.CodecContext.create("hevc", "r") if av is not None else None
        self._lock = threading.Lock()
        self._frame = None            # latest BGR np.ndarray
        self._stop = threading.Event()
        self._thread = None
        self._sock = None             # stored for shutdown() in release()
        self._opened = False

    def start(self) -> bool:
        sock = connect_device()
        if sock is None:
            LOG.error("iphone usb: no device / connect failed")
            return False
        self._sock = sock
        self._opened = True
        self._thread = threading.Thread(
            target=self._run, args=(sock,), name="iphone_usb_src", daemon=True)
        self._thread.start()
        return True

    def isOpened(self) -> bool:
        return self._opened

    def _run(self, sock) -> None:
        while not self._stop.is_set():
            try:
                for tag, pid, payload in iter_frames(sock):
                    if self._stop.is_set():
                        break
                    if tag == TAG_VIDEO and len(payload) > 1:
                        annexb = _to_annexb(payload[1:])
                        if self._codec is not None and av is not None:
                            try:
                                for fr in self._codec.decode(av.Packet(annexb)):
                                    img = fr.to_ndarray(format="bgr24")
                                    img = cv2.resize(img, (self.target_w, self.target_h))
                                    with self._lock:
                                        self._frame = img
                            except Exception as e:  # av.AVError is a removal-prone alias
                                LOG.debug("hevc decode: %s", e)
                    elif tag == TAG_SKELETON and self.state is not None:
                        joints = decode_skeleton(payload)
                        if joints is not None:
                            with self.state.lock():
                                arr = self.state.persons_arkit_joints.get(pid)
                                if arr is None or arr.shape != (_ARKIT_JOINTS, 3):
                                    arr = np.zeros((_ARKIT_JOINTS, 3), dtype=np.float32)
                                for i, (x, y, z, valid) in enumerate(joints):
                                    if valid:
                                        arr[i] = (x, y, z)
                                self.state.persons_arkit_joints[pid] = arr
                                self.state.persons_arkit_last_t[pid] = time.perf_counter()
                    elif tag == TAG_HANDS:
                        hands = _decode_hands(payload)
                        if hands is not None and self._write_hands and self.state is not None:
                            with self.state.lock():
                                self.state.persons_hands = hands
            except OSError as e:
                LOG.warning("iphone usb stream error: %s", e)
            finally:
                try:
                    sock.close()
                except OSError:
                    pass
            # Stream ended. Drop the stale frame so read() reports no-frame,
            # then reconnect (unless stopping) so a transient USB/app drop
            # doesn't freeze the pose pipeline (the iPhone backgrounding or a
            # USB hiccup ends iter_frames; we re-establish :7000).
            with self._lock:
                self._frame = None
            self._opened = False
            if self._stop.is_set():
                break
            LOG.info("iphone usb stream ended — reconnecting...")
            sock = self._reconnect()
            if sock is None:
                break
            self._sock = sock
            self._opened = True
            LOG.info("iphone usb reconnected")
        self._opened = False

    def _reconnect(self):
        """Retry connect_device() with capped backoff until it succeeds or
        release() is called. Returns the new socket, or None if stopping."""
        delay = 0.5
        while not self._stop.is_set():
            sock = connect_device()
            if sock is not None:
                return sock
            self._stop.wait(delay)
            delay = min(delay * 2, 3.0)
        return None

    def read(self):
        with self._lock:
            if self._frame is None or not self._opened:
                return False, None
            return True, self._frame.copy()

    def set(self, *args) -> bool:
        return True   # cv2 CAP_PROP_* no-op

    def release(self) -> None:
        self._stop.set()
        if self._sock is not None:
            try:
                self._sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        if self._thread is not None:
            self._thread.join(timeout=2.0)
        self._opened = False
