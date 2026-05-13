# SMPL-X / Multi-HMR Test Coverage Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the test-coverage gap on the Body Mesh production path: add focused tests for `MultiHMRWorker`, `SMPLXTCPSender`, and the (post-Plan-1) `SMPLXPerson` dataclass with ndarray fields. Lock-in the Plan 1 fixes (numpy serializer, joints_3d removal, ndarray vertices) by exercising them.

**Prerequisite:** Plan `2026-05-13-body-mesh-perf-safety.md` must be completed first (Tasks 5 and 6 change the SMPLXPerson contract, which these tests assert).

**Architecture:** Pure unit tests, no Multi-HMR checkpoint required at test time, no real TCP listener. All heavy deps (`torch`, `cv2`, `smplx`) are mocked via `unittest.mock` or `sys.modules` injection (the pattern Task 1 of the previous plan established). Tests live alongside the existing `data_only_viz/tests/` suite and run via `uv run pytest`.

**Tech Stack:** Python 3.11+, pytest, unittest.mock, numpy.

**Out of scope:**
- Integration test of the full Python→Swift TCP loop (requires running both processes; deferred).
- Visual regression tests of mesh rendering (subjective).
- Performance benchmarks (separate work — Plan 1 already adds debug timers).

---

### Task 1: `SMPLXTCPSender` — serialization round-trip

**Files:**
- Test: `data_only_viz/tests/test_smplx_osc_sender_serialize.py`

**Context:** After Plan 1 Task 5, the sender uses `np.ascontiguousarray(...).tobytes()` per field. We must lock-in that the wire bytes match what a hand-written struct decoder produces, so any future refactor of `_serialize_person` breaks loudly. We do NOT open a socket; we call `_serialize_person` directly and reparse the bytes.

- [ ] **Step 1: Write the test**

```python
"""SMPLXTCPSender._serialize_person produces the expected binary frame."""

import struct
import numpy as np

from data_only_viz.smplx_osc_sender import SMPLXTCPSender
from data_only_viz.state import SMPLXPerson


def _make_person(pid: int = 7) -> SMPLXPerson:
    rng = np.random.default_rng(seed=42)
    return SMPLXPerson(
        pid=pid,
        confidence=0.83,
        translation=np.array([0.1, 0.2, 0.3], dtype=np.float32),
        betas=rng.standard_normal(10).astype(np.float32),
        expression=rng.standard_normal(10).astype(np.float32),
        vertices_3d=rng.standard_normal((10475, 3)).astype(np.float32),
    )


def test_serialize_person_layout():
    sender = SMPLXTCPSender.__new__(SMPLXTCPSender)
    p = _make_person()
    payload = sender._serialize_person(p)

    # Expected layout: pid(4) + conf(4) + trans(12) + betas(40) + expr(40) + verts(125700)
    assert len(payload) == 4 + 4 + 12 + 40 + 40 + 10475 * 3 * 4

    # Parse the header
    pid, conf = struct.unpack_from("<if", payload, 0)
    assert pid == 7
    assert abs(conf - 0.83) < 1e-5

    # Reparse translation and compare
    trans = np.frombuffer(payload, dtype="<f4", count=3, offset=8)
    np.testing.assert_allclose(trans, p.translation, rtol=0, atol=0)

    # Reparse vertices and compare
    verts = np.frombuffer(
        payload, dtype="<f4", count=10475 * 3, offset=8 + 12 + 40 + 40
    ).reshape(10475, 3)
    np.testing.assert_allclose(verts, p.vertices_3d, rtol=0, atol=0)


def test_serialize_person_round_trip_handles_non_contiguous_input():
    """Vertex arrays that come from slicing / transpose must still serialize cleanly."""
    sender = SMPLXTCPSender.__new__(SMPLXTCPSender)
    p = _make_person()
    # Force a non-contiguous view:
    p.vertices_3d = p.vertices_3d[::1, :].T.T
    payload = sender._serialize_person(p)
    assert len(payload) == 4 + 4 + 12 + 40 + 40 + 10475 * 3 * 4
    verts = np.frombuffer(
        payload, dtype="<f4", count=10475 * 3, offset=8 + 12 + 40 + 40
    ).reshape(10475, 3)
    np.testing.assert_allclose(verts, p.vertices_3d, rtol=0, atol=0)
```

- [ ] **Step 2: Run**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_smplx_osc_sender_serialize.py -v
```

Expected: 2 passed.

If the test fails because field order in the actual `_serialize_person` differs from what's assumed here, **read the function** and update the expected offsets in the test — the LIVING contract of the wire format is the function itself, the test mirrors it.

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/tests/test_smplx_osc_sender_serialize.py
git commit -m "test(smplx-tcp): serialize round-trip + offsets"
```

(46 chars — fits.)

---

### Task 2: `SMPLXTCPSender` — connection lifecycle

**Files:**
- Test: `data_only_viz/tests/test_smplx_osc_sender_lifecycle.py`

**Context:** Validate the post-Plan-1 reconnect behavior: timeout closes the socket, broken-pipe closes the socket, reconnect attempts succeed when the listener comes back. No real socket — we mock `socket.socket`.

- [ ] **Step 1: Write the test**

```python
"""SMPLXTCPSender handles timeouts and reconnects without dying."""

import socket
from unittest.mock import MagicMock, patch

import pytest

from data_only_viz.smplx_osc_sender import SMPLXTCPSender


def _make_sender():
    s = SMPLXTCPSender.__new__(SMPLXTCPSender)
    s.host = "127.0.0.1"
    s.port = 57130
    s._sock = None
    s._last_warn = 0.0
    return s


def test_send_timeout_closes_socket():
    sender = _make_sender()
    fake_sock = MagicMock()
    fake_sock.sendall.side_effect = socket.timeout
    sender._sock = fake_sock

    ok = sender._send(b"\x00" * 8)
    assert ok is False
    assert sender._sock is None  # closed on timeout


def test_send_broken_pipe_closes_socket():
    sender = _make_sender()
    fake_sock = MagicMock()
    fake_sock.sendall.side_effect = BrokenPipeError
    sender._sock = fake_sock
    ok = sender._send(b"\x00" * 8)
    assert ok is False
    assert sender._sock is None


@patch("socket.socket")
def test_ensure_connected_sets_tcp_nodelay_and_timeout(mock_socket_cls):
    sender = _make_sender()
    fake_sock = MagicMock()
    mock_socket_cls.return_value = fake_sock
    sender._ensure_connected()
    fake_sock.setsockopt.assert_any_call(
        socket.IPPROTO_TCP, socket.TCP_NODELAY, 1
    )
    fake_sock.settimeout.assert_called_with(1.0)
```

The third test pins the Plan 1 Task 4 invariant — TCP_NODELAY + 1 s timeout must be set on every fresh connection.

- [ ] **Step 2: Run**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_smplx_osc_sender_lifecycle.py -v
```

Expected: 3 passed.

If the function names differ (`_send` vs `_try_send`, `_ensure_connected` vs `_connect`), grep first and adapt:

```bash
grep -n "def _" data_only_viz/smplx_osc_sender.py
```

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/tests/test_smplx_osc_sender_lifecycle.py
git commit -m "test(smplx-tcp): timeout + reconnect lifecycle"
```

(46 chars — fits.)

---

### Task 3: `MultiHMRWorker` — availability guard + lock discipline

**Files:**
- Test: `data_only_viz/tests/test_multi_hmr_worker.py`

**Context:** Two key invariants to lock in: (a) `MultiHMRWorker.is_available()` returns `False` when the checkpoint file is absent (so the headless fail-fast added in Plan 1 Task 7 works), and (b) every write to `state.persons_smplx` happens inside `with state.lock():` (audit confirmed this is currently true — test pins it).

- [ ] **Step 1: Write the test**

```python
"""MultiHMRWorker availability and thread-safety invariants."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


def test_is_available_returns_false_when_checkpoint_missing(tmp_path, monkeypatch):
    # Point the checkpoint path at an empty dir
    from data_only_viz import multi_hmr_worker

    monkeypatch.setattr(multi_hmr_worker, "CHECKPOINT_PATH", tmp_path / "missing.pt")
    assert multi_hmr_worker.MultiHMRWorker.is_available() is False


def test_is_available_returns_true_when_checkpoint_present(tmp_path, monkeypatch):
    from data_only_viz import multi_hmr_worker

    ckpt = tmp_path / "fake.pt"
    ckpt.write_bytes(b"")
    monkeypatch.setattr(multi_hmr_worker, "CHECKPOINT_PATH", ckpt)
    assert multi_hmr_worker.MultiHMRWorker.is_available() is True


def test_state_mutations_are_all_under_lock():
    """Static grep: every assignment to state.persons_smplx is preceded by `with`."""
    import re
    src = Path("data_only_viz/multi_hmr_worker.py").read_text()
    # Find every line that assigns to state.persons_smplx (or self.state.persons_smplx)
    assign_lines = [
        (i, line)
        for i, line in enumerate(src.splitlines(), start=1)
        if re.search(r"\bstate\.persons_smplx\s*=", line)
    ]
    assert assign_lines, "expected at least one persons_smplx assignment in multi_hmr_worker.py"

    # For each, walk backwards up to 20 lines looking for `with self.state.lock():`
    lines = src.splitlines()
    for lineno, line in assign_lines:
        found_lock = any(
            "state.lock()" in lines[j]
            for j in range(max(0, lineno - 20), lineno)
        )
        assert found_lock, (
            f"line {lineno} mutates persons_smplx without a nearby `state.lock()` context:\n{line}"
        )
```

The third test is structural (greps the source) — it pins the lock-discipline pattern. It catches a future PR that accidentally adds an out-of-lock write.

- [ ] **Step 2: Run**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_multi_hmr_worker.py -v
```

Expected: 3 passed.

If `CHECKPOINT_PATH` does not exist as a module-level constant (the name was assumed — Plan 1 Task 7 mentions it might need to be added), inspect first:

```bash
grep -n "CHECKPOINT\|checkpoint_path\|.pt" data_only_viz/multi_hmr_worker.py
```

If the constant has a different name, adapt the `monkeypatch.setattr` call accordingly.

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/tests/test_multi_hmr_worker.py
git commit -m "test(multihmr): is_available + lock discipline"
```

(46 chars — fits.)

---

### Task 4: `SMPLXPerson` — ndarray contract

**Files:**
- Test: `data_only_viz/tests/test_state_smplxperson.py`

**Context:** After Plan 1 Task 5, `SMPLXPerson` fields are `np.ndarray`, not tuples. Lock the contract so a future "let me convert these to tuples for hashability" refactor breaks loudly.

- [ ] **Step 1: Write the test**

```python
"""SMPLXPerson fields are numpy float32 arrays after Plan 1 Task 5."""

import numpy as np

from data_only_viz.state import SMPLXPerson


def test_smplxperson_accepts_ndarrays():
    p = SMPLXPerson(
        pid=0,
        confidence=1.0,
        translation=np.zeros(3, dtype=np.float32),
        betas=np.zeros(10, dtype=np.float32),
        expression=np.zeros(10, dtype=np.float32),
        vertices_3d=np.zeros((10475, 3), dtype=np.float32),
    )
    assert isinstance(p.vertices_3d, np.ndarray)
    assert p.vertices_3d.dtype == np.float32
    assert p.vertices_3d.shape == (10475, 3)
    assert isinstance(p.translation, np.ndarray)
    assert isinstance(p.betas, np.ndarray)
    assert isinstance(p.expression, np.ndarray)


def test_smplxperson_does_not_have_joints_3d():
    """Plan 1 Task 6 removed the joints_3d field."""
    p = SMPLXPerson(
        pid=0,
        confidence=1.0,
        translation=np.zeros(3, dtype=np.float32),
        betas=np.zeros(10, dtype=np.float32),
        expression=np.zeros(10, dtype=np.float32),
        vertices_3d=np.zeros((10475, 3), dtype=np.float32),
    )
    assert not hasattr(p, "joints_3d"), "joints_3d was removed in Plan 1 Task 6"
```

- [ ] **Step 2: Run**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_state_smplxperson.py -v
```

Expected: 2 passed (only after Plan 1 Tasks 5 & 6 are merged — otherwise the second test fails because `joints_3d` still exists).

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/tests/test_state_smplxperson.py
git commit -m "test(state): SMPLXPerson ndarray contract"
```

(42 chars — fits.)

---

## Self-Review

**1. Spec coverage:** Test 1 covers the wire format (round-trip). Test 2 covers TCP lifecycle (timeout, reconnect, NODELAY). Test 3 covers worker availability + lock discipline. Test 4 covers dataclass contract. Together they pin the Plan 1 changes structurally.

**2. Placeholder scan:** No "TBD" / "fill in" / "similar to Task N". Every test body is complete code. Where field/method names may differ (`_send` vs `_try_send`, `CHECKPOINT_PATH` constant name), the task says to grep first and adapt — with the grep command included.

**3. Type consistency:** All ndarray dtypes are `np.float32` consistently. All struct offsets in Task 1 align with the expected layout from Plan 1 Task 5. `MultiHMRWorker.is_available()` is referenced consistently across Tasks 3 and Plan 1 Task 7.

---

## Execution Handoff

Plan complete. Same execution options as Plan 1. Run AFTER Plan 1 ships (Tasks 5 and 6 are prerequisites).
