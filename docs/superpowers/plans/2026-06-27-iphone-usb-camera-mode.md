# iPhone-USB Camera Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Drive `data_only_viz` entirely from the iPhone over USB — HEVC video → PyAV → MediaPipe, ARKit skeleton → arkit_fuse, Vision hands → hand features — with no Mac webcam.

**Architecture:** A new `IphoneUSBSource` (cv2-`VideoCapture`-shaped) backed by a USB reader thread that decodes HEVC video and writes ARKit skeleton + Vision hands straight into `State`. `multi.py` uses it in place of `cv2.VideoCapture` under a `--iphone-usb` flag. The HEVC decode is already de-risked (256 frames at ~28fps from real iPhone access units).

**Tech Stack:** Python 3.11, PyAV 17.1.0 (HEVC decode, already installed in the venv), usbmux (AF_UNIX `/var/run/usbmuxd`), the existing `iphone_usb_bridge.py` (connect + demux), MediaPipe.

## Global Constraints

- Reuse `data_only_viz/scripts/iphone_usb_bridge.py`: `connect_device()`, `iter_frames()`, `decode_skeleton()`, `to_annexb` logic, the AVLiveWire constants (MAGIC, HEADER_LEN, TAG_SKELETON=1, etc.). Do NOT reimplement usbmux/demux.
- Tags: skeleton=1, video=2, hands=4, face=5 (face out of scope).
- HEVC AUs are length-prefixed NALs → convert each 4-byte length to `00 00 00 01` (Annex-B) before `av.Packet`. VPS/SPS/PPS are prepended on keyframes.
- Frame source contract (from `multi.py` / `_av_capture.py:14`): `.read() -> (ok, frame_bgr)` where `frame_bgr` is a BGR `np.ndarray`. Also provide `.isOpened()`, `.set(*a)` (no-op returning True), `.release()`.
- ARKit store is the SAME one `iphone_osc_listener._on_kp` fills: `state.persons_arkit_joints[pid]` = numpy `(91,3)` float32, `state.persons_arkit_last_t[pid]` = `time.perf_counter()`. `arkit_fuse` reads it (POSE_FILTER must include `arkit_fuse`).
- All state mutation under `state.lock()`.
- Tests run on **macm1** (the iPhone is plugged there; SC/camera stack proven). The ARBodyTracker app must be running and the iPhone unlocked: launch via `xcrun devicectl device process launch --device AC1CDE5F-DDC4-5B2C-80D7-9953D8ABA0AC cc.saillant.ARBodyTracker` (fails "Locked" if the phone is locked — ask the human to unlock). Edit on GrosMac, `scp` to macm1, run there.
- `uv`/venv: run via `~/Documents/Projets/AV-Live/data_only_viz/.venv/bin/python` on macm1.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `data_only_viz/iphone_usb_source.py` (new) | `IphoneUSBSource`: USB reader thread (video decode + skeleton + hands), cv2-shaped `.read()` |
| `data_only_viz/multi.py` (modify) | pick `IphoneUSBSource` when iphone-usb mode is on |
| `data_only_viz/main.py` (modify) | `--iphone-usb` flag, thread it to the worker, skip Mac-camera TCC |

---

## Task 1: `IphoneUSBSource` — video decode + cv2 `.read()`

**Files:**
- Create: `data_only_viz/iphone_usb_source.py`
- Test: `/tmp/test_iphone_src.scd` → actually `/tmp/test_iphone_src.py` (scratch)

**Interfaces:**
- Consumes: `iphone_usb_bridge.connect_device()`, `iter_frames()` (TAG values, MAGIC).
- Produces: `IphoneUSBSource(state=None, target_size=(640,480))` with `.start()->bool`, `.isOpened()->bool`, `.read()->(bool, np.ndarray|None)`, `.set(*a)->bool`, `.release()->None`.

- [ ] **Step 1: Write the failing test**

Create `/tmp/test_iphone_src.py`:

```python
import sys, time
sys.path.insert(0, "/Users/electron/Documents/Projets/AV-Live")
from data_only_viz.iphone_usb_source import IphoneUSBSource
src = IphoneUSBSource(state=None, target_size=(640, 480))
assert src.start(), "[FAIL] start() returned False"
ok = False
t0 = time.monotonic()
while time.monotonic() - t0 < 8:
    got, frame = src.read()
    if got and frame is not None:
        print(f"[PASS] read frame shape={frame.shape} dtype={frame.dtype}")
        assert frame.shape[1] == 640 and frame.shape[2] == 3, "[FAIL] not downscaled BGR"
        print("[PASS] downscaled BGR 640 wide")
        ok = True
        break
    time.sleep(0.1)
src.release()
print("[PASS] released" if ok else "[FAIL] no frame within 8s")
```

- [ ] **Step 2: Run to verify it fails**

Run on macm1 (app running): `data_only_viz/.venv/bin/python /tmp/test_iphone_src.py 2>&1 | grep -E "PASS|FAIL|Error"`
Expected: import error (module missing).

- [ ] **Step 3: Write `iphone_usb_source.py`**

```python
"""IphoneUSBSource — a cv2-VideoCapture-shaped frame source backed by the
iPhone ARBodyTracker USB stream. Decodes the AVLiveWire HEVC video to BGR
frames for MediaPipe, and (Task 2) writes ARKit skeleton + Vision hands into
State. Substitutes for cv2.VideoCapture in multi.py under --iphone-usb."""
from __future__ import annotations

import logging
import threading
import time

import av
import cv2
import numpy as np

from data_only_viz.scripts.iphone_usb_bridge import (
    connect_device, iter_frames, TAG_SKELETON,
)

TAG_VIDEO = 2
TAG_HANDS = 4
LOG = logging.getLogger("iphone_usb_source")


def _to_annexb(data: bytes) -> bytes:
    out = bytearray(); i = 0
    while i + 4 <= len(data):
        n = int.from_bytes(data[i:i + 4], "big"); i += 4
        if i + n > len(data):
            break
        out += b"\x00\x00\x00\x01" + data[i:i + n]; i += n
    return bytes(out)


class IphoneUSBSource:
    def __init__(self, state=None, target_size=(640, 480)) -> None:
        self.state = state
        self.target_w, self.target_h = target_size
        self._codec = av.codec.CodecContext.create("hevc", "r")
        self._lock = threading.Lock()
        self._frame = None            # latest BGR np.ndarray
        self._stop = threading.Event()
        self._thread = None
        self._opened = False

    def start(self) -> bool:
        sock = connect_device()
        if sock is None:
            LOG.error("iphone usb: no device / connect failed")
            return False
        self._opened = True
        self._thread = threading.Thread(
            target=self._run, args=(sock,), name="iphone_usb_src", daemon=True)
        self._thread.start()
        return True

    def isOpened(self) -> bool:
        return self._opened

    def _run(self, sock) -> None:
        try:
            for tag, pid, payload in iter_frames(sock):
                if self._stop.is_set():
                    break
                if tag == TAG_VIDEO and len(payload) > 1:
                    annexb = _to_annexb(payload[1:])
                    try:
                        for fr in self._codec.decode(av.Packet(annexb)):
                            img = fr.to_ndarray(format="bgr24")
                            img = cv2.resize(img, (self.target_w, self.target_h))
                            with self._lock:
                                self._frame = img
                    except av.AVError as e:
                        LOG.debug("hevc decode: %s", e)
                # skeleton + hands handled in Task 2
        except OSError as e:
            LOG.warning("iphone usb stream ended: %s", e)
        finally:
            try:
                sock.close()
            except OSError:
                pass
            self._opened = False

    def read(self):
        with self._lock:
            if self._frame is None:
                return False, None
            return True, self._frame.copy()

    def set(self, *args) -> bool:
        return True   # cv2 CAP_PROP_* no-op

    def release(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=2.0)
        self._opened = False
```

- [ ] **Step 4: scp + run test on macm1**

Run:
```
scp ~/Documents/Projets/AV-Live/data_only_viz/iphone_usb_source.py macm1:Documents/Projets/AV-Live/data_only_viz/iphone_usb_source.py
scp /tmp/test_iphone_src.py macm1:/tmp/test_iphone_src.py
ssh macm1 'xcrun devicectl device process launch --device AC1CDE5F-DDC4-5B2C-80D7-9953D8ABA0AC cc.saillant.ARBodyTracker 2>&1 | tail -1; sleep 3; cd ~/Documents/Projets/AV-Live && data_only_viz/.venv/bin/python /tmp/test_iphone_src.py 2>&1 | grep -E "PASS|FAIL|Error|Locked"'
```
Expected: `[PASS] read frame shape=(480, 640, 3)`, `[PASS] downscaled BGR 640 wide`, `[PASS] released`. (If "Locked" → ask the human to unlock the iPhone.)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/iphone_usb_source.py
git commit -m "feat(viz): iphone USB source with HEVC video decode"
```

---

## Task 2: ARKit skeleton + Vision hands into State

**Files:**
- Modify: `data_only_viz/iphone_usb_source.py` (handle TAG_SKELETON + TAG_HANDS in `_run`)
- Test: `/tmp/test_iphone_state.py`

**Interfaces:**
- Consumes: `iphone_usb_bridge.decode_skeleton(payload)` → `[(x,y,z,valid), ...]` len 91; `state.lock()`; `state.persons_arkit_joints` / `persons_arkit_last_t`; `state.persons_hands`.
- Reads the existing State field shapes — the implementer MUST read `data_only_viz/state.py` to match the exact types (`persons_arkit_joints[pid]` numpy (91,3) float32, and what `persons_hands` holds — the 21-point hand landmark structure `HandFeatureExtractor` expects; check `data_only_viz/hand_features.py` for the input shape).

- [ ] **Step 1: Write the failing test**

Create `/tmp/test_iphone_state.py`:

```python
import sys, time
sys.path.insert(0, "/Users/electron/Documents/Projets/AV-Live")
from data_only_viz.iphone_usb_source import IphoneUSBSource
from data_only_viz.state import State
st = State()
src = IphoneUSBSource(state=st, target_size=(640, 480))
assert src.start(), "[FAIL] start"
t0 = time.monotonic(); got_skel = False
while time.monotonic() - t0 < 10:
    with st.lock():
        if st.persons_arkit_joints:
            pid = next(iter(st.persons_arkit_joints))
            arr = st.persons_arkit_joints[pid]
            print(f"[PASS] arkit_joints pid={pid} shape={arr.shape}")
            assert arr.shape == (91, 3), "[FAIL] wrong arkit shape"
            got_skel = True
            break
    time.sleep(0.1)
src.release()
print("[PASS] skeleton in state" if got_skel else "[INFO] no body in frame (stand in front of iPhone)")
```

- [ ] **Step 2: Run to verify it fails** (skeleton never lands)

Run (on macm1, app running, you in front of the iPhone): `... python /tmp/test_iphone_state.py | grep -E "PASS|FAIL|INFO"`
Expected: `[INFO] no body in frame` (skeleton not handled yet) — or a FAIL if it somehow lands.

- [ ] **Step 3: Handle skeleton + hands in `_run`**

In `iphone_usb_source.py`, add imports and, in `_run`'s per-frame loop, after the video branch:

```python
                elif tag == TAG_SKELETON and self.state is not None:
                    joints = decode_skeleton(payload)
                    if joints is not None:
                        arr = np.array([[j[0], j[1], j[2]] for j in joints], dtype=np.float32)
                        with self.state.lock():
                            self.state.persons_arkit_joints[pid] = arr
                            self.state.persons_arkit_last_t[pid] = time.perf_counter()
                elif tag == TAG_HANDS and self.state is not None:
                    hands = _decode_hands(payload)   # see below
                    if hands is not None:
                        with self.state.lock():
                            self.state.persons_hands = hands
```

Add `from data_only_viz.scripts.iphone_usb_bridge import decode_skeleton` to the imports, and a `_decode_hands` helper. HandsPayload layout: `count:u8`, then per hand `chirality:u8 (1=right)` + `21 × (x,y,z) BE f32`. Map each hand to the 21-point structure `HandFeatureExtractor` consumes — **read `data_only_viz/hand_features.py` to get the exact per-point type** (likely a PoseKp/namedtuple with normalized x,y; z relative; c=1.0). Write `_decode_hands` to return that structure (a list of hands, each a list of 21 points). Example skeleton (adapt the point type to what hand_features expects):

```python
import struct
def _decode_hands(payload: bytes):
    if not payload:
        return None
    n = payload[0]; off = 1; hands = []
    for _ in range(n):
        if off + 1 + 21 * 12 > len(payload):
            break
        # chirality = payload[off]  (0=left, 1=right) — keep if hand_features uses it
        off += 1
        pts = struct.unpack(">" + "f" * 63, payload[off:off + 21 * 12]); off += 21 * 12
        hand = [_make_point(pts[i*3], pts[i*3+1], pts[i*3+2]) for i in range(21)]
        hands.append(hand)
    return hands
```

(`_make_point` constructs whatever `hand_features.py` expects — match it exactly.)

- [ ] **Step 4: scp + re-run state test on macm1** (stand in front of the iPhone)

Run the scp + `python /tmp/test_iphone_state.py | grep -E "PASS|FAIL"`.
Expected: `[PASS] arkit_joints pid=… shape=(91, 3)`, `[PASS] skeleton in state`. (Requires a body in the iPhone's view.)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/iphone_usb_source.py
git commit -m "feat(viz): feed ARKit skeleton and hands into State"
```

---

## Task 3: Wire `--iphone-usb` into multi.py + main.py

**Files:**
- Modify: `data_only_viz/multi.py` (capture construction)
- Modify: `data_only_viz/main.py` (flag + thread it; skip camera TCC)
- Test: `/tmp/test_iphone_mode.py`

**Interfaces:**
- Consumes: `IphoneUSBSource` (Tasks 1-2). The implementer MUST read `multi.py` around the capture (`cap = cv2.VideoCapture(self.camera_index)`, ~line 346) and the `MultiWorker.__init__` signature, and `main.py` around `_request_camera_and_start_pose` (~line 205) and the argparse block (~line 639) to thread the flag through exactly.

- [ ] **Step 1: Write the failing test**

Create `/tmp/test_iphone_mode.py`:

```python
import subprocess, time, signal, os
p = subprocess.Popen(
    ["data_only_viz/.venv/bin/python", "-m", "data_only_viz.main", "--pose", "--iphone-usb"],
    cwd="/Users/electron/Documents/Projets/AV-Live",
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    env={**os.environ, "POSE_FILTER": "median+kalman+lookahead+ik+arkit_fuse",
         "MEDIAPIPE_DELEGATE": "cpu"})
time.sleep(12)
p.send_signal(signal.SIGINT); out, _ = p.communicate(timeout=10)
ok_flag = "iphone" in out.lower() or "usb" in out.lower()
ok_body = "body3d" in out or "render:" in out
print("[PASS] --iphone-usb accepted + worker ran" if (ok_flag and ok_body) else "[FAIL]")
print(out[-800:])
```

- [ ] **Step 2: Run to verify it fails**

Run on macm1: `... python /tmp/test_iphone_mode.py | grep -E "PASS|FAIL|error: unrecognized|render:"`
Expected: argparse error `unrecognized arguments: --iphone-usb`.

- [ ] **Step 3: Add the flag + wiring**

- `main.py` argparse: `p.add_argument("--iphone-usb", dest="iphone_usb", action="store_true", help="drive pose from the iPhone USB stream (no Mac camera)")`.
- Thread `self._opts.iphone_usb` into the pose worker (the `MultiWorker`/pose worker constructor — pass an `iphone_usb=` kwarg, default False).
- In `_request_camera_and_start_pose`: when `iphone_usb` is set, skip the AVFoundation TCC request and start the pose worker directly (IphoneUSBSource does its own usbmux connect — no camera TCC).
- `multi.py`: in the capture construction, `if self.iphone_usb: from data_only_viz.iphone_usb_source import IphoneUSBSource; cap = IphoneUSBSource(self.state); cap.start()` else the existing `cv2.VideoCapture(self.camera_index)`. The frame loop (`ok, frame_bgr = cap.read()`) is unchanged. Add a log line `"multi — iphone USB source"` for the test to assert on.

(Read the exact constructor/option-passing pattern in main.py + multi.py and match it — do not invent a new option-passing mechanism.)

- [ ] **Step 4: scp + run mode test on macm1**

scp `multi.py`, `main.py` (and `iphone_usb_source.py` if changed). Run `python /tmp/test_iphone_mode.py | grep -E "PASS|FAIL|render:|iphone"`.
Expected: `[PASS] --iphone-usb accepted + worker ran` (the worker opens the USB source and the renderer ticks; no hang).

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/multi.py data_only_viz/main.py
git commit -m "feat(viz): --iphone-usb mode wiring"
```

---

## Task 4: Live smoke (manual)

- [ ] On macm1 (iPhone unlocked, ARBodyTracker running, SC body-play booted with `~doScene.(\play)`): launch `POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse MEDIAPIPE_DELEGATE=cpu data_only_viz/.venv/bin/python -m data_only_viz.main --pose --iphone-usb` in a GUI `.command`. Stand in front of the **iPhone**: confirm MediaPipe detects you on the iPhone video (render segs > 0), the ARKit skeleton refines the body, hands drive the lead/chord, and body-play reacts audibly. Everything from the iPhone, no Mac webcam. (Manual — no automated assertion.)

---

## Self-Review notes

- **Spec coverage:** IphoneUSBSource video decode (T1) · skeleton+hands into State (T2) · multi.py pluggable + main.py flag + skip-TCC (T3) · live smoke (T4) · arkit_fuse via POSE_FILTER (constraint, T4). All spec sections covered.
- **De-risk reuse:** the HEVC `_to_annexb` + `codec.decode` path in T1 is the exact code validated on 256 real frames.
- **Type consistency:** `IphoneUSBSource.read()` returns `(bool, np.ndarray|None)` matching `multi.py`'s `ok, frame_bgr = cap.read()`. `persons_arkit_joints[pid]` is `(91,3)` float32 in both T2 and the existing `iphone_osc_listener`.
- **Known risk:** the exact `persons_hands` / hand-point type (T2) and the option-threading pattern (T3) are verified by reading `hand_features.py` / `state.py` / `multi.py` / `main.py` during implementation — flagged in each task. 1920×1440 → 640×480 downscale (T1) keeps MediaPipe real-time on CPU.
