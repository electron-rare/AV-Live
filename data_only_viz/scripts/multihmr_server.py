"""Multi-HMR inference server (TCP, coremltools backend).

Runs on a remote Mac (macm1 in the AV-Live cluster), loads the
mlpackage via coremltools (Python 3.12), and serves frames over TCP.

Protocol (little-endian, persistent connection):

Request:
  [4 bytes uint32 payload_len]
  [4 bytes magic "REQ\\x01"]
  [1 byte uint8 format_id]   # 1 = raw RGB uint8 HWC, 2 = JPEG
  [3 bytes padding]
  [variable image bytes]      # IMG_BYTES if format=1, else JPEG bytes
  [9 float32 LE = 36 bytes K] # always last 36 bytes

Response:
  [4 bytes uint32 payload_len]
  [4 bytes magic "RSP\\x01"]
  [4 bytes int32 status]            # 0 = OK, 1 = error
  [v3d: 4*10475*3 float32]
  [transl: 4*1*3 float32]
  [scores: 4 float32]
  [betas: 4*10 float32]
  [expr: 4*10 float32]

Connection handler runs a 3-thread pipeline: reader -> worker -> writer.
While the worker predicts frame N, the reader has already buffered frame
N+1 so the next predict can start the instant the previous response is
handed to the writer. Queue depth is 2 to absorb network jitter.

Bench mode (--bench): synthetic frames against the loaded backend.
"""
from __future__ import annotations

import argparse
import logging
import os
import queue
import signal
import socket
import struct
import sys
import threading
import time
from pathlib import Path

import numpy as np

LOG = logging.getLogger("multihmr_server")

IMG_SIZE = 672
N_PERSONS_FIXED = 4
N_VERTS = 10475

MAGIC_REQ = b"REQ\x01"
MAGIC_RSP = b"RSP\x01"

FORMAT_RAW = 1
FORMAT_JPEG = 2

IMG_BYTES = IMG_SIZE * IMG_SIZE * 3                # 1_354_752
K_BYTES = 9 * 4                                    # 36
REQ_HEADER = 4 + 1 + 3                             # magic + fmt u8 + 3 pad

V3D_BYTES = N_PERSONS_FIXED * N_VERTS * 3 * 4
TRANSL_BYTES = N_PERSONS_FIXED * 1 * 3 * 4
SCORES_BYTES = N_PERSONS_FIXED * 4
BETAS_BYTES = N_PERSONS_FIXED * 10 * 4
EXPR_BYTES = N_PERSONS_FIXED * 10 * 4
RSP_HEADER = 4 + 4
RSP_PAYLOAD_LEN = (RSP_HEADER + V3D_BYTES + TRANSL_BYTES
                  + SCORES_BYTES + BETAS_BYTES + EXPR_BYTES)


DEFAULT_MLPACKAGE = Path(
    os.environ.get("MULTIHMR_MLPACKAGE")
    or str(Path.home() / ".cache" / "av-live-multihmr"
           / "multihmr_full_672_s.mlpackage"))

OUT_V3D = "var_2412"
OUT_TRANSL = "var_2415"
OUT_SCORES = "var_2428"
OUT_BETAS = "var_2431"
OUT_EXPR = "var_2434"


def recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = bytearray(n)
    view = memoryview(buf)
    pos = 0
    while pos < n:
        got = sock.recv_into(view[pos:])
        if got == 0:
            raise ConnectionError("peer closed")
        pos += got
    return bytes(buf)


def encode_response(v3d: np.ndarray, transl: np.ndarray,
                    scores: np.ndarray, betas: np.ndarray,
                    expr: np.ndarray, status: int = 0) -> bytes:
    parts = [
        struct.pack("<I", RSP_PAYLOAD_LEN),
        MAGIC_RSP,
        struct.pack("<i", status),
        np.ascontiguousarray(v3d, dtype=np.float32).tobytes(),
        np.ascontiguousarray(transl, dtype=np.float32).tobytes(),
        np.ascontiguousarray(scores, dtype=np.float32).tobytes(),
        np.ascontiguousarray(betas, dtype=np.float32).tobytes(),
        np.ascontiguousarray(expr, dtype=np.float32).tobytes(),
    ]
    return b"".join(parts)


def decode_request(payload: bytes) -> tuple[np.ndarray, np.ndarray, float]:
    """Decode a request payload (without the leading 4-byte length).

    Returns (image_uint8_hwc, K_33_f32, decode_ms_overhead).
    """
    if len(payload) < REQ_HEADER + K_BYTES:
        raise ValueError(f"req payload too short: {len(payload)}")
    magic = payload[:4]
    if magic != MAGIC_REQ:
        raise ValueError(f"bad magic {magic!r}")
    fmt = payload[4]
    # payload[5:8] reserved.
    img_end = len(payload) - K_BYTES
    img_bytes = payload[REQ_HEADER:img_end]
    K = np.frombuffer(payload, dtype="<f4", count=9,
                      offset=img_end).reshape(3, 3).astype(np.float32)
    t0 = time.monotonic()
    if fmt == FORMAT_RAW:
        if len(img_bytes) != IMG_BYTES:
            raise ValueError(
                f"raw img bytes {len(img_bytes)} != {IMG_BYTES}")
        img = np.frombuffer(img_bytes, dtype=np.uint8).reshape(
            IMG_SIZE, IMG_SIZE, 3)
    elif fmt == FORMAT_JPEG:
        import cv2
        arr = np.frombuffer(img_bytes, dtype=np.uint8)
        bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if bgr is None:
            raise ValueError("cv2.imdecode failed")
        if bgr.shape[:2] != (IMG_SIZE, IMG_SIZE):
            bgr = cv2.resize(bgr, (IMG_SIZE, IMG_SIZE))
        img = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    else:
        raise ValueError(f"unknown format_id {fmt}")
    decode_ms = (time.monotonic() - t0) * 1e3
    return img, K, decode_ms


ML_DTYPE_FLOAT16 = 65552
ML_DTYPE_FLOAT32 = 65568
ML_DTYPE_DOUBLE = 65600


def _np_to_mlarray(arr: np.ndarray, MLMultiArray):
    """Create a contiguous float32 MLMultiArray from a numpy array."""
    import ctypes
    arr = np.ascontiguousarray(arr, dtype=np.float32)
    shape = [int(s) for s in arr.shape]
    ml = MLMultiArray.alloc().initWithShape_dataType_error_(
        shape, ML_DTYPE_FLOAT32, None)
    if ml is None:
        raise RuntimeError("MLMultiArray alloc failed")
    ptr = ml.dataPointer()
    addr = int(ptr) if isinstance(ptr, int) else ctypes.cast(
        ptr, ctypes.c_void_p).value
    if addr is None:
        raise RuntimeError("MLMultiArray dataPointer null")
    ctypes.memmove(addr, arr.ctypes.data, arr.nbytes)
    return ml


def _mlarray_to_np(ml) -> np.ndarray:
    """Copy an MLMultiArray (FLOAT16/32/64) to numpy float32."""
    import ctypes
    shape = tuple(int(s) for s in ml.shape())
    dtype_id = int(ml.dataType())
    count = 1
    for s in shape:
        count *= s
    ptr = ml.dataPointer()
    addr = int(ptr) if isinstance(ptr, int) else ctypes.cast(
        ptr, ctypes.c_void_p).value
    if addr is None:
        raise RuntimeError("MLMultiArray dataPointer null")
    if dtype_id == ML_DTYPE_FLOAT16:
        raw = (ctypes.c_uint16 * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).view(np.float16).astype(np.float32)
    elif dtype_id == ML_DTYPE_FLOAT32:
        raw = (ctypes.c_float * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).copy()
    elif dtype_id == ML_DTYPE_DOUBLE:
        raw = (ctypes.c_double * count).from_address(addr)
        arr = np.ctypeslib.as_array(raw).astype(np.float32)
    else:
        raise RuntimeError(f"unsupported MLMultiArray dtype {dtype_id}")
    return arr.reshape(shape)


class CoreMLModel:
    """pyobjc-direct CoreML wrapper. Drops the ~30 ms coremltools.MLModel.predict
    overhead by using CoreML.framework directly (MLDictionaryFeatureProvider
    + MLMultiArray ctypes memcpy). Fallback to coremltools if pyobjc missing,
    via MULTIHMR_SERVER_BACKEND=coremltools env."""

    def __init__(self, mlpackage_path: Path) -> None:
        self.path = Path(mlpackage_path)
        if not self.path.exists():
            raise FileNotFoundError(f"mlpackage missing: {self.path}")
        backend = os.environ.get(
            "MULTIHMR_SERVER_BACKEND", "pyobjc").strip().lower()
        cu_env = os.environ.get(
            "COREML_COMPUTE_UNITS", "cpu_and_gpu").strip().lower()
        if backend == "pyobjc":
            self._use_pyobjc = True
            self._init_pyobjc(cu_env)
        else:
            self._use_pyobjc = False
            self._init_coremltools(cu_env)

    def _init_pyobjc(self, cu_env: str) -> None:
        import objc
        from Foundation import NSURL
        ns: dict = {}
        objc.loadBundle("CoreML", ns,
                        "/System/Library/Frameworks/CoreML.framework")
        cu_map = {"cpu_only": 0, "cpu_and_gpu": 1, "all": 2,
                  "cpu_and_ne": 3}
        cu = cu_map.get(cu_env, 1)
        MLModel = ns["MLModel"]
        MLModelConfiguration = ns["MLModelConfiguration"]
        cfg = MLModelConfiguration.alloc().init()
        try:
            cfg.setComputeUnits_(cu)
        except Exception:  # noqa: BLE001
            pass
        url = NSURL.fileURLWithPath_(str(self.path))
        compiled_url = MLModel.compileModelAtURL_error_(url, None)
        if compiled_url is None:
            raise RuntimeError(f"compileModelAtURL failed for {self.path}")
        model = MLModel.modelWithContentsOfURL_configuration_error_(
            compiled_url, cfg, None)
        if model is None:
            raise RuntimeError(f"MLModel load failed for {compiled_url}")
        self._model = model
        self._ns = ns
        LOG.info("loading mlpackage %s via pyobjc (computeUnit=%s)",
                 self.path.name, cu_env)

    def _init_coremltools(self, cu_env: str) -> None:
        import coremltools as ct
        from coremltools.models import MLModel as CTMLModel
        cu_map = {
            "cpu_only": ct.ComputeUnit.CPU_ONLY,
            "cpu_and_gpu": ct.ComputeUnit.CPU_AND_GPU,
            "all": ct.ComputeUnit.ALL,
            "cpu_and_ne": ct.ComputeUnit.CPU_AND_NE,
        }
        cu = cu_map.get(cu_env, ct.ComputeUnit.CPU_AND_GPU)
        LOG.info("loading mlpackage %s via coremltools (computeUnit=%s)",
                 self.path.name, cu_env)
        self.model = CTMLModel(str(self.path), compute_units=cu)

    def predict(self, image_uint8_hwc: np.ndarray, K_33: np.ndarray
                ) -> dict[str, np.ndarray]:
        img_chw = image_uint8_hwc.transpose(2, 0, 1).astype(np.float32) / 255.0
        img4 = img_chw[np.newaxis, ...]
        K = K_33.astype(np.float32)
        if K.ndim == 2:
            K = K[np.newaxis, ...]
        if self._use_pyobjc:
            return self._predict_pyobjc(img4, K)
        return self.model.predict({"image": img4, "cam_K": K})

    def _predict_pyobjc(self, image_4d: np.ndarray, K_33: np.ndarray
                        ) -> dict[str, np.ndarray]:
        ns = self._ns
        MLMultiArray = ns["MLMultiArray"]
        MLDictionaryFeatureProvider = ns["MLDictionaryFeatureProvider"]
        MLFeatureValue = ns["MLFeatureValue"]
        img_ml = _np_to_mlarray(image_4d, MLMultiArray)
        k_ml = _np_to_mlarray(K_33, MLMultiArray)
        feats = {
            "image": MLFeatureValue.featureValueWithMultiArray_(img_ml),
            "cam_K": MLFeatureValue.featureValueWithMultiArray_(k_ml),
        }
        provider = MLDictionaryFeatureProvider.alloc(
            ).initWithDictionary_error_(feats, None)
        if provider is None:
            raise RuntimeError("MLDictionaryFeatureProvider alloc failed")
        out = self._model.predictionFromFeatures_error_(provider, None)
        if out is None:
            raise RuntimeError("MLModel predict failed")
        names = [str(n) for n in out.featureNames()]
        result: dict[str, np.ndarray] = {}
        for n in names:
            fv = out.featureValueForName_(n)
            if fv is None:
                continue
            ml = fv.multiArrayValue()
            if ml is None:
                continue
            result[n] = _mlarray_to_np(ml)
        return result


def _zero_outputs() -> tuple[np.ndarray, ...]:
    return (
        np.zeros((N_PERSONS_FIXED, N_VERTS, 3), dtype=np.float32),
        np.zeros((N_PERSONS_FIXED, 1, 3), dtype=np.float32),
        np.zeros((N_PERSONS_FIXED,), dtype=np.float32),
        np.zeros((N_PERSONS_FIXED, 10), dtype=np.float32),
        np.zeros((N_PERSONS_FIXED, 10), dtype=np.float32),
    )


def _extract_outputs(raw: dict[str, np.ndarray]
                     ) -> tuple[np.ndarray, ...]:
    v3d = np.asarray(raw[OUT_V3D], dtype=np.float32).reshape(
        N_PERSONS_FIXED, N_VERTS, 3)
    transl = np.asarray(raw[OUT_TRANSL], dtype=np.float32).reshape(
        N_PERSONS_FIXED, 1, 3)
    scores = np.asarray(raw[OUT_SCORES], dtype=np.float32).reshape(
        N_PERSONS_FIXED)
    betas = np.asarray(raw[OUT_BETAS], dtype=np.float32).reshape(
        N_PERSONS_FIXED, 10)
    expr = np.asarray(raw[OUT_EXPR], dtype=np.float32).reshape(
        N_PERSONS_FIXED, 10)
    return v3d, transl, scores, betas, expr


class Server:
    def __init__(self, model: CoreMLModel, host: str, port: int) -> None:
        self.model = model
        self.host = host
        self.port = port
        self._stop = threading.Event()
        self._sock: socket.socket | None = None

    def stop(self) -> None:
        self._stop.set()
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass

    def serve(self) -> None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.host, self.port))
        sock.listen(4)
        sock.settimeout(1.0)
        self._sock = sock
        LOG.info("listening %s:%d", self.host, self.port)
        while not self._stop.is_set():
            try:
                conn, addr = sock.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            LOG.info("client connected %s", addr)
            try:
                self._handle_pipelined(conn)
            except (ConnectionError, BrokenPipeError, OSError) as e:
                LOG.info("client disconnected: %s", e)
            finally:
                try:
                    conn.close()
                except OSError:
                    pass
        LOG.info("server stopped")

    # -- pipelined per-connection handler -----------------------------

    def _handle_pipelined(self, conn: socket.socket) -> None:
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        conn_stop = threading.Event()

        # raw requests in, encoded responses out.
        req_q: queue.Queue[bytes] = queue.Queue(maxsize=2)
        rsp_q: queue.Queue[bytes] = queue.Queue(maxsize=2)

        # stats
        served = {"n": 0, "t0": time.monotonic(),
                  "sum_decode": 0.0, "sum_pred": 0.0,
                  "sum_encode": 0.0}

        def reader() -> None:
            try:
                while not conn_stop.is_set() and not self._stop.is_set():
                    len_buf = recv_exact(conn, 4)
                    payload_len = struct.unpack("<I", len_buf)[0]
                    if payload_len > 8 * 1024 * 1024:
                        raise ValueError(f"reqlen too big {payload_len}")
                    payload = recv_exact(conn, payload_len)
                    req_q.put(payload)
            except (ConnectionError, BrokenPipeError, OSError) as e:
                LOG.info("reader exit: %s", e)
            finally:
                conn_stop.set()
                # poison-pill the worker
                try:
                    req_q.put_nowait(b"")
                except queue.Full:
                    pass

        def worker() -> None:
            try:
                while not conn_stop.is_set() and not self._stop.is_set():
                    try:
                        payload = req_q.get(timeout=0.5)
                    except queue.Empty:
                        continue
                    if payload == b"":
                        break
                    try:
                        img, K, decode_ms = decode_request(payload)
                    except Exception as e:  # noqa: BLE001
                        LOG.warning("decode failed: %s", e)
                        v3d, transl, scores, betas, expr = _zero_outputs()
                        rsp_q.put(encode_response(
                            v3d, transl, scores, betas, expr, status=1))
                        continue
                    t_pred = time.monotonic()
                    try:
                        raw = self.model.predict(img, K)
                        v3d, transl, scores, betas, expr = _extract_outputs(
                            raw)
                        status = 0
                    except Exception as e:  # noqa: BLE001
                        LOG.warning("predict failed: %s", e)
                        v3d, transl, scores, betas, expr = _zero_outputs()
                        status = 1
                    t_pred_end = time.monotonic()
                    t_enc = time.monotonic()
                    rsp = encode_response(
                        v3d, transl, scores, betas, expr, status=status)
                    t_enc_end = time.monotonic()
                    pred_ms = (t_pred_end - t_pred) * 1e3
                    encode_ms = (t_enc_end - t_enc) * 1e3
                    served["n"] += 1
                    served["sum_decode"] += decode_ms
                    served["sum_pred"] += pred_ms
                    served["sum_encode"] += encode_ms
                    rsp_q.put(rsp)
                    now = time.monotonic()
                    if served["n"] % 30 == 0:
                        dt = now - served["t0"]
                        fps = served["n"] / max(1e-6, dt)
                        LOG.info(
                            "served %d frames at %.1f fps over %.1f s "
                            "(decode=%.1fms pred=%.1fms encode=%.1fms)",
                            served["n"], fps, dt,
                            served["sum_decode"] / served["n"],
                            served["sum_pred"] / served["n"],
                            served["sum_encode"] / served["n"])
            finally:
                conn_stop.set()
                try:
                    rsp_q.put_nowait(b"")
                except queue.Full:
                    pass

        def writer() -> None:
            try:
                while not conn_stop.is_set() and not self._stop.is_set():
                    try:
                        rsp = rsp_q.get(timeout=0.5)
                    except queue.Empty:
                        continue
                    if rsp == b"":
                        break
                    conn.sendall(rsp)
            except (ConnectionError, BrokenPipeError, OSError) as e:
                LOG.info("writer exit: %s", e)
            finally:
                conn_stop.set()

        t_r = threading.Thread(target=reader, name="srv-reader", daemon=True)
        t_w = threading.Thread(target=worker, name="srv-worker", daemon=True)
        t_x = threading.Thread(target=writer, name="srv-writer", daemon=True)
        t_r.start()
        t_w.start()
        t_x.start()
        t_r.join()
        t_w.join()
        t_x.join()
        dt = time.monotonic() - served["t0"]
        if served["n"] > 0:
            LOG.info("connection closed: served %d frames at %.1f fps "
                     "over %.1f s", served["n"],
                     served["n"] / max(1e-6, dt), dt)


def run_bench(model: CoreMLModel, n: int = 30) -> None:
    """Local synthetic bench (no socket)."""
    rng = np.random.default_rng(0)
    K = np.array([[672.0, 0.0, 336.0],
                  [0.0, 672.0, 336.0],
                  [0.0, 0.0, 1.0]], dtype=np.float32)
    img0 = rng.integers(0, 256, (IMG_SIZE, IMG_SIZE, 3), dtype=np.uint8)
    model.predict(img0, K)
    times = []
    for _ in range(n):
        img = rng.integers(0, 256, (IMG_SIZE, IMG_SIZE, 3), dtype=np.uint8)
        t0 = time.monotonic()
        model.predict(img, K)
        times.append((time.monotonic() - t0) * 1e3)
    ts = sorted(times)
    median = ts[len(ts) // 2]
    mean = sum(times) / len(times)
    p90 = ts[int(len(ts) * 0.9)]
    LOG.info("bench n=%d median=%.1fms mean=%.1fms p90=%.1fms (%.1f fps)",
             n, median, mean, p90, 1000.0 / median)


def run_bench_async(model: CoreMLModel, host: str, port: int,
                    n: int = 60) -> None:
    """End-to-end pipeline bench via real socket loopback."""
    import threading
    server = Server(model, host, port)
    th = threading.Thread(target=server.serve, daemon=True)
    th.start()
    time.sleep(0.5)
    try:
        from data_only_viz.multihmr_remote import MultiHMRRemoteBackend
    except ImportError:
        # When the server runs standalone, the client package may not be
        # importable. Skip with a friendly message.
        LOG.warning("data_only_viz package not importable on this host, "
                    "skipping --bench-async")
        server.stop()
        return
    os.environ.setdefault("MULTIHMR_REMOTE_HOST", host)
    os.environ.setdefault("MULTIHMR_REMOTE_PORT", str(port))
    be = MultiHMRRemoteBackend(host=host, port=port)
    rng = np.random.default_rng(0)
    K = np.array([[672.0, 0.0, 336.0],
                  [0.0, 672.0, 336.0],
                  [0.0, 0.0, 1.0]], dtype=np.float32)
    t0 = time.monotonic()
    got = 0
    for _ in range(n):
        img = (rng.random((3, IMG_SIZE, IMG_SIZE), dtype=np.float32))
        out = be.infer(img, K)
        if out is not None:
            got += 1
        time.sleep(0.01)
    dt = time.monotonic() - t0
    LOG.info("bench-async submitted=%d got=%d in %.2fs (%.1f fps submit)",
             n, got, dt, n / max(1e-6, dt))
    be.close()
    server.stop()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Multi-HMR TCP server")
    ap.add_argument("--mlpackage", type=Path, default=DEFAULT_MLPACKAGE)
    ap.add_argument("--host", default=os.environ.get(
        "MULTIHMR_SERVER_HOST", "0.0.0.0"))
    ap.add_argument("--port", type=int, default=int(os.environ.get(
        "MULTIHMR_SERVER_PORT", "57140")))
    ap.add_argument("--bench", action="store_true",
                    help="local synthetic bench, no socket")
    ap.add_argument("--bench-async", action="store_true",
                    help="loopback pipeline bench through real sockets")
    ap.add_argument("--bench-n", type=int, default=30)
    ap.add_argument("--log-level", default="INFO")
    args = ap.parse_args(argv)

    logging.basicConfig(
        level=args.log_level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s")

    model = CoreMLModel(args.mlpackage)

    if args.bench:
        run_bench(model, n=args.bench_n)
        return 0
    if args.bench_async:
        run_bench_async(model, "127.0.0.1", args.port, n=args.bench_n)
        return 0

    server = Server(model, args.host, args.port)

    def _sigint(*_a):
        LOG.info("SIGINT received, stopping")
        server.stop()

    signal.signal(signal.SIGINT, _sigint)
    signal.signal(signal.SIGTERM, _sigint)
    try:
        server.serve()
    except KeyboardInterrupt:
        server.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
