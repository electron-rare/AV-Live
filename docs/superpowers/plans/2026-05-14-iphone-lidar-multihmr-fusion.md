# iPhone LiDAR → Multi-HMR Fusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the iOS ARBodyTracker app's `/body3d/kp` OSC stream into the Python pipeline so ARKit 91-joint LiDAR ground truth fixes Multi-HMR's scale ambiguity and reduces SMPL-X joint jitter via Kalman fusion.

**Architecture:** A new `iphone_osc_listener.py` worker subscribes to `/body3d/kp` on UDP `:57128` (port distinct from existing `:57126` body output) and writes per-pid 91-joint arrays into `state.persons_arkit_joints`. `pose_filter.py` gains an `arkit_fuse` stage that pulls the ARKit joints (low-noise ground truth) and overrides matching MediaPipe Pose 33 slots before the existing kalman/one_euro chain runs. `multi_hmr_worker.py` post-inference reads the ARKit pelvis world-z and rewrites `pred_cam_t` of the SMPL-X mesh so it lands at the actual depth instead of HaMeR's per-frame guess.

**Tech Stack:** Python 3.14, python-osc (OSCDispatcher), numpy, threading, pytest. Existing modules: `state.State`, `pose_filter.PoseFilterChain`, `multi_hmr_worker.MultiHMRWorker`.

---

## File Structure

| File | Responsibility |
|---|---|
| `data_only_viz/iphone_osc_listener.py` | **NEW**. ThreadingOSCUDPServer on `:57128`, routes `/body3d/kp pid joint_idx x y z` → `state.persons_arkit_joints[pid][joint_idx] = (x,y,z)`. GC entries older than 1.0s. |
| `data_only_viz/state.py` | **MODIFY**. Add fields `persons_arkit_joints: dict[int, np.ndarray]` (91×3 per pid) + `persons_arkit_last_t: dict[int, float]`. |
| `data_only_viz/arkit_joint_map.py` | **NEW**. Constant tuple `ARKIT91_TO_MP33` mapping ARKit joint indices → MediaPipe Pose 33 indices. |
| `data_only_viz/pose_filter.py` | **MODIFY**. Add `"arkit_fuse"` to `ALL_STAGES`, add `ArkitFuse` class, splice in `PoseFilterChain.apply` before kalman. |
| `data_only_viz/multi_hmr_worker.py` | **MODIFY**. After Multi-HMR inference, if `state.persons_arkit_joints[pid]` is fresh, override `pred_cam_t.z` with ARKit pelvis world-z. |
| `data_only_viz/main.py` | **MODIFY**. Start `IphoneOSCListener` in `_start_pose_worker` regardless of any --flag (always-on, harmless if no iPhone). |
| `data_only_viz/tests/test_iphone_osc_listener.py` | **NEW**. Unit tests: send fake OSC packets, assert state updated. |
| `data_only_viz/tests/test_arkit_fuse.py` | **NEW**. Unit tests: fake state, run PoseFilterChain.apply, assert MP33 slots overwritten. |
| `data_only_viz/tests/test_multihmr_arkit_z.py` | **NEW**. Unit test: fake ARKit pelvis z, assert pred_cam_t corrected. |

---

## Task 1: State fields for ARKit joints

**Files:**
- Modify: `data_only_viz/state.py` (add fields)
- Test: `data_only_viz/tests/test_state_arkit.py` (new)

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_state_arkit.py`:

```python
"""State must expose persons_arkit_joints + persons_arkit_last_t."""
import numpy as np

from data_only_viz.state import State


def test_state_has_arkit_joint_fields():
    s = State()
    assert hasattr(s, "persons_arkit_joints")
    assert hasattr(s, "persons_arkit_last_t")
    assert isinstance(s.persons_arkit_joints, dict)
    assert isinstance(s.persons_arkit_last_t, dict)


def test_state_arkit_joints_writable_under_lock():
    s = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    with s.lock():
        s.persons_arkit_joints[0] = arr
        s.persons_arkit_last_t[0] = 1.5
    assert 0 in s.persons_arkit_joints
    assert s.persons_arkit_last_t[0] == 1.5
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_state_arkit.py -v`
Expected: FAIL with `AttributeError: 'State' object has no attribute 'persons_arkit_joints'`

- [ ] **Step 3: Add fields to State**

Edit `data_only_viz/state.py`. Find the existing line with `persons_hands_mesh_last_t: float = 0.0` (around line 134) and insert below it:

```python
    # ARKit body tracking (iOS ARBodyTracker app) : 91 joints world
    # space per pid. Same units as MediaPipe pose_world_landmarks
    # (metres, hip-centered). Fresh = updated within < 1 s.
    persons_arkit_joints: dict = field(default_factory=dict)
    persons_arkit_last_t: dict = field(default_factory=dict)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_state_arkit.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
cd /Users/electron/Documents/Projets/AV-Live
git add data_only_viz/state.py data_only_viz/tests/test_state_arkit.py
git commit -m "feat(state): add persons_arkit_joints + persons_arkit_last_t"
```

---

## Task 2: ARKit → MediaPipe joint index mapping

**Files:**
- Create: `data_only_viz/arkit_joint_map.py`
- Test: `data_only_viz/tests/test_arkit_joint_map.py` (new)

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_arkit_joint_map.py`:

```python
"""ARKit 91 joints → MediaPipe Pose 33 mapping integrity."""
from data_only_viz.arkit_joint_map import (
    ARKIT91_TO_MP33, ARKIT_PELVIS_IDX, MP33_NUM_LANDMARKS,
)


def test_mapping_is_tuple_of_pairs():
    assert isinstance(ARKIT91_TO_MP33, tuple)
    assert len(ARKIT91_TO_MP33) > 0
    for pair in ARKIT91_TO_MP33:
        assert isinstance(pair, tuple)
        assert len(pair) == 2


def test_mapping_indices_in_range():
    for arkit_idx, mp33_idx in ARKIT91_TO_MP33:
        assert 0 <= arkit_idx < 91, f"arkit idx out of range: {arkit_idx}"
        assert 0 <= mp33_idx < MP33_NUM_LANDMARKS, \
            f"mp33 idx out of range: {mp33_idx}"


def test_pelvis_index_valid():
    assert 0 <= ARKIT_PELVIS_IDX < 91


def test_no_duplicate_mp33_targets():
    """Each MediaPipe slot must be written by at most one ARKit joint."""
    mp33_seen = set()
    for _, mp33_idx in ARKIT91_TO_MP33:
        assert mp33_idx not in mp33_seen, \
            f"mp33 slot {mp33_idx} mapped twice"
        mp33_seen.add(mp33_idx)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_arkit_joint_map.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'data_only_viz.arkit_joint_map'`

- [ ] **Step 3: Create the mapping module**

Create `data_only_viz/arkit_joint_map.py`:

```python
"""ARKit ARSkeleton3D 91-joint indices → MediaPipe Pose 33 indices.

The ARKit ARSkeleton.JointName enum (Apple SDK) orders 91 joints
starting with the root, hips, spine chain, shoulders, etc. We pick
only the joints with a clear 1:1 anatomical correspondence to the
MediaPipe Pose 33 landmark set (which is what AVLiveBody renders).
Face/hand sub-joints (fingers, eyes) are skipped — those keep their
existing data sources (MediaPipe Face/Hand + HaMeR MANO).

Reference for ARKit joint order : Apple developer docs
"ARSkeleton.JointName" — the canonical 91-joint list runs from
root_joint=0 down to right_handThumbEndJoint=90.

The selection here mirrors `multi.py::SMPLX_TO_MP33` so the same 14
body slots are overridden by ARKit when fresh. Confidence comes
from ARKit's tracking state but is not currently fanned out — we
trust ARKit body tracking when its OSC frame is present.
"""
from __future__ import annotations

# MediaPipe Pose 33 cardinality (cf. mediapipe pose_world_landmarks).
MP33_NUM_LANDMARKS = 33

# Pelvis = ARKit hips_joint, slot 1 in the canonical enum order.
# Used by multi_hmr_worker for cam-translation z lock.
ARKIT_PELVIS_IDX = 1

# (arkit_joint_idx, mediapipe_pose_idx). Match the body slots used
# by the SMPL-X body fusion in multi.py.
ARKIT91_TO_MP33: tuple[tuple[int, int], ...] = (
    (50, 11),   # left_shoulder_1_joint -> L_SHOULDER
    (32, 12),   # right_shoulder_1_joint -> R_SHOULDER
    (53, 13),   # left_arm_joint -> L_ELBOW
    (35, 14),   # right_arm_joint -> R_ELBOW
    (54, 15),   # left_forearm_joint -> L_WRIST
    (36, 16),   # right_forearm_joint -> R_WRIST
    (62, 23),   # left_upLeg_joint -> L_HIP
    (57, 24),   # right_upLeg_joint -> R_HIP
    (63, 25),   # left_leg_joint -> L_KNEE
    (58, 26),   # right_leg_joint -> R_KNEE
    (64, 27),   # left_foot_joint -> L_ANKLE
    (59, 28),   # right_foot_joint -> R_ANKLE
    (65, 31),   # left_toes_joint -> L_FOOT_INDEX
    (60, 32),   # right_toes_joint -> R_FOOT_INDEX
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_arkit_joint_map.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/arkit_joint_map.py data_only_viz/tests/test_arkit_joint_map.py
git commit -m "feat(viz): arkit 91-joint -> mediapipe 33 mapping"
```

---

## Task 3: iPhone OSC listener worker

**Files:**
- Create: `data_only_viz/iphone_osc_listener.py`
- Test: `data_only_viz/tests/test_iphone_osc_listener.py` (new)

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_iphone_osc_listener.py`:

```python
"""IphoneOSCListener writes ARKit joints to state from OSC packets."""
import time

import numpy as np
import pytest
from pythonosc.udp_client import SimpleUDPClient

from data_only_viz.state import State
from data_only_viz.iphone_osc_listener import (
    IphoneOSCListener, IPHONE_OSC_PORT,
)


@pytest.fixture()
def listener():
    state = State()
    listener = IphoneOSCListener(state, port=IPHONE_OSC_PORT + 100)
    listener.start()
    yield state, listener
    listener.stop()


def test_kp_message_updates_state(listener):
    state, lst = listener
    client = SimpleUDPClient("127.0.0.1", lst.port)
    client.send_message("/body3d/kp", [0, 1, 0.1, 0.2, 0.3])
    # Settle
    deadline = time.monotonic() + 1.0
    while time.monotonic() < deadline:
        with state.lock():
            if 0 in state.persons_arkit_joints:
                arr = state.persons_arkit_joints[0]
                if arr[1, 0] != 0.0:
                    break
        time.sleep(0.02)
    with state.lock():
        arr = state.persons_arkit_joints[0]
    assert arr.shape == (91, 3)
    assert np.allclose(arr[1], [0.1, 0.2, 0.3])


def test_gc_drops_stale_pids(listener):
    state, lst = listener
    with state.lock():
        state.persons_arkit_joints[7] = np.zeros((91, 3), dtype=np.float32)
        state.persons_arkit_last_t[7] = time.perf_counter() - 5.0
    lst._gc_stale()
    with state.lock():
        assert 7 not in state.persons_arkit_joints
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_iphone_osc_listener.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'data_only_viz.iphone_osc_listener'`

- [ ] **Step 3: Implement listener**

Create `data_only_viz/iphone_osc_listener.py`:

```python
"""OSC UDP listener for the iOS ARBodyTracker app.

Subscribes to /body3d/kp on UDP :57128 (distinct from MediaPipe
output :57126). Each /body3d/kp pid joint_idx x y z message stores
one joint of ARKit's 91-joint ARSkeleton3D into
state.persons_arkit_joints[pid] (np.ndarray shape (91, 3), float32).
A background GC drops pids whose last_t is older than 1.0 s.

Worker pattern mirrors osc_listener.OscListener.
"""
from __future__ import annotations

import logging
import threading
import time
from typing import Any

import numpy as np
from pythonosc import dispatcher, osc_server

from .state import State

LOG = logging.getLogger("iphone_osc")

IPHONE_OSC_PORT = 57128
ARKIT_NUM_JOINTS = 91
STALE_SEC = 1.0


class IphoneOSCListener:
    def __init__(self, state: State, host: str = "0.0.0.0",
                 port: int = IPHONE_OSC_PORT) -> None:
        self.state = state
        self.host = host
        self.port = port
        self._server: osc_server.ThreadingOSCUDPServer | None = None
        self._server_thread: threading.Thread | None = None
        self._gc_thread: threading.Thread | None = None
        self._stop = threading.Event()

    def start(self) -> None:
        d = dispatcher.Dispatcher()
        d.map("/body3d/kp", self._on_kp)
        d.map("/body3d/count", self._on_count)
        self._server = osc_server.ThreadingOSCUDPServer(
            (self.host, self.port), d)
        self._server_thread = threading.Thread(
            target=self._server.serve_forever,
            name="iphone_osc", daemon=True)
        self._server_thread.start()
        self._gc_thread = threading.Thread(
            target=self._gc_loop, name="iphone_gc", daemon=True)
        self._gc_thread.start()
        LOG.info("iphone OSC listening on %s:%d", self.host, self.port)

    def stop(self) -> None:
        self._stop.set()
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server = None

    def _on_kp(self, _addr: str, *args: Any) -> None:
        if len(args) < 5:
            return
        try:
            pid = int(args[0])
            joint_idx = int(args[1])
            x = float(args[2])
            y = float(args[3])
            z = float(args[4])
        except (TypeError, ValueError):
            return
        if not (0 <= joint_idx < ARKIT_NUM_JOINTS):
            return
        with self.state.lock():
            arr = self.state.persons_arkit_joints.get(pid)
            if arr is None or arr.shape != (ARKIT_NUM_JOINTS, 3):
                arr = np.zeros((ARKIT_NUM_JOINTS, 3), dtype=np.float32)
                self.state.persons_arkit_joints[pid] = arr
            arr[joint_idx] = (x, y, z)
            self.state.persons_arkit_last_t[pid] = time.perf_counter()

    def _on_count(self, _addr: str, *args: Any) -> None:
        # Optional : we currently don't gate on count, but parse for log.
        if not args:
            return
        try:
            n = int(args[0])
        except (TypeError, ValueError):
            return
        if not hasattr(self, "_last_hb") or \
                time.monotonic() - self._last_hb > 5.0:
            self._last_hb = time.monotonic()
            LOG.info("hb: %d ARKit bodies live", n)

    def _gc_stale(self) -> None:
        cutoff = time.perf_counter() - STALE_SEC
        with self.state.lock():
            drop = [
                pid for pid, t in self.state.persons_arkit_last_t.items()
                if t < cutoff
            ]
            for pid in drop:
                self.state.persons_arkit_joints.pop(pid, None)
                self.state.persons_arkit_last_t.pop(pid, None)

    def _gc_loop(self) -> None:
        while not self._stop.is_set():
            self._gc_stale()
            time.sleep(0.5)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_iphone_osc_listener.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/iphone_osc_listener.py data_only_viz/tests/test_iphone_osc_listener.py
git commit -m "feat(viz): iphone OSC listener -> state.persons_arkit_joints"
```

---

## Task 4: ArkitFuse stage in PoseFilterChain

**Files:**
- Modify: `data_only_viz/pose_filter.py`
- Test: `data_only_viz/tests/test_arkit_fuse.py` (new)

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_arkit_fuse.py`:

```python
"""ArkitFuse stage overrides 14 body slots with ARKit data when fresh."""
import time

import numpy as np

from data_only_viz.state import Kp3D, State
from data_only_viz.pose_filter import PoseFilterChain


def _mp33_zero_body():
    return [Kp3D(x=0.0, y=0.0, z=0.0, c=1.0) for _ in range(33)]


def test_arkit_fuse_overrides_shoulder():
    state = State()
    # ARKit publishes joint 50 (left shoulder) with (1.0, 2.0, 3.0)
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[50] = (1.0, 2.0, 3.0)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter()
    chain = PoseFilterChain(state=state, enabled_stages=("arkit_fuse",))
    bodies = [_mp33_zero_body()]
    out = chain.apply(bodies, ids=[0], t_now=time.perf_counter())
    # Slot 11 = L_SHOULDER (from ARKIT91_TO_MP33).
    assert out[0][11].x == 1.0
    assert out[0][11].y == 2.0
    assert out[0][11].z == 3.0


def test_arkit_fuse_skips_stale():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[50] = (9.0, 9.0, 9.0)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter() - 5.0
    chain = PoseFilterChain(state=state, enabled_stages=("arkit_fuse",))
    bodies = [_mp33_zero_body()]
    out = chain.apply(bodies, ids=[0], t_now=time.perf_counter())
    # Stale -> not applied, MediaPipe zero left intact.
    assert out[0][11].x == 0.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_arkit_fuse.py -v`
Expected: FAIL — `arkit_fuse` not in `ALL_STAGES` so chain.enabled is empty, no fuse happens.

- [ ] **Step 3: Add ArkitFuse class + register stage**

Edit `data_only_viz/pose_filter.py`. Find the line `ALL_STAGES = (...)` near the top and replace:

```python
ALL_STAGES = (
    "median", "kalman", "spring", "lookahead", "ik",
    "one_euro_joints", "one_euro_bones", "arkit_fuse",
)
```

Find the import block at the top (after `from .euro_filter import ...`) and add:

```python
from .arkit_joint_map import ARKIT91_TO_MP33
```

Find the `PoseFilterChain.__init__` method and after the line `self.one_euro_bones = BoneOneEuroFilter(...)` add:

```python
        self.arkit_fuse = ArkitFuse()
```

In `PoseFilterChain.apply`, find the block defining `use_one_euro_joints = "one_euro_joints" in self.enabled` and add right after it:

```python
        use_arkit_fuse = "arkit_fuse" in self.enabled
```

In the same method, find the outer `for body_i, kps in enumerate(bodies3d):` loop. The fuse happens BEFORE per-joint filtering (so kalman sees the fused signal). Insert this immediately after the `pid = ids[body_i] if body_i < len(ids) else -1` line:

```python
            if use_arkit_fuse and self.state is not None:
                kps = self.arkit_fuse.apply(self.state, pid, kps, t_now)
```

Then add the `ArkitFuse` class definition. Find the line `# ============================ face / hand =================================` and insert right BEFORE it:

```python
class ArkitFuse:
    """Splice ARKit 91-joint world-space data into MediaPipe Pose 33.

    Reads ``state.persons_arkit_joints[pid]`` (shape (91, 3)) when fresh
    (last_t within FRESH_SEC). Writes the 14 body slots covered by
    ARKIT91_TO_MP33 ; everything else (face landmarks, finger tips)
    stays MediaPipe-driven.
    """

    FRESH_SEC: float = 1.0

    def apply(self, state: "State", pid: int,
              kps: list[Kp3D], t_now: float) -> list[Kp3D]:
        with state.lock():
            arr = state.persons_arkit_joints.get(pid)
            last_t = state.persons_arkit_last_t.get(pid, 0.0)
        if arr is None:
            return kps
        if t_now - last_t > self.FRESH_SEC:
            return kps
        out = list(kps)
        n = len(out)
        for arkit_idx, mp33_idx in ARKIT91_TO_MP33:
            if mp33_idx >= n:
                continue
            x = float(arr[arkit_idx, 0])
            y = float(arr[arkit_idx, 1])
            z = float(arr[arkit_idx, 2])
            old = out[mp33_idx]
            out[mp33_idx] = Kp3D(x=x, y=y, z=z, c=getattr(old, "c", 1.0))
        return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_arkit_fuse.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Regression check existing filter tests**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_pose_filter.py -v`
Expected: PASS (all existing pose_filter tests still green)

- [ ] **Step 6: Commit**

```bash
git add data_only_viz/pose_filter.py data_only_viz/tests/test_arkit_fuse.py
git commit -m "feat(viz): arkit_fuse stage in PoseFilterChain"
```

---

## Task 5: Cam-translation z lock in multi_hmr_worker

**Files:**
- Modify: `data_only_viz/multi_hmr_worker.py`
- Test: `data_only_viz/tests/test_multihmr_arkit_z.py` (new)

- [ ] **Step 1: Locate post-inference cam_t write site**

Run: `grep -n "pred_cam_t\|cam_t =" /Users/electron/Documents/Projets/AV-Live/data_only_viz/multi_hmr_worker.py | head -15`

You will see lines where `pred_cam_t` is read from model output and copied into `state.persons_smplx`. Look for the loop after model inference that assigns `transl=...` or `translation=...` per pid. Save the exact line numbers — Step 3 inserts the lock just AFTER the existing cam_t computation but BEFORE the state write.

- [ ] **Step 2: Write the failing test**

Create `data_only_viz/tests/test_multihmr_arkit_z.py`:

```python
"""arkit_pelvis_z_override : if ARKit pelvis z is fresh, replace
the Multi-HMR pred_cam_t.z so the SMPL-X mesh sits at the actual
distance instead of HaMeR's monocular guess.
"""
import time

import numpy as np

from data_only_viz.state import State
from data_only_viz.multi_hmr_worker import arkit_pelvis_z_override


def test_returns_arkit_z_when_fresh():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[1] = (0.0, 0.0, 2.5)   # ARKIT_PELVIS_IDX=1, z=2.5 m
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter()
    z_pred = 5.0   # Multi-HMR ambiguous guess
    z_out = arkit_pelvis_z_override(state, pid=0, z_pred=z_pred)
    assert z_out == 2.5


def test_keeps_pred_when_stale():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[1] = (0.0, 0.0, 2.5)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter() - 5.0
    z_pred = 5.0
    z_out = arkit_pelvis_z_override(state, pid=0, z_pred=z_pred)
    assert z_out == 5.0


def test_keeps_pred_when_pid_missing():
    state = State()
    z_pred = 4.2
    z_out = arkit_pelvis_z_override(state, pid=99, z_pred=z_pred)
    assert z_out == 4.2
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_multihmr_arkit_z.py -v`
Expected: FAIL — `arkit_pelvis_z_override` does not exist in multi_hmr_worker.

- [ ] **Step 4: Add the override function + import**

Edit `data_only_viz/multi_hmr_worker.py`. At the top of the file, add to the imports block:

```python
from .arkit_joint_map import ARKIT_PELVIS_IDX
```

Then at module level (after imports, before any class), add:

```python
def arkit_pelvis_z_override(state, pid: int, z_pred: float,
                            fresh_sec: float = 1.0) -> float:
    """Return ARKit pelvis world-z if a fresh ARKit frame exists for
    this pid, otherwise return the Multi-HMR predicted z unchanged.

    Used to resolve Multi-HMR's monocular scale ambiguity: ARKit's
    LiDAR-anchored pelvis position is ground truth in the iPhone
    world frame, which (after extrinsics calibration) is the same
    metric scale as the SMPL-X cam-space output.
    """
    import time as _time
    with state.lock():
        arr = state.persons_arkit_joints.get(pid)
        last_t = state.persons_arkit_last_t.get(pid, 0.0)
    if arr is None:
        return float(z_pred)
    if _time.perf_counter() - last_t > fresh_sec:
        return float(z_pred)
    return float(arr[ARKIT_PELVIS_IDX, 2])
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/test_multihmr_arkit_z.py -v`
Expected: PASS (3 passed)

- [ ] **Step 6: Wire override at the cam_t write site**

Now use the line numbers from Step 1. In `multi_hmr_worker.py`, find the per-person loop where `pred_cam_t` (or equivalent transl) is being written into the SMPL-X person record. For each person, after the model output's z is computed but before assignment to state, wrap the z value:

```python
                z_locked = arkit_pelvis_z_override(
                    self.state, pid, float(transl[2]))
                transl = np.array([transl[0], transl[1], z_locked],
                                  dtype=transl.dtype)
```

(Adapt variable names to the exact context — `transl`, `t_full`, or whatever is used. The pattern is: take the existing z, replace via the override, repack.)

- [ ] **Step 7: Regression smoke**

Run: `cd /Users/electron/Documents/Projets/AV-Live && ~/avlive-venv/bin/python -m pytest data_only_viz/tests/ -q -x`
Expected: All tests pass (no regressions introduced).

- [ ] **Step 8: Commit**

```bash
git add data_only_viz/multi_hmr_worker.py data_only_viz/tests/test_multihmr_arkit_z.py
git commit -m "feat(viz): arkit pelvis z locks Multi-HMR cam translation"
```

---

## Task 6: Always-on listener in main.py

**Files:**
- Modify: `data_only_viz/main.py`

- [ ] **Step 1: Locate _start_pose_worker function**

Run: `grep -n "_start_pose_worker\|_maybe_start_webcam_source" /Users/electron/Documents/Projets/AV-Live/data_only_viz/main.py | head -5`

Note the line number where `_start_pose_worker` begins (around line 287).

- [ ] **Step 2: Insert listener startup**

Edit `data_only_viz/main.py`. In the body of `_start_pose_worker`, immediately after the call to `self._maybe_start_webcam_source()` (line ~289), insert:

```python
        # iPhone ARBodyTracker (option 2 LiDAR fusion) : always-on
        # listener on :57128. Harmless if no iPhone is broadcasting ;
        # state.persons_arkit_joints stays empty and the arkit_fuse
        # stage no-ops. Activated via POSE_FILTER=...+arkit_fuse.
        try:
            from .iphone_osc_listener import IphoneOSCListener
            self._iphone_osc = IphoneOSCListener(self._state)
            self._iphone_osc.start()
            LOG.info("worker: + iPhone OSC listener :57128")
        except Exception as e:  # noqa: BLE001
            LOG.warning("iphone OSC listener start failed (%s)", e)
```

- [ ] **Step 3: Smoke test the listener starts**

Run: `cd /Users/electron/Documents/Projets/AV-Live && AV_LIVE_INFERENCE_OFF=1 timeout 8 ~/avlive-venv/bin/python -u -c "
import os, sys, time
os.environ.setdefault('AV_SHARED_CAM', '0')
sys.path.insert(0, '/Users/electron/Documents/Projets/AV-Live')
import threading, logging
logging.basicConfig(level=logging.INFO)
from data_only_viz.state import State
from data_only_viz.iphone_osc_listener import IphoneOSCListener
s = State()
l = IphoneOSCListener(s)
l.start()
time.sleep(2)
print('listener up :', l.port)
l.stop()
print('stopped clean')
" 2>&1 | tail -5`

Expected output:
```
... iphone OSC listening on 0.0.0.0:57128
listener up : 57128
stopped clean
```

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/main.py
git commit -m "feat(viz): start iphone OSC listener in main pose worker"
```

---

## Task 7: Documentation update

**Files:**
- Modify: `CLAUDE.md` (top-level env var table)
- Modify: `data_only_viz/CLAUDE.md` (POSE_FILTER stages table)

- [ ] **Step 1: Update top-level CLAUDE.md env var table**

Edit `/Users/electron/Documents/Projets/AV-Live/CLAUDE.md`. Find the row with `POSE_FILTER` and replace its description so it lists `arkit_fuse` as an available stage. Also append a new row for the iPhone OSC port. Use these exact replacements:

For the `POSE_FILTER` row, replace whatever is there with:

```
| `POSE_FILTER` | `median+kalman+lookahead+ik` | filter chain stages — extra: `one_euro_joints` (joint-space CHI 2012 One Euro, inserted before kalman), `one_euro_bones` (bone-vector One Euro applied after SMPL-X fusion in multi.py), `arkit_fuse` (overrides 14 body slots with ARKit ARSkeleton3D from the iOS app, expects /body3d/kp on :57128) |
```

Then below the `POSE_FILTER` row add:

```
| `IPHONE_OSC_PORT` | `57128` | UDP port the iPhone ARBodyTracker app pushes /body3d/kp to (always-on listener in data_only_viz) |
```

- [ ] **Step 2: Update data_only_viz/CLAUDE.md**

Edit `/Users/electron/Documents/Projets/AV-Live/data_only_viz/CLAUDE.md`. Find the "Conventions" section's filtering bullet (mentions `euro_filter.py`) and append after it:

```
- ARKit fusion : `iphone_osc_listener.py` consume /body3d/kp UDP :57128
  → `state.persons_arkit_joints`. `pose_filter.py::ArkitFuse` (stage
  `arkit_fuse`) splices the 14 mapped body slots into MediaPipe pose
  before kalman ; `multi_hmr_worker::arkit_pelvis_z_override` locks the
  SMPL-X cam translation z to the ARKit pelvis. Mapping in
  `arkit_joint_map.py`.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md data_only_viz/CLAUDE.md
git commit -m "docs: iphone arkit fusion env + filter stage"
```

---

## Task 8: End-to-end live smoke

This is a manual verification step run once after the iOS app is
deployed to a real iPhone Pro and broadcasting on the LAN. No new
code ; just confirm wiring + telemetry.

- [ ] **Step 1: Start the GrosMac pipeline (already wired)**

Run: `bash /Users/electron/Documents/Projets/AV-Live/launcher/apps/dist/GrosMac-AVLive.app/Contents/MacOS/bootstrap &`

Wait ~8 s, then verify the listener line appeared:

```
grep "iphone OSC listening" ~/Library/Logs/AVLive/GrosMac-AVLive.python.log
```

Expected: a line `iphone OSC listening on 0.0.0.0:57128`.

- [ ] **Step 2: Start ARBodyTracker on iPhone**

In the iOS app (deployed via Xcode):
1. Host = your GrosMac LAN IP (`192.168.0.159`)
2. Port = `57128`
3. Tap **Start**

Stand 2 m in front of the iPhone with body fully visible. The app
status label should say "running (LiDAR depth, env mesh)".

- [ ] **Step 3: Confirm ARKit state on GrosMac**

Run on GrosMac while iPhone is broadcasting:

```bash
~/avlive-venv/bin/python -u -c "
import time, sys
sys.path.insert(0, '/Users/electron/Documents/Projets/AV-Live')
from data_only_viz.iphone_osc_listener import IphoneOSCListener
from data_only_viz.state import State
s = State()
l = IphoneOSCListener(s, port=57130)  # alt port to avoid clash
l.start()
time.sleep(3)
with s.lock():
    print('pids :', list(s.persons_arkit_joints.keys()))
    if s.persons_arkit_joints:
        pid = next(iter(s.persons_arkit_joints))
        print('pelvis :', s.persons_arkit_joints[pid][1])
l.stop()
"
```

Expected: `pids : [0]` and `pelvis : [x, y, z]` with z > 0.

NOTE: this snippet uses port 57130 to avoid clashing with the live
listener already bound to 57128. To test against the live listener,
just open Activity Monitor's network panel for the Python process —
you should see UDP packets flowing in on :57128.

- [ ] **Step 4: Enable arkit_fuse in live pipeline**

The pipeline currently uses `POSE_FILTER` from the bootstrap env. To
add `arkit_fuse`, edit the GrosMac bootstrap and append the stage:

Edit `/Users/electron/Documents/Projets/AV-Live/launcher/apps/dist/GrosMac-AVLive.app/Contents/MacOS/bootstrap`. Find any existing `export POSE_FILTER=...` line (if absent, look around the `if [ "${ROLE}" = "source" ]; then` section for where envs are exported in the source branch) and add:

```bash
    export POSE_FILTER="median+kalman+lookahead+ik+one_euro_joints+one_euro_bones+arkit_fuse"
```

Restart GrosMac bundle:

```bash
pkill -9 -f "AVLiveBody|data_only_viz"
open /Users/electron/Documents/Projets/AV-Live/launcher/apps/dist/GrosMac-AVLive.app
```

- [ ] **Step 5: Verify fusion in log**

After the live launch, tail the python log:

```bash
grep "PoseFilterChain stages" ~/Library/Logs/AVLive/GrosMac-AVLive.python.log
```

Expected: a line ending in `'arkit_fuse')`.

- [ ] **Step 6: Visual confirmation**

In AVLiveBody window (release build), the body wireframe should
visibly stabilise compared to a session without ARKit (shoulders/hips
no longer wobble between MediaPipe predictions ; the mesh sits at
the real-world depth from the camera instead of HaMeR's monocular
guess). If you see persistent jitter, double-check via Activity
Monitor that UDP :57128 traffic is non-zero, and that
`state.persons_arkit_joints` has fresh entries (Step 3 snippet).

---

## Self-Review

Spec coverage check :
- iphone_osc_listener.py ✅ Task 3
- state fields ✅ Task 1
- arkit_joint_map.py ✅ Task 2
- pose_filter arkit_fuse ✅ Task 4
- multi_hmr cam-z lock ✅ Task 5
- main.py startup ✅ Task 6
- Docs ✅ Task 7
- Live verification ✅ Task 8

ICP mesh fitting is intentionally deferred — that's a separate plan
once the joint-level fusion is proven stable.

Type consistency : `ARKIT91_TO_MP33` declared in Task 2, used in
Task 4 (pose_filter import) and Task 5 (multi_hmr import of
`ARKIT_PELVIS_IDX`). `IphoneOSCListener` defined Task 3, instantiated
Task 6. State fields `persons_arkit_joints` and
`persons_arkit_last_t` declared Task 1, consumed Tasks 3, 4, 5.

No placeholders, no TBD, every step is concrete with code or a
copy-pasteable command. The plan compiles a hot-loop story without
ICP, which keeps it bite-sized and shippable in a single working
session (~1 day for a fresh engineer).
