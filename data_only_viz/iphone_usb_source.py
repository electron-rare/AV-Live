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
    connect_device, decode_skeleton, decode_skeleton2D,
    iter_frames, TAG_SKELETON, TAG_SKELETON2D,
)
from data_only_viz.arkit_topology import decode_topology
from data_only_viz.state import PoseKp

TAG_VIDEO = 2
TAG_HANDS = 4
TAG_TOPOLOGY = 7
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
                 write_hands: bool = True, mirror: bool = True) -> None:
        self.state = state
        self.target_w, self.target_h = target_size
        self._write_hands = write_hands
        # Mirror the video horizontally so the performer facing the camera
        # interacts naturally (move right -> goes right; raise right arm ->
        # the right side responds). Env CONCERT_MIRROR=0 disables it.
        import os as _os
        self._mirror = mirror and (_os.environ.get("CONCERT_MIRROR", "1") != "0")
        self._codec = av.codec.CodecContext.create("hevc", "r") if av is not None else None
        self._lock = threading.Lock()
        self._frame = None            # latest BGR np.ndarray
        self._stop = threading.Event()
        self._thread = None
        self._sock = None             # stored for shutdown() in release()
        self._opened = False

    def start(self) -> bool:
        # Try an immediate connect, but do NOT give up if the iPhone app isn't
        # streaming yet: start the read thread regardless. _run retries the
        # connect (with backoff) until the app appears, so a startup race (app
        # not ready / phone locked at launch) recovers the same way a mid-session
        # drop does -- no data_only_viz restart needed.
        sock = connect_device()
        if sock is None:
            LOG.warning("iphone usb: no device yet -- thread will keep retrying")
        else:
            self._sock = sock
            self._opened = True
        self._thread = threading.Thread(
            target=self._run, args=(sock,), name="iphone_usb_src", daemon=True)
        self._thread.start()
        return True

    def isOpened(self) -> bool:
        return self._opened

    def _run(self, sock) -> None:
        if self.state is not None:
            with self.state.lock():
                self.state.mirror_2d = self._mirror
        while not self._stop.is_set():
            if sock is None:                      # no connection yet (startup or post-drop)
                sock = self._reconnect()
                if sock is None:                  # release() was called while waiting
                    break
                self._sock = sock
                self._opened = True
                LOG.info("iphone usb connected")
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
                                    if self._mirror:
                                        img = cv2.flip(img, 1)
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
                    elif tag == TAG_SKELETON2D and self.state is not None:
                        pts = decode_skeleton2D(payload)
                        if pts is not None:
                            arr = np.array([[x, y] for (x, y, _v) in pts],
                                           dtype=np.float32)
                            valid = np.array([v for (_x, _y, v) in pts],
                                             dtype=bool)
                            with self.state.lock():
                                self.state.persons_arkit_2d[pid] = arr
                                self.state.persons_arkit_2d_valid[pid] = valid
                                self.state.persons_arkit_2d_t[pid] = \
                                    time.perf_counter()
                    elif tag == TAG_TOPOLOGY and self.state is not None:
                        topo = decode_topology(payload)
                        if topo is not None:
                            names, parents = topo
                            with self.state.lock():
                                self.state.arkit_joint_names = names
                                self.state.arkit_parents = parents
                    elif tag == TAG_HANDS:
                        hands = _decode_hands(payload)
                        if hands is not None and self.state is not None:
                            with self.state.lock():
                                # Always expose iPhone Vision hands (stable,
                                # rotation-invariant) for the air-piano.
                                self.state.persons_hands_iphone = hands
                                self.state.persons_hands_iphone_t = \
                                    time.perf_counter()
                                if self._write_hands:
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
            sock = None                           # forces the reconnect at the loop top
            if not self._stop.is_set():
                LOG.info("iphone usb stream ended -- reconnecting...")
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
