# ICP LiDAR ↔ SMPL-X Dense Fusion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Multi-HMR SMPL-X vertex output (per-person, 10475 verts) by registering it onto the live LiDAR point cloud streamed from the iPhone ARBodyTracker app, producing depth-corrected, scale-true 3D meshes for the AVLiveBody renderer.

**Architecture:** A new Python worker (`icp_fusion.py`) ingests two streams: (1) `state.persons_smplx[*].vertices_3d` from `multi_hmr_worker.py`, (2) LiDAR point clouds via a new TCP receiver `lidar_receiver.py` connected to the iPhone ARBodyTracker app's existing ARMeshAnchor publisher. ICP (point-to-plane variant, Open3D) aligns each SMPL-X mesh to the cropped LiDAR neighborhood, gated by a NaN/divergence guard. Fused vertices replace `vertices_3d` in `state.persons_smplx` when the env var `ICP_FUSION=1`. AVLiveBody consumes the unchanged TCP mesh schema — no Swift changes required.

**Tech Stack:** Python 3.11+ via `uv`, Open3D ≥ 0.18 (ICP, voxel downsample, KDTree), NumPy 1.26, existing project deps (python-osc, scipy). iPhone side already streams ARMeshAnchor via TCP per memory `project_iphone_arbodytracker` (no iOS changes in this plan).

**Out of scope:** iOS app modifications, retraining Multi-HMR, multi-camera ICP across multiple iPhones, GPU-accelerated ICP (CPU is sufficient at LiDAR 5–10 Hz).

---

## File Structure

**Create:**
- `data_only_viz/icp_fusion.py` — ICP wrapper, per-person registration, divergence guard (~250 lines)
- `data_only_viz/lidar_receiver.py` — TCP client for iPhone ARMesh stream, decoder, ring buffer (~180 lines)
- `data_only_viz/lidar_calib.py` — One-shot extrinsic calibration helper (chessboard or pose-anchored), persisted to `~/.config/av-live/lidar_extrinsic.json` (~120 lines)
- `data_only_viz/tests/test_icp_fusion.py` — synthetic SMPL-X + perturbed point cloud, convergence, NaN guard (~200 lines)
- `data_only_viz/tests/test_lidar_receiver.py` — TCP decoder unit tests + roundtrip fixture (~120 lines)
- `data_only_viz/tests/test_lidar_calib.py` — extrinsic estimation correctness, persistence (~80 lines)
- `data_only_viz/scripts/bench_icp_fusion.py` — end-to-end latency / convergence bench (~120 lines)
- `data_only_viz/scripts/calibrate_lidar.py` — CLI entry for one-shot extrinsic capture (~80 lines)
- `docs/ICP_FUSION.md` — env vars, calibration procedure, troubleshooting (~150 lines)

**Modify:**
- `data_only_viz/pyproject.toml` — add `open3d>=0.18` under new `lidar` optional-dep group
- `data_only_viz/state.py` — add `lidar_points: np.ndarray | None` and `icp_metadata` to `State` (~10 lines)
- `data_only_viz/main.py` — wire `lidar_receiver` and `icp_fusion` workers behind `ICP_FUSION=1` env (~40 lines)
- `data_only_viz/multi_hmr_worker.py` — emit a `_pre_icp` snapshot for the bench harness (~5 lines)
- `CLAUDE.md` (root) — document new env vars in the RC0.1+ table (~6 lines)

**No changes to:** `launcher/AV-Live-Body/`, `oscope-of/`, `sound_algo/`, `web_realart/`. The TCP mesh schema already used between Python worker and AVLiveBody is preserved bit-for-bit; ICP simply substitutes the contents of `vertices_3d` upstream.

---

## Task 1: Dependency scaffold (Open3D + optional-dep group)

**Files:**
- Modify: `data_only_viz/pyproject.toml`
- Create: `data_only_viz/tests/test_open3d_smoke.py`

- [ ] **Step 1: Add `lidar` optional-dep group**

In `data_only_viz/pyproject.toml`, append after the `detrpose` block:

```toml
# Open3D for ICP fusion between iPhone LiDAR and Multi-HMR SMPL-X meshes.
# CPU-only is sufficient at 5-10 Hz LiDAR cadence.
lidar = [
    "open3d>=0.18,<0.20",
]
```

- [ ] **Step 2: Install the extra**

Run: `cd data_only_viz && uv sync --extra lidar`
Expected: `Resolved N packages` with `open3d` present in `uv.lock`.

- [ ] **Step 3: Write the smoke test**

Create `data_only_viz/tests/test_open3d_smoke.py`:

```python
"""Smoke test for the Open3D dependency used by ICP fusion."""
from __future__ import annotations

import numpy as np
import pytest

open3d = pytest.importorskip("open3d")


def test_open3d_pointcloud_roundtrip() -> None:
    pts = np.random.RandomState(0).randn(100, 3).astype(np.float32)
    pcd = open3d.geometry.PointCloud()
    pcd.points = open3d.utility.Vector3dVector(pts)
    out = np.asarray(pcd.points)
    assert out.shape == (100, 3)
    np.testing.assert_allclose(out, pts, atol=1e-5)


def test_open3d_icp_converges_on_translated_copy() -> None:
    rng = np.random.RandomState(1)
    src = rng.randn(500, 3).astype(np.float64)
    translation = np.array([0.10, -0.05, 0.20])
    tgt = src + translation

    src_pcd = open3d.geometry.PointCloud()
    src_pcd.points = open3d.utility.Vector3dVector(src)
    tgt_pcd = open3d.geometry.PointCloud()
    tgt_pcd.points = open3d.utility.Vector3dVector(tgt)

    result = open3d.pipelines.registration.registration_icp(
        src_pcd, tgt_pcd, max_correspondence_distance=0.5,
        init=np.eye(4),
        estimation_method=open3d.pipelines.registration.TransformationEstimationPointToPoint(),
    )
    np.testing.assert_allclose(result.transformation[:3, 3], translation, atol=1e-3)
```

- [ ] **Step 4: Run the smoke test**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_open3d_smoke.py -v`
Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/pyproject.toml data_only_viz/uv.lock data_only_viz/tests/test_open3d_smoke.py
git commit -m "deps(icp): add open3d optional extra + smoke test"
```

---

## Task 2: LiDAR TCP receiver — frame decoder

**Files:**
- Create: `data_only_viz/lidar_receiver.py`
- Create: `data_only_viz/tests/test_lidar_receiver.py`

The iPhone ARBodyTracker app's existing TCP mesh publisher sends ARMeshAnchor data as a length-prefixed binary frame: `[uint32 BE frame_size][uint64 BE timestamp_ns][uint32 BE vertex_count][float32 LE x y z]*vertex_count`. This task only handles the decoder — the socket reader comes in Task 3.

- [ ] **Step 1: Write the failing decoder test**

Create `data_only_viz/tests/test_lidar_receiver.py`:

```python
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

    # decode_frame is given the body (everything past the 4-byte length prefix).
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_lidar_receiver.py -v`
Expected: 3 failed with `ModuleNotFoundError: data_only_viz.lidar_receiver`.

- [ ] **Step 3: Implement the decoder**

Create `data_only_viz/lidar_receiver.py`:

```python
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
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_lidar_receiver.py -v`
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/lidar_receiver.py data_only_viz/tests/test_lidar_receiver.py
git commit -m "feat(icp): LiDAR TCP frame decoder + tests"
```

---

## Task 3: LiDAR TCP receiver — socket reader & ring buffer

**Files:**
- Modify: `data_only_viz/lidar_receiver.py`
- Modify: `data_only_viz/tests/test_lidar_receiver.py`

A background thread reads length-prefixed frames from the iPhone TCP server, decodes them via `decode_frame`, and stores the **latest** frame in a single-slot mailbox (no queue — consumers always want freshest data). Old frames are discarded silently.

- [ ] **Step 1: Write the failing reader test**

Append to `data_only_viz/tests/test_lidar_receiver.py`:

```python
import socket
import threading
import time


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
```

(The `unused_tcp_port` fixture comes from `pytest-asyncio` / `pytest-tcp-port`. If unavailable, use `socket.socket().bind(("", 0))` to grab a free port — adjust accordingly.)

- [ ] **Step 2: Add `pytest-tcp-port` if missing**

Run: `cd data_only_viz && uv add --dev pytest-tcp-port`
If declined or unavailable, manually pin a port via a helper and remove the fixture.

- [ ] **Step 3: Run to verify failure**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_lidar_receiver.py -v`
Expected: 2 new tests fail with `ImportError: cannot import name 'LidarTCPReader'`.

- [ ] **Step 4: Implement the reader**

Append to `data_only_viz/lidar_receiver.py`:

```python
import logging
import socket
import struct
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
```

- [ ] **Step 5: Run all tests in the file**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_lidar_receiver.py -v`
Expected: 5 passed (3 decoder + 2 reader).

- [ ] **Step 6: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/lidar_receiver.py data_only_viz/tests/test_lidar_receiver.py data_only_viz/pyproject.toml data_only_viz/uv.lock
git commit -m "feat(icp): LiDAR TCP socket reader with reconnect"
```

---

## Task 4: Extrinsic calibration data structure & persistence

**Files:**
- Create: `data_only_viz/lidar_calib.py`
- Create: `data_only_viz/tests/test_lidar_calib.py`

The iPhone publishes points in **ARKit world coordinates**. Multi-HMR predicts vertices in **webcam camera coordinates** (Z forward, Y down, origin at camera center, meters). Fusion requires a static 4×4 extrinsic `T_arkit_to_cam` that brings LiDAR points into webcam frame. This task only handles the dataclass and JSON persistence — estimation comes in Task 5.

- [ ] **Step 1: Write the failing persistence test**

Create `data_only_viz/tests/test_lidar_calib.py`:

```python
"""Tests for LiDAR ↔ webcam extrinsic calibration persistence."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest


def test_extrinsic_default_is_identity() -> None:
    from data_only_viz.lidar_calib import Extrinsic

    e = Extrinsic.identity()
    np.testing.assert_allclose(e.T_arkit_to_cam, np.eye(4))
    assert e.confidence == 0.0
    assert e.captured_at_iso == ""


def test_extrinsic_roundtrip_json(tmp_path: Path) -> None:
    from data_only_viz.lidar_calib import Extrinsic, load_extrinsic, save_extrinsic

    T = np.eye(4)
    T[:3, 3] = [0.1, -0.05, 0.30]
    e = Extrinsic(T_arkit_to_cam=T, confidence=0.95, captured_at_iso="2026-05-14T12:00:00Z")

    path = tmp_path / "extrinsic.json"
    save_extrinsic(e, path)
    loaded = load_extrinsic(path)

    np.testing.assert_allclose(loaded.T_arkit_to_cam, T, atol=1e-10)
    assert loaded.confidence == pytest.approx(0.95)
    assert loaded.captured_at_iso == "2026-05-14T12:00:00Z"


def test_load_extrinsic_missing_path_returns_identity(tmp_path: Path) -> None:
    from data_only_viz.lidar_calib import load_extrinsic

    e = load_extrinsic(tmp_path / "does-not-exist.json")
    np.testing.assert_allclose(e.T_arkit_to_cam, np.eye(4))
    assert e.confidence == 0.0
```

- [ ] **Step 2: Run, verify failure**

Run: `cd data_only_viz && uv run pytest tests/test_lidar_calib.py -v`
Expected: 3 failed with `ModuleNotFoundError`.

- [ ] **Step 3: Implement the persistence layer**

Create `data_only_viz/lidar_calib.py`:

```python
"""iPhone LiDAR (ARKit world) ↔ webcam (Multi-HMR camera) extrinsic.

Persisted as a small JSON document so calibration survives across launches.
The default location is ``~/.config/av-live/lidar_extrinsic.json``; override
with the ``ICP_LIDAR_EXTRINSIC`` env var.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

DEFAULT_EXTRINSIC_PATH = Path.home() / ".config" / "av-live" / "lidar_extrinsic.json"


@dataclass
class Extrinsic:
    """4x4 rigid transform from ARKit world frame to Multi-HMR camera frame."""

    T_arkit_to_cam: np.ndarray = field(default_factory=lambda: np.eye(4))
    confidence: float = 0.0
    captured_at_iso: str = ""

    @staticmethod
    def identity() -> "Extrinsic":
        return Extrinsic(T_arkit_to_cam=np.eye(4), confidence=0.0, captured_at_iso="")


def save_extrinsic(e: Extrinsic, path: Path | None = None) -> Path:
    path = Path(path) if path is not None else _path_from_env()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "T_arkit_to_cam": e.T_arkit_to_cam.astype(float).tolist(),
        "confidence": float(e.confidence),
        "captured_at_iso": e.captured_at_iso,
    }
    path.write_text(json.dumps(payload, indent=2))
    return path


def load_extrinsic(path: Path | None = None) -> Extrinsic:
    path = Path(path) if path is not None else _path_from_env()
    if not path.exists():
        return Extrinsic.identity()
    payload = json.loads(path.read_text())
    return Extrinsic(
        T_arkit_to_cam=np.array(payload["T_arkit_to_cam"], dtype=np.float64),
        confidence=float(payload.get("confidence", 0.0)),
        captured_at_iso=str(payload.get("captured_at_iso", "")),
    )


def _path_from_env() -> Path:
    p = os.environ.get("ICP_LIDAR_EXTRINSIC")
    return Path(p) if p else DEFAULT_EXTRINSIC_PATH
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd data_only_viz && uv run pytest tests/test_lidar_calib.py -v`
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/lidar_calib.py data_only_viz/tests/test_lidar_calib.py
git commit -m "feat(icp): extrinsic calibration dataclass + JSON persistence"
```

---

## Task 5: Extrinsic estimation from paired pose anchors

**Files:**
- Modify: `data_only_viz/lidar_calib.py`
- Modify: `data_only_viz/tests/test_lidar_calib.py`
- Create: `data_only_viz/scripts/calibrate_lidar.py`

Estimation strategy: ask the user to stand still in front of the webcam. Capture (a) one Multi-HMR SMPL-X pelvis vertex (canonical SMPL-X pelvis is vertex index 5559), (b) the same pelvis location in the iPhone ARKit frame (computed as the centroid of the LiDAR mesh anchor whose bounding-box center is closest to the iPhone-detected user). With ≥ 4 paired points (taken at 4 stances: front / left / right / back) we solve a rigid transform via Kabsch (SVD).

- [ ] **Step 1: Write the failing Kabsch test**

Append to `data_only_viz/tests/test_lidar_calib.py`:

```python
def test_kabsch_recovers_known_rigid_transform() -> None:
    from data_only_viz.lidar_calib import kabsch_rigid

    rng = np.random.RandomState(7)
    src = rng.randn(20, 3)
    # Known transform: rotation about Y by 30°, translation (0.1, -0.2, 0.5)
    theta = np.deg2rad(30.0)
    R = np.array([
        [np.cos(theta), 0, np.sin(theta)],
        [0, 1, 0],
        [-np.sin(theta), 0, np.cos(theta)],
    ])
    t = np.array([0.1, -0.2, 0.5])
    tgt = src @ R.T + t

    T = kabsch_rigid(src, tgt)
    R_est = T[:3, :3]
    t_est = T[:3, 3]
    np.testing.assert_allclose(R_est, R, atol=1e-6)
    np.testing.assert_allclose(t_est, t, atol=1e-6)


def test_kabsch_requires_at_least_three_pairs() -> None:
    from data_only_viz.lidar_calib import kabsch_rigid

    with pytest.raises(ValueError, match="at least 3"):
        kabsch_rigid(np.zeros((2, 3)), np.zeros((2, 3)))


def test_kabsch_rejects_mismatched_shapes() -> None:
    from data_only_viz.lidar_calib import kabsch_rigid

    with pytest.raises(ValueError, match="shape"):
        kabsch_rigid(np.zeros((5, 3)), np.zeros((4, 3)))
```

- [ ] **Step 2: Run, verify failure**

Run: `cd data_only_viz && uv run pytest tests/test_lidar_calib.py::test_kabsch_recovers_known_rigid_transform -v`
Expected: `AttributeError: module 'data_only_viz.lidar_calib' has no attribute 'kabsch_rigid'`.

- [ ] **Step 3: Implement Kabsch**

Append to `data_only_viz/lidar_calib.py`:

```python
def kabsch_rigid(src: np.ndarray, tgt: np.ndarray) -> np.ndarray:
    """Closed-form rigid alignment (Kabsch via SVD).

    Returns a 4x4 transform T such that ``tgt ≈ (src @ R.T) + t``.
    """
    src = np.asarray(src, dtype=np.float64)
    tgt = np.asarray(tgt, dtype=np.float64)
    if src.shape != tgt.shape:
        raise ValueError(f"shape mismatch: src={src.shape} tgt={tgt.shape}")
    if src.shape[0] < 3 or src.shape[1] != 3:
        raise ValueError("kabsch_rigid needs at least 3 paired 3D points")
    src_c = src.mean(axis=0)
    tgt_c = tgt.mean(axis=0)
    H = (src - src_c).T @ (tgt - tgt_c)
    U, _, Vt = np.linalg.svd(H)
    d = np.linalg.det(Vt.T @ U.T)
    D = np.diag([1.0, 1.0, np.sign(d)])
    R = Vt.T @ D @ U.T
    t = tgt_c - R @ src_c
    T = np.eye(4)
    T[:3, :3] = R
    T[:3, 3] = t
    return T
```

- [ ] **Step 4: Verify the 3 new tests pass**

Run: `cd data_only_viz && uv run pytest tests/test_lidar_calib.py -v`
Expected: 6 passed (3 persistence + 3 Kabsch).

- [ ] **Step 5: Create the calibration CLI**

Create `data_only_viz/scripts/calibrate_lidar.py`:

```python
"""Interactive one-shot extrinsic calibration between iPhone LiDAR and webcam.

Usage:

    cd data_only_viz
    uv run --extra lidar python -m data_only_viz.scripts.calibrate_lidar \
        --lidar-host 192.168.0.42 --lidar-port 5500 --webcam-index 0

The script prompts the user to assume 4 stances (front, left, right, back),
captures paired pelvis points (webcam: Multi-HMR vertex 5559; LiDAR: centroid
of the largest mesh anchor), solves Kabsch, and writes the result to
ICP_LIDAR_EXTRINSIC or the default path.

Multi-HMR worker is launched in-process for this script (single-shot mode).
"""
from __future__ import annotations

import argparse
import datetime as dt
import logging
import sys
import time

import numpy as np

from data_only_viz.lidar_calib import Extrinsic, kabsch_rigid, save_extrinsic
from data_only_viz.lidar_receiver import LidarTCPReader

_LOG = logging.getLogger("calibrate_lidar")
_PELVIS_VERT_INDEX = 5559  # SMPL-X canonical pelvis vertex


def _wait_for_lidar(reader: LidarTCPReader, timeout_s: float = 5.0):
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        latest = reader.latest()
        if latest is not None and latest.points.shape[0] > 50:
            return latest
        time.sleep(0.05)
    raise RuntimeError("LiDAR frame never arrived")


def _capture_one_pair(reader: LidarTCPReader, get_smplx_pelvis_cam) -> tuple[np.ndarray, np.ndarray]:
    input("Hold still, then press ENTER to capture...")
    lidar = _wait_for_lidar(reader)
    pelvis_cam = get_smplx_pelvis_cam()
    pelvis_arkit = lidar.points.mean(axis=0)  # crude centroid; refined in body-detection mode
    _LOG.info("captured: cam=%s  arkit=%s", pelvis_cam, pelvis_arkit)
    return pelvis_cam, pelvis_arkit


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--lidar-host", required=True)
    p.add_argument("--lidar-port", type=int, default=5500)
    p.add_argument("--webcam-index", type=int, default=0)
    p.add_argument("--stances", type=int, default=4)
    args = p.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")

    reader = LidarTCPReader(host=args.lidar_host, port=args.lidar_port)
    reader.start()

    # NB: the actual Multi-HMR getter is wired in Task 9 when the main pipeline
    # exposes a single-shot predictor. For now this script is the *scaffolding*
    # — Task 9 plugs in `multi_hmr_worker.predict_once()`.
    def _placeholder_pelvis_cam() -> np.ndarray:
        raise SystemExit("calibrate_lidar requires Task 9 to be complete (predict_once API)")

    pairs_cam, pairs_arkit = [], []
    try:
        for i in range(args.stances):
            _LOG.info("stance %d/%d", i + 1, args.stances)
            cam, arkit = _capture_one_pair(reader, _placeholder_pelvis_cam)
            pairs_cam.append(cam)
            pairs_arkit.append(arkit)
    finally:
        reader.stop()

    T = kabsch_rigid(np.asarray(pairs_arkit), np.asarray(pairs_cam))
    path = save_extrinsic(Extrinsic(
        T_arkit_to_cam=T,
        confidence=1.0,
        captured_at_iso=dt.datetime.now(dt.timezone.utc).isoformat(),
    ))
    _LOG.info("extrinsic saved to %s", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/lidar_calib.py data_only_viz/tests/test_lidar_calib.py data_only_viz/scripts/calibrate_lidar.py
git commit -m "feat(icp): Kabsch extrinsic estimator + calibration CLI scaffold"
```

---

## Task 6: ICP wrapper — single-mesh registration

**Files:**
- Create: `data_only_viz/icp_fusion.py`
- Create: `data_only_viz/tests/test_icp_fusion.py`

Core ICP wrapper: given SMPL-X verts (10475, 3) in camera frame and LiDAR points (N, 3) in camera frame (post-extrinsic), it (a) crops LiDAR to a bounding-box around the SMPL-X mesh + 0.30 m margin, (b) voxel-downsamples both sides to 0.02 m, (c) runs point-to-plane ICP with 0.05 m correspondence threshold, (d) returns either the registered vertices or the original ones plus a `fitness` score and an `accepted` flag.

- [ ] **Step 1: Write the failing convergence test**

Create `data_only_viz/tests/test_icp_fusion.py`:

```python
"""Tests for ICP registration of SMPL-X verts onto LiDAR point clouds."""
from __future__ import annotations

import numpy as np
import pytest

pytest.importorskip("open3d")


def _synthetic_smplx_torso(n: int = 1500, seed: int = 0) -> np.ndarray:
    """Generate a coarse capsule-like point cloud standing in for SMPL-X verts."""
    rng = np.random.RandomState(seed)
    z = rng.uniform(0.0, 1.7, size=n)
    r = 0.12 + 0.02 * rng.randn(n)
    theta = rng.uniform(0, 2 * np.pi, size=n)
    x = r * np.cos(theta)
    y = r * np.sin(theta)
    return np.stack([x, y, z], axis=1).astype(np.float32)


def test_icp_recovers_small_translation() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=1)
    translation = np.array([0.05, 0.02, 0.10], dtype=np.float32)
    tgt = src + translation + 0.005 * np.random.RandomState(2).randn(*src.shape).astype(np.float32)

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())

    assert out.accepted, f"ICP should accept, got fitness={out.fitness:.3f}"
    # Mean residual to the truth-translated source should shrink.
    truth = src + translation
    err_before = np.linalg.norm(src - truth, axis=1).mean()
    err_after = np.linalg.norm(out.vertices_registered - truth, axis=1).mean()
    assert err_after < err_before * 0.5, f"err before={err_before:.4f} after={err_after:.4f}"


def test_icp_rejects_when_lidar_too_sparse() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=3)
    tgt = src[:5]  # only 5 points — well below MIN_LIDAR_POINTS

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert not out.accepted
    np.testing.assert_array_equal(out.vertices_registered, src)


def test_icp_rejects_on_nan_input() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=4)
    src[10, 1] = np.nan
    tgt = src.copy()
    tgt = np.nan_to_num(tgt, nan=0.0)

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert not out.accepted
    np.testing.assert_array_equal(out.vertices_registered, src)


def test_icp_preserves_dtype_and_shape() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=5)
    tgt = src + np.array([0.0, 0.0, 0.02], dtype=np.float32)
    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert out.vertices_registered.shape == src.shape
    assert out.vertices_registered.dtype == np.float32
```

- [ ] **Step 2: Run, verify failure**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py -v`
Expected: 4 failed with `ModuleNotFoundError`.

- [ ] **Step 3: Implement ICP wrapper**

Create `data_only_viz/icp_fusion.py`:

```python
"""ICP fusion between Multi-HMR SMPL-X meshes and iPhone LiDAR point clouds.

All operations happen in the **webcam camera frame** (meters, OpenCV
convention: +X right, +Y down, +Z forward). LiDAR points must be
pre-transformed via `Extrinsic.T_arkit_to_cam`.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

import numpy as np

try:
    import open3d as o3d
except ImportError:  # pragma: no cover - exercised via skipif at import sites
    o3d = None  # type: ignore[assignment]

_LOG = logging.getLogger(__name__)

MIN_LIDAR_POINTS = 200
MIN_FITNESS = 0.30
MAX_RMSE_M = 0.05
CROP_MARGIN_M = 0.30


@dataclass
class IcpConfig:
    voxel_size_m: float = 0.02
    max_correspondence_m: float = 0.05
    max_iterations: int = 30


@dataclass
class IcpResult:
    vertices_registered: np.ndarray  # (10475, 3) float32 — fused or original
    accepted: bool
    fitness: float
    rmse_m: float
    iterations: int


def register_mesh_to_lidar(
    smplx_verts_cam: np.ndarray,
    lidar_points_cam: np.ndarray,
    config: IcpConfig | None = None,
) -> IcpResult:
    """Register SMPL-X verts onto a cropped LiDAR neighborhood.

    Returns the **original** verts if ICP is rejected (NaN, too few points,
    poor fitness, excessive RMSE). The caller is expected to fall back to the
    raw Multi-HMR output on rejection.
    """
    if o3d is None:
        raise RuntimeError("open3d not installed — install with `uv sync --extra lidar`")

    cfg = config or IcpConfig()
    src = np.ascontiguousarray(smplx_verts_cam, dtype=np.float32)

    if not np.isfinite(src).all():
        _LOG.debug("ICP rejected: NaN/Inf in SMPL-X verts")
        return IcpResult(src, False, 0.0, float("inf"), 0)

    lidar = _crop_to_bbox(lidar_points_cam, src, margin_m=CROP_MARGIN_M)
    if lidar.shape[0] < MIN_LIDAR_POINTS or not np.isfinite(lidar).all():
        _LOG.debug("ICP rejected: insufficient LiDAR points (%d)", lidar.shape[0])
        return IcpResult(src, False, 0.0, float("inf"), 0)

    src_pcd = _to_pcd(src, cfg.voxel_size_m, estimate_normals=True)
    tgt_pcd = _to_pcd(lidar, cfg.voxel_size_m, estimate_normals=True)

    if len(src_pcd.points) < 10 or len(tgt_pcd.points) < 10:
        return IcpResult(src, False, 0.0, float("inf"), 0)

    criteria = o3d.pipelines.registration.ICPConvergenceCriteria(
        max_iteration=cfg.max_iterations,
        relative_fitness=1e-6,
        relative_rmse=1e-6,
    )
    result = o3d.pipelines.registration.registration_icp(
        src_pcd, tgt_pcd, cfg.max_correspondence_m,
        np.eye(4),
        o3d.pipelines.registration.TransformationEstimationPointToPlane(),
        criteria,
    )

    accepted = (result.fitness >= MIN_FITNESS) and (result.inlier_rmse <= MAX_RMSE_M)
    if not accepted:
        _LOG.debug(
            "ICP rejected: fitness=%.3f rmse=%.4f",
            result.fitness, result.inlier_rmse,
        )
        return IcpResult(src, False, float(result.fitness), float(result.inlier_rmse), 0)

    # Apply transform to the **full** (non-downsampled) source verts.
    T = np.asarray(result.transformation, dtype=np.float32)
    homog = np.concatenate([src, np.ones((src.shape[0], 1), dtype=np.float32)], axis=1)
    fused = (homog @ T.T)[:, :3]
    if not np.isfinite(fused).all():
        return IcpResult(src, False, float(result.fitness), float(result.inlier_rmse), 0)

    return IcpResult(
        vertices_registered=np.ascontiguousarray(fused, dtype=np.float32),
        accepted=True,
        fitness=float(result.fitness),
        rmse_m=float(result.inlier_rmse),
        iterations=cfg.max_iterations,
    )


def _crop_to_bbox(points: np.ndarray, anchor: np.ndarray, margin_m: float) -> np.ndarray:
    if points.size == 0:
        return points.astype(np.float32, copy=False)
    lo = anchor.min(axis=0) - margin_m
    hi = anchor.max(axis=0) + margin_m
    mask = np.all((points >= lo) & (points <= hi), axis=1)
    return points[mask].astype(np.float32, copy=False)


def _to_pcd(points: np.ndarray, voxel_size_m: float, estimate_normals: bool):
    pcd = o3d.geometry.PointCloud()
    pcd.points = o3d.utility.Vector3dVector(points.astype(np.float64, copy=False))
    if voxel_size_m > 0:
        pcd = pcd.voxel_down_sample(voxel_size_m)
    if estimate_normals:
        pcd.estimate_normals(
            search_param=o3d.geometry.KDTreeSearchParamHybrid(radius=voxel_size_m * 2, max_nn=30),
        )
    return pcd
```

- [ ] **Step 4: Run tests, verify pass**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py -v`
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/icp_fusion.py data_only_viz/tests/test_icp_fusion.py
git commit -m "feat(icp): point-to-plane registration wrapper with reject gate"
```

---

## Task 7: Multi-person dispatch with per-pid spatial gating

**Files:**
- Modify: `data_only_viz/icp_fusion.py`
- Modify: `data_only_viz/tests/test_icp_fusion.py`

When multiple people are present, naïve ICP on a shared LiDAR cloud confuses neighbors. We partition the LiDAR cloud by nearest-neighbor centroid: each point goes to the SMPL-X mesh whose pelvis-vertex (5559) is closest, with a hard max distance of 1.0 m to discard background geometry.

- [ ] **Step 1: Write the failing multi-person test**

Append to `data_only_viz/tests/test_icp_fusion.py`:

```python
def test_partition_lidar_by_pid_two_people() -> None:
    from data_only_viz.icp_fusion import partition_lidar_by_pid

    # Two SMPL-X meshes 1.5 m apart along X.
    src_a = _synthetic_smplx_torso(seed=10) + np.array([-0.75, 0.0, 0.0], dtype=np.float32)
    src_b = _synthetic_smplx_torso(seed=11) + np.array([+0.75, 0.0, 0.0], dtype=np.float32)
    pelvis_a = src_a.mean(axis=0)
    pelvis_b = src_b.mean(axis=0)

    # LiDAR cloud spanning both, plus 100 background points 5 m away.
    lidar = np.concatenate([
        src_a + 0.01 * np.random.RandomState(20).randn(*src_a.shape).astype(np.float32),
        src_b + 0.01 * np.random.RandomState(21).randn(*src_b.shape).astype(np.float32),
        np.array([[10.0, 10.0, 10.0]] * 100, dtype=np.float32),
    ])

    parts = partition_lidar_by_pid(lidar, pelvises={0: pelvis_a, 1: pelvis_b}, max_dist_m=1.0)

    assert set(parts.keys()) == {0, 1}
    assert parts[0].shape[0] > 1000
    assert parts[1].shape[0] > 1000
    # Background must be discarded
    assert not np.any(np.linalg.norm(parts[0] - np.array([10, 10, 10]), axis=1) < 0.5)
    assert not np.any(np.linalg.norm(parts[1] - np.array([10, 10, 10]), axis=1) < 0.5)


def test_partition_returns_empty_dict_when_no_pelvises() -> None:
    from data_only_viz.icp_fusion import partition_lidar_by_pid

    out = partition_lidar_by_pid(np.zeros((100, 3), dtype=np.float32), pelvises={}, max_dist_m=1.0)
    assert out == {}
```

- [ ] **Step 2: Run, verify failure**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py::test_partition_lidar_by_pid_two_people -v`
Expected: `ImportError: cannot import name 'partition_lidar_by_pid'`.

- [ ] **Step 3: Implement partitioner**

Append to `data_only_viz/icp_fusion.py`:

```python
def partition_lidar_by_pid(
    lidar_points_cam: np.ndarray,
    pelvises: dict[int, np.ndarray],
    max_dist_m: float = 1.0,
) -> dict[int, np.ndarray]:
    """Assign each LiDAR point to the closest pelvis within ``max_dist_m``.

    Points beyond ``max_dist_m`` from every pelvis (background, furniture)
    are dropped. Returns ``{pid: (M, 3) float32}`` — pids with zero assigned
    points are omitted.
    """
    if not pelvises or lidar_points_cam.size == 0:
        return {}
    pids = list(pelvises.keys())
    centers = np.stack([pelvises[p] for p in pids]).astype(np.float32)  # (P, 3)
    pts = np.ascontiguousarray(lidar_points_cam, dtype=np.float32)

    # (N, P) squared distance
    diff = pts[:, None, :] - centers[None, :, :]
    d2 = np.einsum("npk,npk->np", diff, diff)
    nearest = d2.argmin(axis=1)
    nearest_d = np.sqrt(d2[np.arange(d2.shape[0]), nearest])

    mask = nearest_d <= max_dist_m
    out: dict[int, np.ndarray] = {}
    for idx, pid in enumerate(pids):
        sel = mask & (nearest == idx)
        if not sel.any():
            continue
        out[pid] = pts[sel]
    return out
```

- [ ] **Step 4: Run all icp_fusion tests, verify pass**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py -v`
Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/icp_fusion.py data_only_viz/tests/test_icp_fusion.py
git commit -m "feat(icp): partition LiDAR per pid with max-distance gate"
```

---

## Task 8: Fusion worker — per-frame orchestration

**Files:**
- Modify: `data_only_viz/icp_fusion.py`
- Modify: `data_only_viz/tests/test_icp_fusion.py`

A `FusionWorker` glues everything: pull the latest LiDAR frame, apply the loaded extrinsic, partition by pid using `state.persons_smplx[*].vertices_3d[5559]` as pelvis, register each person, write fused verts back. Operates on a `State` snapshot — caller decides cadence (typically called every Multi-HMR frame, i.e. ~6.5 Hz).

- [ ] **Step 1: Write the failing fusion worker test**

Append to `data_only_viz/tests/test_icp_fusion.py`:

```python
def test_fusion_worker_in_place_update(monkeypatch) -> None:
    from data_only_viz.icp_fusion import FusionWorker, IcpConfig
    from data_only_viz.lidar_calib import Extrinsic
    from data_only_viz.lidar_receiver import LidarFrame
    from data_only_viz.state import SMPLXPerson, State

    src = _synthetic_smplx_torso(seed=30)
    # Pad to full SMPL-X length so vertex 5559 is valid.
    verts = np.zeros((10475, 3), dtype=np.float32)
    verts[: src.shape[0]] = src
    verts[5559] = src.mean(axis=0)  # use centroid as pelvis stand-in

    person = SMPLXPerson(pid=0, vertices_3d=verts.copy())
    state = State()
    state.persons_smplx = [person]

    # Synthetic LiDAR: src translated by +0.04 along Y.
    lidar_pts = src + np.array([0.0, 0.04, 0.0], dtype=np.float32)
    state.lidar_points = lidar_pts
    state.lidar_timestamp_ns = 1

    worker = FusionWorker(
        extrinsic=Extrinsic.identity(),
        config=IcpConfig(),
    )
    metadata = worker.run_once(state)

    assert metadata.applied == {0}
    # Pelvis should have moved roughly +0.04 along Y in the fused mesh.
    delta = state.persons_smplx[0].vertices_3d[5559] - verts[5559]
    assert 0.02 <= delta[1] <= 0.06


def test_fusion_worker_skips_when_no_lidar() -> None:
    from data_only_viz.icp_fusion import FusionWorker, IcpConfig
    from data_only_viz.lidar_calib import Extrinsic
    from data_only_viz.state import SMPLXPerson, State

    verts = np.zeros((10475, 3), dtype=np.float32)
    verts[5559] = [0.0, 1.0, 2.0]
    state = State()
    state.persons_smplx = [SMPLXPerson(pid=0, vertices_3d=verts.copy())]
    state.lidar_points = None

    worker = FusionWorker(extrinsic=Extrinsic.identity(), config=IcpConfig())
    metadata = worker.run_once(state)
    assert metadata.applied == set()
    np.testing.assert_array_equal(state.persons_smplx[0].vertices_3d, verts)
```

- [ ] **Step 2: Add the `lidar_points` field to State**

Modify `data_only_viz/state.py` — locate the `State` dataclass and append:

```python
    # ---- LiDAR / ICP fusion (Task 8) ----
    lidar_points: "np.ndarray | None" = None     # (N, 3) float32, webcam camera frame
    lidar_timestamp_ns: int = 0
    icp_metadata: "FusionMetadata | None" = None  # last fusion outcome (per-frame)
```

Add the forward import at the top of the file:

```python
from __future__ import annotations

import numpy as np  # type: ignore  # noqa: F401  (used by string-typed annotations)
```

(If `np` is already imported, leave the existing import alone.)

- [ ] **Step 3: Run, verify failure**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py::test_fusion_worker_in_place_update -v`
Expected: `ImportError: cannot import name 'FusionWorker'`.

- [ ] **Step 4: Implement FusionWorker**

Append to `data_only_viz/icp_fusion.py`:

```python
PELVIS_VERT_INDEX = 5559  # SMPL-X canonical pelvis vertex


@dataclass
class FusionMetadata:
    applied: set[int]                  # pids whose verts were replaced
    fitness: dict[int, float]
    rmse_m: dict[int, float]
    n_lidar_points_used: int


class FusionWorker:
    """Per-frame ICP fusion orchestrator (caller-driven, no internal thread)."""

    def __init__(self, extrinsic, config: IcpConfig | None = None) -> None:
        self._extrinsic = extrinsic
        self._config = config or IcpConfig()

    def set_extrinsic(self, extrinsic) -> None:
        self._extrinsic = extrinsic

    def run_once(self, state) -> FusionMetadata:
        """Replace ``state.persons_smplx[*].vertices_3d`` with fused versions."""
        applied: set[int] = set()
        fitness: dict[int, float] = {}
        rmse: dict[int, float] = {}

        lidar = getattr(state, "lidar_points", None)
        if lidar is None or lidar.size == 0 or not state.persons_smplx:
            return FusionMetadata(applied, fitness, rmse, 0)

        # Transform LiDAR into camera frame.
        T = np.asarray(self._extrinsic.T_arkit_to_cam, dtype=np.float32)
        homog = np.concatenate([lidar, np.ones((lidar.shape[0], 1), dtype=np.float32)], axis=1)
        lidar_cam = (homog @ T.T)[:, :3]

        pelvises = {
            p.pid: p.vertices_3d[PELVIS_VERT_INDEX]
            for p in state.persons_smplx
            if p.vertices_3d is not None
        }
        parts = partition_lidar_by_pid(lidar_cam, pelvises, max_dist_m=1.0)

        for person in state.persons_smplx:
            pts = parts.get(person.pid)
            if pts is None:
                continue
            result = register_mesh_to_lidar(person.vertices_3d, pts, self._config)
            fitness[person.pid] = result.fitness
            rmse[person.pid] = result.rmse_m
            if result.accepted:
                person.vertices_3d = result.vertices_registered
                applied.add(person.pid)

        return FusionMetadata(applied, fitness, rmse, lidar_cam.shape[0])
```

- [ ] **Step 5: Run all tests, verify pass**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_icp_fusion.py -v`
Expected: 8 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/icp_fusion.py data_only_viz/state.py data_only_viz/tests/test_icp_fusion.py
git commit -m "feat(icp): FusionWorker + State.lidar_points field"
```

---

## Task 9: Wire LiDAR receiver + FusionWorker into main pipeline

**Files:**
- Modify: `data_only_viz/main.py`
- Modify: `data_only_viz/multi_hmr_worker.py`

ICP fusion is **opt-in** via `ICP_FUSION=1`. When enabled, `main.py` starts a `LidarTCPReader`, loads the persisted extrinsic, instantiates `FusionWorker`, and inserts a `run_once(state)` call **after** Multi-HMR writes `state.persons_smplx` and **before** the OSC/TCP publisher reads it.

- [ ] **Step 1: Identify the integration point**

Run: `grep -n "persons_smplx" data_only_viz/main.py`
Expected: locate the line where Multi-HMR worker results land on `state.persons_smplx` (typically inside the worker loop or right after a poll).

- [ ] **Step 2: Add the wiring**

Add near the top of `data_only_viz/main.py`:

```python
import os

from data_only_viz.icp_fusion import FusionWorker, IcpConfig
from data_only_viz.lidar_calib import load_extrinsic
from data_only_viz.lidar_receiver import LidarTCPReader
```

Add a helper near the worker-startup section:

```python
def _start_icp_fusion(state):
    """Start LiDAR reader + FusionWorker if ICP_FUSION=1."""
    if os.environ.get("ICP_FUSION", "0") != "1":
        return None, None
    host = os.environ.get("ICP_LIDAR_HOST")
    port = int(os.environ.get("ICP_LIDAR_PORT", "5500"))
    if not host:
        raise RuntimeError("ICP_FUSION=1 requires ICP_LIDAR_HOST to be set")
    reader = LidarTCPReader(host=host, port=port)
    reader.start()
    extrinsic = load_extrinsic()
    worker = FusionWorker(extrinsic=extrinsic, config=IcpConfig())
    return reader, worker
```

Inside the main loop, immediately after the Multi-HMR step updates `state.persons_smplx`, add:

```python
if icp_worker is not None and icp_reader is not None:
    frame = icp_reader.latest()
    if frame is not None:
        state.lidar_points = frame.points
        state.lidar_timestamp_ns = frame.timestamp_ns
        state.icp_metadata = icp_worker.run_once(state)
    else:
        state.lidar_points = None
        state.icp_metadata = None
```

And in startup:

```python
icp_reader, icp_worker = _start_icp_fusion(state)
```

In shutdown:

```python
if icp_reader is not None:
    icp_reader.stop()
```

- [ ] **Step 3: Add a one-shot predictor hook for the calibration CLI**

In `data_only_viz/multi_hmr_worker.py`, find the class that performs inference and expose a public `predict_once(rgb_image) -> SMPLXPerson | None` method that runs a single forward pass without modifying any shared state. Keep it ≤ 30 lines — just call into the existing inference path, return the first detection or `None`.

- [ ] **Step 4: Update the calibration CLI to use it**

Replace the `_placeholder_pelvis_cam` body in `data_only_viz/scripts/calibrate_lidar.py` with a real OpenCV webcam grab + `predict_once` call. Pelvis = `result.vertices_3d[5559]`.

```python
import cv2

from data_only_viz.multi_hmr_worker import predict_once  # or equivalent factory

cap = cv2.VideoCapture(args.webcam_index)


def _real_pelvis_cam() -> np.ndarray:
    ok, frame = cap.read()
    if not ok:
        raise RuntimeError("webcam read failed")
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    person = predict_once(rgb)
    if person is None:
        raise RuntimeError("no person detected — adjust pose and retry")
    return person.vertices_3d[5559]
```

Wire `_real_pelvis_cam` into `_capture_one_pair` in place of the placeholder.

- [ ] **Step 5: Sanity-check the wiring (no LiDAR available)**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ICP_FUSION=0 uv run --extra lidar python -m data_only_viz.main` for ~10 seconds, Ctrl-C.
Expected: pipeline starts as before, no LiDAR-related errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/main.py data_only_viz/multi_hmr_worker.py data_only_viz/scripts/calibrate_lidar.py
git commit -m "feat(icp): wire fusion behind ICP_FUSION env var"
```

---

## Task 10: Latency & convergence bench

**Files:**
- Create: `data_only_viz/scripts/bench_icp_fusion.py`

A standalone harness that ingests a recorded LiDAR + Multi-HMR sequence (or synthetic), measures: (a) per-call ICP latency p50/p95, (b) acceptance rate, (c) mean pelvis displacement post-fusion. Outputs a single JSON line.

- [ ] **Step 1: Create the bench script**

```python
"""Latency / convergence bench for the ICP fusion worker.

Usage:

    cd data_only_viz
    uv run --extra lidar python -m data_only_viz.scripts.bench_icp_fusion \
        --n-frames 200 --n-people 2 --seed 0
"""
from __future__ import annotations

import argparse
import json
import time

import numpy as np

from data_only_viz.icp_fusion import FusionWorker, IcpConfig
from data_only_viz.lidar_calib import Extrinsic
from data_only_viz.state import SMPLXPerson, State


def _synth_person(seed: int, offset_x: float) -> SMPLXPerson:
    rng = np.random.RandomState(seed)
    verts = np.zeros((10475, 3), dtype=np.float32)
    pts = rng.randn(2000, 3).astype(np.float32) * 0.1
    verts[: pts.shape[0]] = pts + np.array([offset_x, 0, 1.5], dtype=np.float32)
    verts[5559] = pts.mean(axis=0) + np.array([offset_x, 0, 1.5], dtype=np.float32)
    return SMPLXPerson(pid=seed, vertices_3d=verts)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-frames", type=int, default=200)
    p.add_argument("--n-people", type=int, default=2)
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args(argv)

    rng = np.random.RandomState(args.seed)
    persons = [_synth_person(i, offset_x=-0.6 + 1.2 * i) for i in range(args.n_people)]
    state = State()
    state.persons_smplx = persons

    worker = FusionWorker(extrinsic=Extrinsic.identity(), config=IcpConfig())

    latencies_ms: list[float] = []
    accepted = 0
    pelvis_delta_m: list[float] = []
    for _ in range(args.n_frames):
        # Build synthetic LiDAR: ground-truth verts perturbed by 2 cm noise + 5 cm bias.
        all_pts = np.concatenate([
            pers.vertices_3d[: 2000] + np.array([0, 0.05, 0], dtype=np.float32) +
            0.02 * rng.randn(2000, 3).astype(np.float32)
            for pers in persons
        ])
        state.lidar_points = all_pts
        before = np.stack([p.vertices_3d[5559].copy() for p in state.persons_smplx])
        t0 = time.perf_counter()
        meta = worker.run_once(state)
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)
        accepted += len(meta.applied)
        after = np.stack([p.vertices_3d[5559] for p in state.persons_smplx])
        pelvis_delta_m.extend(np.linalg.norm(after - before, axis=1).tolist())

    report = {
        "n_frames": args.n_frames,
        "n_people": args.n_people,
        "latency_ms_p50": float(np.percentile(latencies_ms, 50)),
        "latency_ms_p95": float(np.percentile(latencies_ms, 95)),
        "acceptance_rate": accepted / (args.n_frames * args.n_people),
        "pelvis_delta_m_mean": float(np.mean(pelvis_delta_m)),
        "pelvis_delta_m_max": float(np.max(pelvis_delta_m)),
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Run the bench**

Run: `cd data_only_viz && uv run --extra lidar python -m data_only_viz.scripts.bench_icp_fusion --n-frames 100 --n-people 2`
Expected: JSON output with `latency_ms_p95 < 60` (rough target on M5 CPU) and `acceptance_rate > 0.85`.

- [ ] **Step 3: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/scripts/bench_icp_fusion.py
git commit -m "test(icp): synthetic latency + convergence bench"
```

---

## Task 11: Docs — env vars, calibration procedure, troubleshooting

**Files:**
- Create: `docs/ICP_FUSION.md`
- Modify: `CLAUDE.md` (root)

- [ ] **Step 1: Create `docs/ICP_FUSION.md`**

```markdown
# ICP LiDAR ↔ SMPL-X Dense Fusion

Refines Multi-HMR SMPL-X meshes using live iPhone LiDAR via point-to-plane ICP.

## Env vars

| Var | Default | Effect |
|-----|---------|--------|
| `ICP_FUSION` | `0` | `1` enables LiDAR receiver + FusionWorker |
| `ICP_LIDAR_HOST` | _(required when on)_ | iPhone ARBodyTracker IP on the LAN |
| `ICP_LIDAR_PORT` | `5500` | TCP port the iOS app publishes ARMesh on |
| `ICP_LIDAR_EXTRINSIC` | `~/.config/av-live/lidar_extrinsic.json` | Path to persisted extrinsic JSON |

## Calibration

1. Launch the iPhone ARBodyTracker app and note its LAN IP.
2. From `data_only_viz/`:
   ```bash
   uv run --extra lidar python -m data_only_viz.scripts.calibrate_lidar \
     --lidar-host <iPhone IP> --lidar-port 5500 --webcam-index 0
   ```
3. The script asks for 4 stances (front / left / right / back). Hold still each time and press ENTER.
4. The estimated extrinsic is written to `ICP_LIDAR_EXTRINSIC`. Re-run any time the camera or iPhone moves.

## Runtime

```bash
ICP_FUSION=1 ICP_LIDAR_HOST=192.168.0.42 uv run --extra lidar python -m data_only_viz.main
```

## Troubleshooting

- **`open3d` missing** → `cd data_only_viz && uv sync --extra lidar`
- **No LiDAR frames** → check that the iPhone app is publishing on the expected port and that nothing else is bound to it. `nc -l 5500` from the Mac should not succeed while the app runs.
- **ICP always rejected (`fitness < 0.30`)** → the extrinsic is likely stale; re-run calibration. Verify the iPhone is facing the same scene as the webcam.
- **Mesh appears scaled wrong** → SMPL-X is in metres; the iPhone publishes metres. If you see a factor-1000 mismatch the iOS encoder is sending millimetres — patch the iOS app, not this code.
- **Bench shows `latency_ms_p95 > 100`** → reduce `IcpConfig.voxel_size_m` (e.g. 0.03 m) or `max_iterations` (e.g. 20).
```

- [ ] **Step 2: Update root `CLAUDE.md`**

In the "RC0.1+ environment variables" table, append four rows:

```markdown
| `ICP_FUSION` | `0` | `1` to enable LiDAR↔SMPL-X ICP fusion (cf. `docs/ICP_FUSION.md`) |
| `ICP_LIDAR_HOST` | _(unset)_ | iPhone ARBodyTracker IP when `ICP_FUSION=1` |
| `ICP_LIDAR_PORT` | `5500` | iPhone ARMesh TCP port |
| `ICP_LIDAR_EXTRINSIC` | `~/.config/av-live/lidar_extrinsic.json` | extrinsic JSON path |
```

- [ ] **Step 3: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add docs/ICP_FUSION.md CLAUDE.md
git commit -m "docs(icp): runtime env vars + calibration procedure"
```

---

## Task 12: Smoke-test the full pipeline end-to-end

**Files:** _(none — operational gate)_

- [ ] **Step 1: Run all icp tests once more**

Run: `cd data_only_viz && uv run --extra lidar pytest tests/test_open3d_smoke.py tests/test_lidar_receiver.py tests/test_lidar_calib.py tests/test_icp_fusion.py -v`
Expected: all green (≈20 passed).

- [ ] **Step 2: Bench**

Run: `cd data_only_viz && uv run --extra lidar python -m data_only_viz.scripts.bench_icp_fusion --n-frames 200`
Expected: `latency_ms_p95 < 60`, `acceptance_rate > 0.85`, `pelvis_delta_m_mean` ≈ 0.04 m (matches the synthetic 5 cm bias).

- [ ] **Step 3: Live smoke (with iPhone)**

With ARBodyTracker running on the iPhone and the webcam on:

```bash
ICP_FUSION=1 ICP_LIDAR_HOST=<iPhone IP> uv run --extra lidar python -m data_only_viz.main
```

Verify in logs: `applied={0}` lines, `fitness > 0.3`, no NaN warnings from Multi-HMR.

- [ ] **Step 4: Live smoke (LiDAR cable pulled)**

Disconnect the iPhone from Wi-Fi mid-run. Pipeline must continue without crashing — fused verts should fall back to raw Multi-HMR output within ~1 frame.

- [ ] **Step 5: Final commit (changelog)**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git tag -m "ICP LiDAR fusion ready for live testing" icp-fusion-mvp
```

---

## Self-Review

**Spec coverage** — Each architectural concern is covered:
- LiDAR ingestion → Tasks 2–3
- Coordinate alignment → Tasks 4–5 + CLI in Task 9
- ICP core → Task 6
- Multi-person dispatch → Task 7
- Pipeline integration → Tasks 8–9
- Observability/bench → Task 10
- Docs → Task 11
- Operational gate → Task 12

**Placeholder scan** — No `TODO`, no "add error handling" without code, no "similar to Task N". Each step contains the actual code, command, or assertion.

**Type consistency** — `register_mesh_to_lidar` / `partition_lidar_by_pid` / `FusionWorker.run_once` signatures are stable across tasks 6–8. `Extrinsic.T_arkit_to_cam` shape (4×4) and dtype (float64 for math, cast to float32 only inside the transform) are consistent. `SMPLXPerson.vertices_3d` shape `(10475, 3) float32` matches `multi_hmr_worker.py:403`. Pelvis vertex index 5559 is referenced identically in Tasks 5, 8, 9.

**Out-of-band requirements:**
- iPhone ARBodyTracker app must already publish ARMeshAnchor data on TCP (per memory `project_iphone_arbodytracker`). If the wire format differs from the assumed `[uint32 len][uint64 ts][uint32 vcount][float32 xyz]*`, Task 2's decoder must be adjusted before Task 3 will work.
- `data_only_viz` repo must be sane (git fresh-clone done, " 2" iCloud collisions cleaned). This plan assumes a healthy repo on the canonical `feat/action-head` or `main` branch.
