"""Multi-HMR remote backend: drop-in replacement of MultiHMRCoreMLBackend
that delegates inference to a remote TCP server (see
``scripts/multihmr_server.py``).

Protocol (little-endian, persistent connection):

Request:
  [4B uint32 payload_len]
  [4B magic "REQ\x01"]
  [1B uint8 format_id]   # 1 = raw RGB uint8 HWC, 2 = JPEG (variable length)
  [3B padding]
  [variable image bytes]  # IMG_BYTES if format=1, else JPEG bytes
  [9 float32 K = 36 bytes]

The K block is *always* the last 36 bytes of the payload, regardless of
``format_id`` — the server slices it off before treating the rest as the
image.

Response:
  [4B uint32 payload_len]
  [4B magic "RSP\x01"]
  [4B int32 status]
  [v3d : 4*10475*3 f32]
  [transl: 4*1*3 f32]
  [scores: 4 f32]
  [betas: 4*10 f32]
  [expr : 4*10 f32]

Two extra features over the bare RPC:

* JPEG compression (``MULTIHMR_REMOTE_JPEG=1``, default ON, quality 80).
  Cuts wire bytes from ~1.35 MB to ~50-150 KB.

* Asynchronous double-buffer (``MULTIHMR_REMOTE_ASYNC=1``, default ON).
  ``infer()`` is decoupled from the I/O round-trip via a dedicated worker
  thread and two ``Queue(maxsize=1)`` slots. When the out-queue is empty
  ``infer()`` returns ``None`` — the worker loop reuses its last humans
  list so the visualiser keeps drawing.
"""
from __future__ import annotations

import logging
import os
import queue
import socket
import struct
import threading
import time
from typing import Any

import numpy as np

LOG = logging.getLogger("multihmr_remote")

IMG_SIZE = 672
N_PERSONS_FIXED = 4
N_VERTS = 10475

MAGIC_REQ = b"REQ\x01"
MAGIC_RSP = b"RSP\x01"

FORMAT_RAW = 1
FORMAT_JPEG = 2

IMG_BYTES = IMG_SIZE * IMG_SIZE * 3
K_BYTES = 9 * 4
REQ_HEADER = 4 + 1 + 3  # magic + format_id + 3-byte pad

V3D_BYTES = N_PERSONS_FIXED * N_VERTS * 3 * 4
TRANSL_BYTES = N_PERSONS_FIXED * 1 * 3 * 4
SCORES_BYTES = N_PERSONS_FIXED * 4
BETAS_BYTES = N_PERSONS_FIXED * 10 * 4
EXPR_BYTES = N_PERSONS_FIXED * 10 * 4
RSP_HEADER = 4 + 4
RSP_PAYLOAD_LEN = (RSP_HEADER + V3D_BYTES + TRANSL_BYTES
                  + SCORES_BYTES + BETAS_BYTES + EXPR_BYTES)


def _env_flag(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = bytearray(n)
    view = memoryview(buf)
    pos = 0
    while pos < n:
        got = sock.recv_into(view[pos:])
        if got == 0:
            raise ConnectionError("peer closed mid-stream")
        pos += got
    return bytes(buf)


def encode_request_raw(image_uint8_hwc: np.ndarray,
                       K_33: np.ndarray) -> bytes:
    """Raw uint8 HWC request (format_id=1, fixed payload length)."""
    if image_uint8_hwc.shape != (IMG_SIZE, IMG_SIZE, 3):
        raise ValueError(
            f"image shape {image_uint8_hwc.shape} != "
            f"({IMG_SIZE},{IMG_SIZE},3)")
    if image_uint8_hwc.dtype != np.uint8:
        raise ValueError(f"image dtype {image_uint8_hwc.dtype} != uint8")
    K = np.ascontiguousarray(K_33, dtype="<f4").reshape(9)
    img = np.ascontiguousarray(image_uint8_hwc, dtype=np.uint8)
    img_bytes = img.tobytes()
    header_after_magic = bytes([FORMAT_RAW, 0, 0, 0])
    payload_len = REQ_HEADER + len(img_bytes) + K_BYTES
    return b"".join([
        struct.pack("<I", payload_len),
        MAGIC_REQ,
        header_after_magic,
        img_bytes,
        K.tobytes(),
    ])


def encode_request_jpeg(jpeg_bytes: bytes, K_33: np.ndarray) -> bytes:
    """JPEG request (format_id=2, variable payload length)."""
    K = np.ascontiguousarray(K_33, dtype="<f4").reshape(9)
    header_after_magic = bytes([FORMAT_JPEG, 0, 0, 0])
    payload_len = REQ_HEADER + len(jpeg_bytes) + K_BYTES
    return b"".join([
        struct.pack("<I", payload_len),
        MAGIC_REQ,
        header_after_magic,
        jpeg_bytes,
        K.tobytes(),
    ])


def decode_response(payload: bytes) -> tuple[
        np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, int]:
    if len(payload) != RSP_PAYLOAD_LEN:
        raise ValueError(
            f"rsp payload {len(payload)} != {RSP_PAYLOAD_LEN}")
    if payload[:4] != MAGIC_RSP:
        raise ValueError(f"bad rsp magic {payload[:4]!r}")
    status = struct.unpack("<i", payload[4:8])[0]
    off = 8
    v3d = np.frombuffer(payload, dtype="<f4",
                        count=N_PERSONS_FIXED * N_VERTS * 3,
                        offset=off).reshape(N_PERSONS_FIXED, N_VERTS, 3)
    off += V3D_BYTES
    transl = np.frombuffer(payload, dtype="<f4",
                           count=N_PERSONS_FIXED * 1 * 3,
                           offset=off).reshape(N_PERSONS_FIXED, 1, 3)
    off += TRANSL_BYTES
    scores = np.frombuffer(payload, dtype="<f4",
                           count=N_PERSONS_FIXED,
                           offset=off).reshape(N_PERSONS_FIXED)
    off += SCORES_BYTES
    betas = np.frombuffer(payload, dtype="<f4",
                          count=N_PERSONS_FIXED * 10,
                          offset=off).reshape(N_PERSONS_FIXED, 10)
    off += BETAS_BYTES
    expr = np.frombuffer(payload, dtype="<f4",
                         count=N_PERSONS_FIXED * 10,
                         offset=off).reshape(N_PERSONS_FIXED, 10)
    return (v3d.copy(), transl.copy(), scores.copy(),
            betas.copy(), expr.copy(), int(status))


# Back-compat shim — old call sites used encode_request(img, K) for raw.
def encode_request(image_uint8_hwc: np.ndarray, K_33: np.ndarray) -> bytes:
    return encode_request_raw(image_uint8_hwc, K_33)


class _Tensorlike:
    """Mimics CoreMLArray to avoid a hard import on multihmr_coreml."""
    __slots__ = ("_arr",)

    def __init__(self, arr: np.ndarray) -> None:
        self._arr = arr

    def detach(self) -> "_Tensorlike":
        return self

    def cpu(self) -> "_Tensorlike":
        return self

    def numpy(self) -> np.ndarray:
        return self._arr

    def item(self) -> float:
        return float(self._arr.reshape(-1)[0])

    @property
    def shape(self) -> tuple[int, ...]:
        return tuple(self._arr.shape)


def _humans_from_arrays(v3d: np.ndarray, transl: np.ndarray,
                        scores: np.ndarray, betas: np.ndarray,
                        expr: np.ndarray, det_thresh: float
                        ) -> list[dict[str, Any]]:
    humans: list[dict[str, Any]] = []
    for k in range(N_PERSONS_FIXED):
        sc = float(scores[k])
        if sc < det_thresh:
            continue
        humans.append({
            "v3d": _Tensorlike(v3d[k]),
            "transl_pelvis": _Tensorlike(transl[k]),
            "scores": _Tensorlike(np.array([sc], dtype=np.float32)),
            "shape": _Tensorlike(betas[k]),
            "expression": _Tensorlike(expr[k]),
        })
    return humans


class MultiHMRRemoteBackend:
    """TCP client backend mirroring ``MultiHMRCoreMLBackend.infer`` API.

    JPEG compression and async double-buffering are toggleable via env
    (``MULTIHMR_REMOTE_JPEG``, ``MULTIHMR_REMOTE_ASYNC``).
    """

    def __init__(self, host: str = "192.168.0.175", port: int = 57140,
                 connect_timeout: float = 3.0,
                 io_timeout: float = 5.0) -> None:
        self.host = host
        self.port = port
        self.connect_timeout = connect_timeout
        self.io_timeout = io_timeout
        self._sock: socket.socket | None = None
        self._lock = threading.Lock()

        self.use_jpeg = _env_flag("MULTIHMR_REMOTE_JPEG", True)
        self.jpeg_quality = int(os.environ.get(
            "MULTIHMR_REMOTE_JPEG_QUALITY", "80"))
        self.use_async = _env_flag("MULTIHMR_REMOTE_ASYNC", True)

        # Async pipeline state.
        # Multi-buffer queues (2 in / 3 out) absorb jitter without
        # stalling capture. Drop-oldest semantics on overflow.
        self._in_q: queue.Queue[tuple[bytes, float, float]] = queue.Queue(
            maxsize=2)
        self._out_q: queue.Queue[
            tuple[list[dict[str, Any]], dict[str, float]]
        ] = queue.Queue(maxsize=3)
        self._stop = threading.Event()
        self._async_det_thresh = 0.3
        self._worker_thread: threading.Thread | None = None
        self._last_stats: dict[str, float] = {}

        if self.use_jpeg:
            try:
                import cv2  # noqa: F401
            except ImportError:
                LOG.warning("cv2 unavailable client-side, disabling JPEG")
                self.use_jpeg = False

        if self.use_async:
            self._start_worker()
        LOG.info(
            "MultiHMRRemoteBackend %s:%d (jpeg=%s q=%d, async=%s)",
            host, port, self.use_jpeg, self.jpeg_quality, self.use_async)

    # -- connection management -------------------------------------------

    def _connect(self) -> socket.socket:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(self.connect_timeout)
        sock.connect((self.host, self.port))
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.settimeout(self.io_timeout)
        LOG.info("connected to %s:%d", self.host, self.port)
        return sock

    def _ensure_sock(self) -> socket.socket:
        if self._sock is None:
            self._sock = self._connect()
        return self._sock

    def _drop_sock(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    @staticmethod
    def is_available(host: str | None = None, port: int | None = None
                     ) -> bool:
        host = host or os.environ.get(
            "MULTIHMR_REMOTE_HOST", "192.168.0.175")
        port = port or int(os.environ.get(
            "MULTIHMR_REMOTE_PORT", "57140"))
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1.0)
            s.connect((host, port))
            s.close()
            return True
        except OSError:
            return False

    # -- request encoding ------------------------------------------------

    def _encode_request_from_chw(
        self, image_chw_float32: np.ndarray, K_33: np.ndarray
    ) -> tuple[bytes, float]:
        """Return (request bytes, encode_ms)."""
        img = np.asarray(image_chw_float32, dtype=np.float32)
        if img.ndim == 4 and img.shape[0] == 1:
            img = img[0]
        if img.shape != (3, IMG_SIZE, IMG_SIZE):
            raise ValueError(
                f"image shape {img.shape} != (3,{IMG_SIZE},{IMG_SIZE})")
        img_hwc = np.clip(img.transpose(1, 2, 0) * 255.0, 0.0, 255.0
                          ).astype(np.uint8)
        K = np.asarray(K_33, dtype=np.float32)
        if K.ndim == 3 and K.shape[0] == 1:
            K = K[0]
        if K.shape != (3, 3):
            raise ValueError(f"K shape {K.shape} != (3,3)")

        t0 = time.monotonic()
        if self.use_jpeg:
            import cv2  # local import to keep optional
            # cv2.imencode wants BGR for nicest JPEG perceptually but the
            # server decodes back to RGB ; encode RGB->BGR once for parity.
            bgr = cv2.cvtColor(img_hwc, cv2.COLOR_RGB2BGR)
            ok, enc = cv2.imencode(
                ".jpg", bgr,
                [int(cv2.IMWRITE_JPEG_QUALITY), self.jpeg_quality])
            if not ok:
                raise RuntimeError("cv2.imencode failed")
            req = encode_request_jpeg(bytes(enc), K)
        else:
            req = encode_request_raw(img_hwc, K)
        enc_ms = (time.monotonic() - t0) * 1e3
        return req, enc_ms

    # -- synchronous fallback -------------------------------------------

    def _send_recv(self, req: bytes) -> bytes:
        attempts = 0
        last_err: Exception | None = None
        while attempts < 2:
            attempts += 1
            try:
                sock = self._ensure_sock()
                sock.sendall(req)
                len_buf = _recv_exact(sock, 4)
                payload_len = struct.unpack("<I", len_buf)[0]
                if payload_len != RSP_PAYLOAD_LEN:
                    raise ValueError(
                        f"unexpected rsp len {payload_len}")
                return _recv_exact(sock, payload_len)
            except (ConnectionError, BrokenPipeError, OSError,
                    socket.timeout) as e:
                LOG.warning("rpc failed (try %d): %s", attempts, e)
                self._drop_sock()
                last_err = e
        raise RuntimeError(f"remote inference failed: {last_err}")

    # -- async worker ---------------------------------------------------

    def _start_worker(self) -> None:
        self._worker_thread = threading.Thread(
            target=self._async_loop, name="multihmr-remote",
            daemon=True)
        self._worker_thread.start()

    def _async_loop(self) -> None:
        while not self._stop.is_set():
            try:
                req, t_submit, det_thresh = self._in_q.get(timeout=0.5)
            except queue.Empty:
                continue
            t_send = time.monotonic()
            try:
                with self._lock:
                    payload = self._send_recv(req)
            except Exception as e:  # noqa: BLE001
                LOG.warning("async send_recv failed: %s", e)
                continue
            t_recv = time.monotonic()
            try:
                v3d, transl, scores, betas, expr, status = decode_response(
                    payload)
            except Exception as e:  # noqa: BLE001
                LOG.warning("decode_response failed: %s", e)
                continue
            if status != 0:
                humans: list[dict[str, Any]] = []
            else:
                humans = _humans_from_arrays(
                    v3d, transl, scores, betas, expr, det_thresh)
            stats = {
                "queue_wait_ms": (t_send - t_submit) * 1e3,
                "rpc_ms": (t_recv - t_send) * 1e3,
            }
            # Drop any pending stale output before pushing.
            try:
                self._out_q.get_nowait()
            except queue.Empty:
                pass
            try:
                self._out_q.put_nowait((humans, stats))
            except queue.Full:
                pass

    # -- public API -----------------------------------------------------

    def infer(
        self,
        image_chw_float32: np.ndarray,
        K_33: np.ndarray,
        det_thresh: float = 0.3,
    ) -> list[dict[str, Any]] | None:
        """In sync mode returns the humans list (possibly empty).

        In async mode, submits the new frame (non-blocking, drop-newest
        if previous frame still in flight) and returns whatever output
        is ready in the out-queue. Returns ``None`` if nothing is ready
        yet — caller must reuse its last humans list.
        """
        req, _enc_ms = self._encode_request_from_chw(
            image_chw_float32, K_33)

        if not self.use_async:
            with self._lock:
                payload = self._send_recv(req)
            v3d, transl, scores, betas, expr, status = decode_response(
                payload)
            if status != 0:
                return []
            return _humans_from_arrays(
                v3d, transl, scores, betas, expr, det_thresh)

        # Async path.
        self._async_det_thresh = det_thresh
        # drop-newest semantics: keep the freshest pending frame
        try:
            self._in_q.get_nowait()
        except queue.Empty:
            pass
        try:
            self._in_q.put_nowait((req, time.monotonic(), det_thresh))
        except queue.Full:
            pass

        try:
            humans, stats = self._out_q.get_nowait()
        except queue.Empty:
            return None
        self._last_stats = stats
        return humans

    def close(self) -> None:
        self._stop.set()
        with self._lock:
            self._drop_sock()
