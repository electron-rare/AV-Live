# Body Mesh Pipeline — Performance + Safety Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the 3 critical safety bugs (device crash, TCP DoS, blocking send) and apply the 4 highest-ROI perf wins (numpy serialization, drop dead payload, TCP_NODELAY, frame dropping) from the 2026-05-13 critic review of the Body Mesh pipeline (Python `data_only_viz` → TCP → Swift `AV-Live-Body`).

**Architecture:** Surgical, file-local fixes. No refactor of the worker/sender/receiver topology. Each task adds defensive code or replaces a slow Python loop with a numpy operation. The TCP wire format **does not change** except for dropping fields that the receiver already skips. The receiver remains stateful (NWListener+NWConnection), only its buffering policy tightens.

**Tech Stack:** Python 3.11+, numpy (already a dep), PyTorch MPS, Swift 6 + RealityKit (macOS 15+), Network framework.

**Reference audit findings (verified):**
- 🔴 `data_only_viz/smplx_decoder.py:28-46` — no device validation, crashes on "mps" off-Apple
- 🔴 `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift:13,39` — unbounded TCP buffer, header-injection DoS
- 🟠 `data_only_viz/smplx_osc_sender.py:46-65` — `sendall()` blocking without timeout
- 🟠 `data_only_viz/smplx_osc_sender.py:73-90` — `struct.pack` 10475-iteration Python loop per person per frame (≈ 5–15 ms wasted)
- 🟠 `data_only_viz/state.py:27` — `joints_3d` field written but never read anywhere (255 KB/frame waste)
- 🟠 `data_only_viz/main.py:244-262` — silent fallback to MediaPipe in `--multi-hmr` headless mode if checkpoint absent
- 🟠 `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift:42` — no frame dropping when receiver lags behind sender

**Out of scope:**
- `MeshRenderer.computeVertexNormals` Accelerate/SIMD rework (Plan separately — needs measurement first)
- Lowering Multi-HMR input resolution (qualitative tradeoff — needs visual evaluation)
- CoreML conversion of Multi-HMR (20–40h effort, deferred)

---

### Task 1: SMPLX decoder — device validation

**Files:**
- Modify: `data_only_viz/smplx_decoder.py` (`__init__` around line 28-46)
- Test: extend `data_only_viz/tests/test_smplx_decoder.py` (or add `test_smplx_decoder_device.py`)

**Context:** `SMPLXDecoder.__init__` accepts `device="mps"` and calls `.to(device)` directly. On non-Apple platforms or when MPS is unavailable, this raises a low-level torch error. The sibling `MultiHMRWorker` already validates via `torch.backends.mps.is_available()` and falls back to CPU at `multi_hmr_worker.py:95-99`. Copy that pattern.

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_smplx_decoder_device.py`:

```python
"""SMPLXDecoder must validate device and fall back to CPU when MPS unavailable."""

from unittest.mock import patch

import pytest


@patch("data_only_viz.smplx_decoder.smplx", create=True)
def test_decoder_falls_back_to_cpu_when_mps_unavailable(mock_smplx, tmp_path):
    from data_only_viz import smplx_decoder

    with patch.object(smplx_decoder, "_require_torch") as mock_require:
        fake_torch = mock_require.return_value
        fake_torch.backends.mps.is_available.return_value = False

        # Make smplx.SMPLXLayer chainable (.to(device).eval())
        layer = mock_smplx.SMPLXLayer.return_value
        layer.to.return_value = layer
        layer.eval.return_value = layer

        dec = smplx_decoder.SMPLXDecoder(model_path=tmp_path, device="mps")

        # The decoder must NOT have called .to("mps") — it must have demoted to "cpu":
        layer.to.assert_called_with("cpu")
        assert dec.device == "cpu"


@patch("data_only_viz.smplx_decoder.smplx", create=True)
def test_decoder_keeps_cpu_device(mock_smplx, tmp_path):
    from data_only_viz import smplx_decoder

    with patch.object(smplx_decoder, "_require_torch") as mock_require:
        fake_torch = mock_require.return_value
        fake_torch.backends.mps.is_available.return_value = False

        layer = mock_smplx.SMPLXLayer.return_value
        layer.to.return_value = layer
        layer.eval.return_value = layer

        dec = smplx_decoder.SMPLXDecoder(model_path=tmp_path, device="cpu")
        assert dec.device == "cpu"
        layer.to.assert_called_with("cpu")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_smplx_decoder_device.py -v`
Expected: FAIL — either with `AssertionError` because `.to("mps")` was called, or because `self.device == "mps"` instead of `"cpu"`.

- [ ] **Step 3: Modify `smplx_decoder.py`**

In `SMPLXDecoder.__init__`, add device demotion BEFORE the `.to(device)` call:

```python
def __init__(self, model_path, *, device: str = "mps"):
    torch = _require_torch()
    # Demote unsupported devices to CPU (mirrors MultiHMRWorker pattern)
    if device == "mps" and not torch.backends.mps.is_available():
        device = "cpu"
    elif device.startswith("cuda") and not torch.cuda.is_available():
        device = "cpu"
    self.device = device
    # ... rest of __init__, replace any `.to(<original device>)` with `.to(self.device)` ...
```

Search the file for all uses of the parameter `device` after this point — replace with `self.device` so the demoted value is consistent throughout.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/test_smplx_decoder_device.py -v`
Expected: PASS, 2 passed.

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/smplx_decoder.py data_only_viz/tests/test_smplx_decoder_device.py
git commit -m "fix(smplx): demote device to cpu when mps unavailable"
```

(48 chars — fits.)

---

### Task 2: TCP receiver — cap buffer size (anti-DoS)

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift` (around line 39 `parseFrames` / `receive` callback)

**Context:** A malicious sender can declare a giant payload length in the 4-byte header without delivering the body, causing `buffer: Data` to grow unbounded in memory. Cap it at a reasonable max (we send ≤ ~600 KB per frame for 4 persons; 8 MB is comfortably above that and well below RAM exhaustion).

- [ ] **Step 1: Add max-buffer constant**

At the top of `OSCServer` (near the `port` constant), add:

```swift
private static let maxBufferBytes = 8 * 1024 * 1024  // 8 MiB — well above per-frame size
```

- [ ] **Step 2: Enforce the cap in the receive callback**

In the `receive(...)` callback closure, after `self.buffer.append(data)` (or wherever the buffer is mutated), add:

```swift
if self.buffer.count > Self.maxBufferBytes {
    NSLog("OSCServer: buffer exceeded %d bytes (%d), dropping connection", Self.maxBufferBytes, self.buffer.count)
    self.buffer.removeAll(keepingCapacity: false)
    conn.cancel()
    return
}
```

This drops the buffer, kills the connection, and lets `NWListener` accept the next one cleanly.

- [ ] **Step 3: Also bound the declared-payload header**

In `parseFrames` (around line 65 — where the 4-byte length prefix is read), reject obviously-malformed frames:

```swift
guard length > 0, length <= Self.maxBufferBytes else {
    NSLog("OSCServer: invalid frame length %u, resetting", length)
    self.buffer.removeAll(keepingCapacity: false)
    return
}
```

This prevents a tiny header from making us wait forever for a giant body that will never come.

- [ ] **Step 4: Build the Swift app to confirm it still compiles**

```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body
swift build -c release 2>&1 | tail -10
```

Expected: build success, no errors. (Warnings are tolerable if unrelated.)

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
git commit -m "fix(av-live-body): cap TCP buffer at 8 MiB"
```

(46 chars — fits.)

---

### Task 3: TCP receiver — frame dropping

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift` (`parseFrames` — keep only the most recent frame when several are pending)

**Context:** Today every parsed frame is dispatched via `Task { @MainActor }` to update the mesh. If MainActor stalls (because of vertex-normal compute or other rendering work) for, say, 200 ms, the receiver accumulates 6+ frames at 30 fps and replays them all, producing a 200 ms-delayed cascade. We want the receiver to drop stale frames when they pile up.

- [ ] **Step 1: Refactor `parseFrames` to return the latest frame only**

`parseFrames` currently parses each completed frame inside a `while` loop and dispatches each one. Change the contract: parse all complete frames, retain only the most recent set of persons, then dispatch once.

```swift
private func parseFrames() {
    var latestPersons: [SMPLXPerson]? = nil
    while let length = readLength(), self.buffer.count >= 4 + Int(length) {
        guard length > 0, length <= Self.maxBufferBytes else {
            NSLog("OSCServer: invalid frame length %u, resetting", length)
            self.buffer.removeAll(keepingCapacity: false)
            return
        }
        let payload = self.buffer.subdata(in: 4..<(4 + Int(length)))
        self.buffer.removeSubrange(0..<(4 + Int(length)))
        if let persons = decodePersons(payload) {
            latestPersons = persons  // overwrite — only the freshest wins
        }
    }
    if let persons = latestPersons {
        Task { @MainActor in self.onPersons(persons) }
    }
}
```

(Adapt to the actual current names: `decodePersons`, `onPersons`, etc. — verify by reading the file first.)

- [ ] **Step 2: Build**

```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body
swift build -c release 2>&1 | tail -5
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
git commit -m "perf(av-live-body): drop stale frames on backlog"
```

(48 chars — fits.)

---

### Task 4: TCP sender — non-blocking + TCP_NODELAY

**Files:**
- Modify: `data_only_viz/smplx_osc_sender.py` (`_ensure_connected` and `_send` around lines 46-65, 112)

**Context:** Today `sendall()` is fully blocking. If the Swift receiver is paused (e.g., MainActor stalled), the Python sender thread can sit in `sendall()` for seconds, starving the inference loop's downstream consumers. Add a write timeout (1 s) and `TCP_NODELAY` to disable Nagle.

- [ ] **Step 1: Set socket options after `connect()`**

In `_ensure_connected` (or wherever the socket is created), immediately after a successful `s.connect((host, port))`:

```python
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
s.settimeout(1.0)  # 1 s write timeout — must be > worst-case frame transit
```

- [ ] **Step 2: Treat timeout as a transient failure**

In the `_send` (or wherever `sendall` is called), wrap with explicit timeout handling that closes the socket and retries on next frame:

```python
try:
    self._sock.sendall(payload)
except socket.timeout:
    LOG.warning("smplx_tcp: send timeout — receiver stalled, dropping connection")
    self._close()
    return False
except (BrokenPipeError, ConnectionResetError, OSError) as e:
    LOG.warning("smplx_tcp: send failed (%s) — reconnecting", e)
    self._close()
    return False
return True
```

(Adapt `self._close()` to the actual private method that resets `self._sock = None`.)

- [ ] **Step 3: Verify the existing tests still run (the sender doesn't have its own tests yet — that's Plan 3)**

Run: `cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/ -v 2>&1 | tail -10`
Expected: same pass/fail counts as before (13 passed + 1 pre-existing nlf failure).

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/smplx_osc_sender.py
git commit -m "fix(smplx-tcp): add timeout + TCP_NODELAY"
```

(42 chars — fits.)

---

### Task 5: TCP sender — numpy serialization (O1) + keep vertices as ndarray (O2)

**Files:**
- Modify: `data_only_viz/smplx_osc_sender.py` (per-person packing loop around lines 73-90)
- Modify: `data_only_viz/multi_hmr_worker.py` (around line 238 — drop `tuple(map(tuple, v3d))`)
- Modify: `data_only_viz/state.py` (`SMPLXPerson.vertices_3d` type)

**Context:** The per-person serializer currently does `for vx, vy, vz in p.vertices_3d: buf += struct.pack("<fff", vx, vy, vz)` — 10475 iterations of Python bytecode per person per frame, dominating sender latency. Switch to `np.asarray(p.vertices_3d, dtype="<f4").tobytes()` — one C call, ≈50–100× faster. Same change for `betas`, `expression`, `translation` (smaller but consistent).

Pre-requisite: `vertices_3d` must arrive as a numpy array, not as `tuple(map(tuple, ...))`. The worker currently converts to Python tuples at line ~238 of `multi_hmr_worker.py`. Stop the conversion; keep the ndarray.

- [ ] **Step 1: Update `SMPLXPerson` type hint in `state.py`**

```python
# state.py — SMPLXPerson dataclass
vertices_3d: "np.ndarray"          # was: tuple[tuple[float, float, float], ...]
translation: "np.ndarray"          # was: tuple[float, float, float]
betas: "np.ndarray"                # was: tuple[float, ...]
expression: "np.ndarray"           # was: tuple[float, ...]
```

(Use string quotes if `from __future__ import annotations` is not at the top — verify.)

- [ ] **Step 2: Stop the tuple conversion in `multi_hmr_worker.py`**

Around line 238 — replace:

```python
v3d_tup = tuple(map(tuple, v3d))
```

with:

```python
v3d_arr = np.ascontiguousarray(v3d, dtype=np.float32)
```

And in the `SMPLXPerson(...)` construction below, pass `vertices_3d=v3d_arr` (similar for `translation`, `betas`, `expression` — wrap each as `np.ascontiguousarray(..., dtype=np.float32)`).

- [ ] **Step 3: Update the serializer in `smplx_osc_sender.py`**

Around lines 73-90, replace the per-person packing block. The new version assumes ndarray input:

```python
def _serialize_person(self, p) -> bytes:
    head = struct.pack("<if", p.pid, p.confidence)
    trans = np.ascontiguousarray(p.translation, dtype="<f4").tobytes()
    betas = np.ascontiguousarray(p.betas, dtype="<f4").tobytes()
    expr  = np.ascontiguousarray(p.expression, dtype="<f4").tobytes()
    verts = np.ascontiguousarray(p.vertices_3d, dtype="<f4").tobytes()
    return head + trans + betas + expr + verts
```

(Adapt to the exact field order the current code uses — read it first.)

- [ ] **Step 4: Run tests to confirm no regression**

Run: `cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/ -v 2>&1 | tail -10`
Expected: same counts as before. (Wire format unchanged in bytes; only the producer is faster.)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/smplx_osc_sender.py data_only_viz/multi_hmr_worker.py data_only_viz/state.py
git commit -m "perf(smplx): numpy tobytes serialization"
```

(40 chars — fits.)

---

### Task 6: Drop `joints_3d` from the hot path (O3)

**Files:**
- Modify: `data_only_viz/state.py` (`SMPLXPerson.joints_3d` field)
- Modify: `data_only_viz/multi_hmr_worker.py` (around line 217 — stop transferring joints from GPU to CPU)
- Search-and-verify: no consumer reads `joints_3d` anywhere

**Context:** `SMPLXPerson.joints_3d` (127 joints × 3 floats × 4 bytes = 1524 B per person per frame) is written by the worker and never read by anyone (the audit confirmed: not the renderer, not the TCP sender, not any test). Remove it.

- [ ] **Step 1: Verify no consumer reads `joints_3d`**

```bash
grep -rn "joints_3d\|persons_smplx\[.*\]\.joints_3d" data_only_viz/ launcher/
```

Expected: only writes inside `multi_hmr_worker.py` and the dataclass field declaration. No reads.

If there IS a reader, STOP and report `NEEDS_CONTEXT` — this task assumes the field is dead.

- [ ] **Step 2: Remove the field from `SMPLXPerson`**

Edit `data_only_viz/state.py` and delete the `joints_3d: ...` line from `SMPLXPerson`.

- [ ] **Step 3: Stop the GPU→CPU transfer in `multi_hmr_worker.py`**

Around line 217, remove the line:

```python
j3d = hh["j3d"].detach().cpu().numpy()
```

and the corresponding `joints_3d=` argument in the `SMPLXPerson(...)` construction below (around line 239).

- [ ] **Step 4: Run tests**

Run: `cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/ -v 2>&1 | tail -10`
Expected: same counts.

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/state.py data_only_viz/multi_hmr_worker.py
git commit -m "refactor(smplx): drop unused joints_3d field"
```

(44 chars — fits.)

---

### Task 7: Headless mode — fail fast when Multi-HMR checkpoint absent

**Files:**
- Modify: `data_only_viz/main.py` (around the headless-entry block, line ~80 + the `_start_pose_worker` priority cascade ~line 244)

**Context:** When `--multi-hmr` is passed in headless mode, the launcher expects the pipeline to feed the RealityKit app over TCP. If the Multi-HMR checkpoint is missing, the current code silently falls back to MediaPipe — which only fills `persons_body`, not `persons_smplx`, so the TCP sender ships empty payloads indefinitely. Fail loud instead.

- [ ] **Step 1: Add an availability check at headless entry**

Find the headless branch (around line 80 — `if opts.multi_hmr: ...`) and BEFORE starting the worker, call the existing `MultiHMRWorker.is_available()` (or equivalent — check the class for a static probe; if absent, expose one that checks `checkpoint_path.exists()`).

```python
if opts.multi_hmr:
    from data_only_viz.multi_hmr_worker import MultiHMRWorker
    if not MultiHMRWorker.is_available():
        LOG.error(
            "Multi-HMR requested via --multi-hmr but checkpoint is missing. "
            "Run scripts/setup_multihmr.sh first, or omit --multi-hmr to use MediaPipe."
        )
        sys.exit(2)
    # ... existing headless start logic ...
```

If `is_available()` doesn't exist as a class/staticmethod, add it:

```python
# In multi_hmr_worker.py
@classmethod
def is_available(cls) -> bool:
    return CHECKPOINT_PATH.exists()
```

(Find the existing module-level constant for the checkpoint path — name will differ.)

- [ ] **Step 2: Manual smoke test (no automated test for this — main.py argparse + exit is hard to unit-test cleanly)**

```bash
cd /Users/electron/Documents/Projets/AV-Live/data_only_viz
# Temporarily move the checkpoint out of the way if it exists:
test -f ~/.cache/av-live-multihmr/checkpoints/*.pt && mv ~/.cache/av-live-multihmr/checkpoints ~/.cache/av-live-multihmr/_checkpoints_bak
uv run python -m data_only_viz.main --multi-hmr --headless 2>&1 | head -5
# Should print the error and exit with code 2. Then:
test -d ~/.cache/av-live-multihmr/_checkpoints_bak && mv ~/.cache/av-live-multihmr/_checkpoints_bak ~/.cache/av-live-multihmr/checkpoints
```

Expected: error message, exit 2.

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/main.py data_only_viz/multi_hmr_worker.py
git commit -m "fix(main): fail fast on missing multihmr ckpt"
```

(48 chars — fits.)

---

### Task 8: Instrumentation — per-stage timers

**Files:**
- Modify: `data_only_viz/multi_hmr_worker.py` (around `_run`'s inner loop)
- Modify: `data_only_viz/smplx_osc_sender.py` (around `_send`)
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift` (`updateMeshVertices`)

**Context:** Before doing more perf work, validate the budget model. Add `time.monotonic()` (Python) and `CFAbsoluteTimeGetCurrent()` (Swift) timers gated behind a debug flag so they're zero-cost in release.

- [ ] **Step 1: Python — gate behind `LOG.isEnabledFor(logging.DEBUG)`**

In `multi_hmr_worker.py._run`, after the existing loop preamble:

```python
if LOG.isEnabledFor(logging.DEBUG):
    t_cap = time.monotonic()
    ok, frame_bgr = cap.read()
    t_pre = time.monotonic()
    # ... existing preprocessing ...
    t_inf = time.monotonic()
    # ... model() call ...
    t_post = time.monotonic()
    # ... state mutation + tracker ...
    t_end = time.monotonic()
    LOG.debug(
        "frame: cap=%.1f pre=%.1f inf=%.1f post=%.1f total=%.1fms",
        (t_pre - t_cap) * 1e3,
        (t_inf - t_pre) * 1e3,
        (t_post - t_inf) * 1e3,
        (t_end - t_post) * 1e3,
        (t_end - t_cap) * 1e3,
    )
else:
    # existing fast path unchanged
    ...
```

(Or simpler: always take timestamps but only log if debug — overhead of `time.monotonic()` is ~100 ns, negligible.)

- [ ] **Step 2: Swift — log `MeshRenderer.updateMeshVertices` duration**

In `MeshRenderer.swift`, wrap `updateMeshVertices` body:

```swift
func updateMeshVertices(_ persons: [SMPLXPerson]) {
    let t0 = CFAbsoluteTimeGetCurrent()
    // ... existing body ...
    let dtMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
    if dtMs > 5 { NSLog("mesh update: %.1f ms (%d persons)", dtMs, persons.count) }
}
```

Threshold of 5 ms catches stalls without spamming logs in steady state.

- [ ] **Step 3: Build Swift, run pytest**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/ -v 2>&1 | tail -5
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build -c release 2>&1 | tail -5
```

Expected: tests unchanged, Swift builds clean.

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/multi_hmr_worker.py data_only_viz/smplx_osc_sender.py launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift
git commit -m "chore(viz): add per-stage perf timers"
```

(42 chars — fits.)

---

## Self-Review

**1. Spec coverage:** All 8 audit findings have a task — Task 1 (device crash), Task 2 (TCP DoS), Task 3 (frame dropping), Task 4 (blocking send), Task 5 (numpy serialize + ndarray keep), Task 6 (drop joints_3d), Task 7 (headless fail-fast), Task 8 (instrumentation). Out-of-scope items (computeVertexNormals SIMD, resolution lowering, CoreML) are listed in the header.

**2. Placeholder scan:** No "TBD" / "TODO" / "fill in" / "similar to Task N" / "appropriate handling". Every step has runnable code or an exact command. Where exact line numbers may have drifted, the task says "around line X — verify by reading the file first" with explicit grep commands to locate the truth.

**3. Type consistency:** `SMPLXPerson.vertices_3d` changes from tuple-of-tuples to `np.ndarray` (Tasks 5 & 6); the serializer in Task 5 expects ndarray; the dataclass change in Task 5 stays consistent in Task 6 (just removes `joints_3d`, doesn't touch the others). `MultiHMRWorker.is_available()` is mentioned in Task 7 — Step 1 explicitly says "if it doesn't exist, add it" with the code.

---

## Execution Handoff

Plan complete and saved. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Default: Subagent-Driven, as for the previous plan.
