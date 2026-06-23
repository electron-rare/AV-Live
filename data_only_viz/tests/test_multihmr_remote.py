"""Tests for the Multi-HMR remote TCP backend (client-side).

A loopback server is spun up in a background thread; it returns
deterministic stub outputs so we can exercise the byte-for-byte
protocol without depending on a live mlpackage.
"""
from __future__ import annotations

import socket
import struct
import threading
import time

import numpy as np
import pytest

from data_only_viz.multihmr_remote import (
    IMG_SIZE,
    MAGIC_REQ,
    MAGIC_RSP,
    N_PERSONS_FIXED,
    N_VERTS,
    REQ_PAYLOAD_LEN,
    RSP_PAYLOAD_LEN,
    MultiHMRRemoteBackend,
    decode_response,
    encode_request,
)
from data_only_viz.scripts.multihmr_server import (
    decode_request,
    encode_response,
)


# -----------------------------------------------------------------------
# Pure protocol roundtrip tests (no socket, no model).
# -----------------------------------------------------------------------

def _make_K() -> np.ndarray:
    return np.array([[672.0, 0.0, 336.0],
                     [0.0, 672.0, 336.0],
                     [0.0, 0.0, 1.0]], dtype=np.float32)


def test_request_encode_decode_roundtrip():
    rng = np.random.default_rng(0)
    img = rng.integers(0, 256, (IMG_SIZE, IMG_SIZE, 3), dtype=np.uint8)
    K = _make_K()
    req = encode_request(img, K)
    # length prefix + payload
    assert len(req) == 4 + REQ_PAYLOAD_LEN
    payload_len = struct.unpack("<I", req[:4])[0]
    assert payload_len == REQ_PAYLOAD_LEN
    assert req[4:8] == MAGIC_REQ
    img_back, K_back = decode_request(req[4:])
    assert img_back.shape == (IMG_SIZE, IMG_SIZE, 3)
    np.testing.assert_array_equal(img_back, img)
    np.testing.assert_array_equal(K_back, K)


def test_response_encode_decode_roundtrip():
    rng = np.random.default_rng(1)
    v3d = rng.standard_normal(
        (N_PERSONS_FIXED, N_VERTS, 3)).astype(np.float32)
    transl = rng.standard_normal(
        (N_PERSONS_FIXED, 1, 3)).astype(np.float32)
    scores = rng.random(N_PERSONS_FIXED).astype(np.float32)
    betas = rng.standard_normal(
        (N_PERSONS_FIXED, 10)).astype(np.float32)
    expr = rng.standard_normal(
        (N_PERSONS_FIXED, 10)).astype(np.float32)
    resp = encode_response(v3d, transl, scores, betas, expr, status=0)
    assert len(resp) == 4 + RSP_PAYLOAD_LEN
    assert resp[4:8] == MAGIC_RSP
    v3d2, transl2, scores2, betas2, expr2, status = decode_response(resp[4:])
    assert status == 0
    np.testing.assert_array_equal(v3d2, v3d)
    np.testing.assert_array_equal(transl2, transl)
    np.testing.assert_array_equal(scores2, scores)
    np.testing.assert_array_equal(betas2, betas)
    np.testing.assert_array_equal(expr2, expr)


def test_request_rejects_wrong_dtype():
    img = np.zeros((IMG_SIZE, IMG_SIZE, 3), dtype=np.float32)
    with pytest.raises(ValueError):
        encode_request(img, _make_K())


def test_request_rejects_wrong_shape():
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    with pytest.raises(ValueError):
        encode_request(img, _make_K())


# -----------------------------------------------------------------------
# Loopback mock server: full client.infer() end-to-end.
# -----------------------------------------------------------------------

class _StubServer:
    """Minimal TCP server that replies with deterministic stub outputs."""

    def __init__(self, host: str = "127.0.0.1", port: int = 0) -> None:
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((host, port))
        self.sock.listen(1)
        self.sock.settimeout(2.0)
        self.host, self.port = self.sock.getsockname()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.requests_seen: list[tuple[np.ndarray, np.ndarray]] = []

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        try:
            self.sock.close()
        except OSError:
            pass
        if self._thread is not None:
            self._thread.join(timeout=2.0)

    @staticmethod
    def _stub_outputs() -> bytes:
        # Distinct values per person so the test can assert order.
        v3d = np.zeros((N_PERSONS_FIXED, N_VERTS, 3), dtype=np.float32)
        transl = np.zeros((N_PERSONS_FIXED, 1, 3), dtype=np.float32)
        betas = np.zeros((N_PERSONS_FIXED, 10), dtype=np.float32)
        expr = np.zeros((N_PERSONS_FIXED, 10), dtype=np.float32)
        for k in range(N_PERSONS_FIXED):
            v3d[k] = float(k + 1)
            transl[k] = float(k + 1) * 0.1
            betas[k] = float(k + 1) * 0.01
            expr[k] = float(k + 1) * 0.02
        scores = np.array([0.9, 0.8, 0.2, 0.1], dtype=np.float32)
        return encode_response(v3d, transl, scores, betas, expr, status=0)

    def _run(self) -> None:
        try:
            conn, _addr = self.sock.accept()
        except OSError:
            return
        conn.settimeout(2.0)
        try:
            while not self._stop.is_set():
                try:
                    len_buf = conn.recv(4)
                except socket.timeout:
                    continue
                if not len_buf or len(len_buf) < 4:
                    return
                payload_len = struct.unpack("<I", len_buf)[0]
                buf = bytearray()
                while len(buf) < payload_len:
                    chunk = conn.recv(payload_len - len(buf))
                    if not chunk:
                        return
                    buf.extend(chunk)
                img, K = decode_request(bytes(buf))
                self.requests_seen.append((img.copy(), K.copy()))
                conn.sendall(self._stub_outputs())
        finally:
            try:
                conn.close()
            except OSError:
                pass


@pytest.fixture
def stub_server():
    srv = _StubServer()
    srv.start()
    try:
        yield srv
    finally:
        srv.stop()


def test_remote_backend_infer_against_stub(stub_server: _StubServer):
    backend = MultiHMRRemoteBackend(
        host=stub_server.host, port=stub_server.port,
        connect_timeout=2.0, io_timeout=2.0)
    rng = np.random.default_rng(7)
    img = rng.random((3, IMG_SIZE, IMG_SIZE), dtype=np.float32)
    K = _make_K()
    humans = backend.infer(img, K, det_thresh=0.3)
    backend.close()

    # det_thresh 0.3 keeps scores 0.9 and 0.8 only.
    assert len(humans) == 2
    h0 = humans[0]
    v = h0["v3d"].detach().cpu().numpy()
    assert v.shape == (N_VERTS, 3)
    assert float(v[0, 0]) == pytest.approx(1.0)
    t = h0["transl_pelvis"].detach().cpu().numpy()
    assert t.shape == (1, 3)
    assert float(h0["scores"].item()) == pytest.approx(0.9, abs=1e-5)
    assert h0["shape"].detach().cpu().numpy().shape == (10,)
    assert h0["expression"].detach().cpu().numpy().shape == (10,)

    h1 = humans[1]
    assert float(h1["scores"].item()) == pytest.approx(0.8, abs=1e-5)

    # Server saw exactly one request, and the image round-tripped as
    # uint8 (we lose [0,1] precision but the shape and dtype are right).
    assert len(stub_server.requests_seen) == 1
    img_seen, K_seen = stub_server.requests_seen[0]
    assert img_seen.shape == (IMG_SIZE, IMG_SIZE, 3)
    assert img_seen.dtype == np.uint8
    np.testing.assert_array_equal(K_seen, K)


def test_remote_backend_threshold_filters_all(stub_server: _StubServer):
    backend = MultiHMRRemoteBackend(
        host=stub_server.host, port=stub_server.port)
    img = np.zeros((3, IMG_SIZE, IMG_SIZE), dtype=np.float32)
    humans = backend.infer(img, _make_K(), det_thresh=1.5)
    backend.close()
    assert humans == []


def test_is_available_returns_true_for_live_stub(stub_server: _StubServer):
    assert MultiHMRRemoteBackend.is_available(
        host=stub_server.host, port=stub_server.port) is True


def test_is_available_false_for_dead_port():
    # Bind+release a port to get a guaranteed-closed one.
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    _, port = s.getsockname()
    s.close()
    # Tiny race window: port may be reused by something else, but very
    # unlikely in unit-test scope.
    time.sleep(0.05)
    assert MultiHMRRemoteBackend.is_available(
        host="127.0.0.1", port=port) is False
