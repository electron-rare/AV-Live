# ARKit-only body position Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drive the matrix's body position/modulation 100% from the iPhone ARKit skeleton (2D + 3D) and cut the Mac MediaPipe pose/face inference under `--iphone-usb`.

**Architecture:** The iPhone already computes a 2D-projected skeleton for its overlay; we send it over USB as a new `skeleton2D` AVLiveWire frame. The Mac decodes it into `persons_arkit_2d`, builds the MP33 body (2D image-normalized) + `bodies3d` (3D world, from the existing 3D `skeleton`) from the ARKit joints, skips MediaPipe pose/face/hand inference, and emits `/pose/*` from the ARKit body. `arkit_fuse` is dropped (ARKit is the source).

**Tech Stack:** Swift (AVLiveWire package + the iPhone Swift app), Python 3 (data_only_viz), `swift test` + `pytest`.

## Global Constraints

- Commit subject ≤ 50 chars, no underscore in scope, no AI attribution, no `--no-verify`. No emojis. Keep `git commit` on its OWN command line (compound `grep && git commit` trips the block-no-verify hook).
- 91 ARKit joints (`JOINT_COUNT = 91`). The matrix is single-person.
- The 2D skeleton is sent VIEWPORT-NORMALIZED (0..1), `x` = left→right, `y` = top→down (image convention), matching MediaPipe's normalized landmark space so `/pose/center` etc. read identically.
- The iPhone app rebuild (`xcodegen generate` → Xcode → ⌘R on the device) is a MANUAL USER STEP — the agent cannot build/deploy Swift on the device. The Mac pure-function parts ARE unit-tested here; the live integration is verified on the rig after the rebuild.
- `swift test` runs in `shared/AVLiveWire` (the wire package) and is testable in this environment. The iPhone app Swift is NOT buildable here (needs ARKit/device).
- ARKit→MP33 mapping in `arkit_joint_map.py` (`ARKIT91_TO_MP33`, 14 body slots). Extend with a head/neck → MP33 slot 0 anchor.

## File Structure

- `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift` — add `skeleton2D = 5` tag.
- `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift` — add `Skeleton2DPayload` (91×(x,y) Float32 + 91 valid UInt8) encode/decode.
- `shared/AVLiveWire/Tests/AVLiveWireTests/` — round-trip test for the new payload.
- `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` — send the 2D skeleton.
- `data_only_viz/scripts/iphone_usb_bridge.py` — `TAG_SKELETON2D` + `decode_skeleton2D`.
- `data_only_viz/iphone_usb_source.py` — handle `TAG_SKELETON2D` → `state.persons_arkit_2d`.
- `data_only_viz/state.py` — `persons_arkit_2d` / `persons_arkit_2d_t` fields.
- `data_only_viz/arkit_joint_map.py` — `arkit_body_from_2d` / `arkit_body3d_from_world` builders + head mapping.
- `data_only_viz/multi.py` — under `--iphone-usb`, build the body from ARKit + skip MediaPipe pose/face.
- `data_only_viz/tests/test_arkit_body.py` — builder unit tests.
- `launcher/concert/launch_concert.sh` — drop `arkit_fuse` from POSE_FILTER.

---

### Task 1: AVLiveWire — `skeleton2D` tag + payload (Swift, testable)

**Files:** Modify `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`, `WirePayloads.swift`; add a test in `shared/AVLiveWire/Tests/AVLiveWireTests/`.

**Interfaces:**
- Produces: `FrameTag.skeleton2D` (raw 5); `Skeleton2DPayload` with `static let jointCount = 91`, `var points: [SIMD2<Float>]`, `var valid: [Bool]`, `func encoded() -> Data`, `static func decode(_:) -> Skeleton2DPayload?`. Wire layout: 91×(x:Float32,y:Float32) big-endian then 91×UInt8 valid.

- [ ] **Step 1: Read the existing `SkeletonPayload`** in `WirePayloads.swift` to mirror its style (it has `jointCount`, `joints: [SIMD3<Float>]`, `valid`, `encoded()`, `decode`). Then add a failing round-trip test in a new/existing test file:
```swift
import XCTest
@testable import AVLiveWire

final class Skeleton2DPayloadTests: XCTestCase {
    func testRoundTrip() {
        var p = Skeleton2DPayload()
        for i in 0..<Skeleton2DPayload.jointCount {
            p.points[i] = SIMD2(Float(i) * 0.001, Float(i) * 0.002)
            p.valid[i] = (i % 2 == 0)
        }
        let data = p.encoded()
        let r = Skeleton2DPayload.decode(data)
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.points[10].x, p.points[10].x, accuracy: 1e-6)
        XCTAssertEqual(r!.valid[10], p.valid[10])
        XCTAssertEqual(r!.valid[11], p.valid[11])
    }
}
```

- [ ] **Step 2: Run — expect FAIL** (`Skeleton2DPayload` undefined).
Run: `cd shared/AVLiveWire && swift test --filter Skeleton2DPayloadTests`
Expected: build error / FAIL.

- [ ] **Step 3: Add the tag.** In `FrameHeader.swift`, add to `FrameTag`:
```swift
    case skeleton2D = 5
```

- [ ] **Step 4: Add `Skeleton2DPayload`** in `WirePayloads.swift`, mirroring `SkeletonPayload` but 2 floats/joint:
```swift
public struct Skeleton2DPayload {
    public static let jointCount = 91
    public var points: [SIMD2<Float>]
    public var valid: [Bool]
    public init() {
        points = Array(repeating: SIMD2<Float>(0, 0), count: Self.jointCount)
        valid = Array(repeating: false, count: Self.jointCount)
    }
    public func encoded() -> Data {
        var d = Data(capacity: Self.jointCount * 8 + Self.jointCount)
        for p in points {
            for v in [p.x, p.y] { d.append(contentsOf: withUnsafeBytes(of: v.bitPattern.bigEndian) { Data($0) }) }
        }
        for b in valid { d.append(b ? 1 : 0) }
        return d
    }
    public static func decode(_ data: Data) -> Skeleton2DPayload? {
        let floatBytes = jointCount * 2 * 4
        guard data.count == floatBytes + jointCount else { return nil }
        var out = Skeleton2DPayload()
        let bytes = [UInt8](data)
        for i in 0..<jointCount {
            func f(_ off: Int) -> Float {
                let b = (UInt32(bytes[off]) << 24) | (UInt32(bytes[off+1]) << 16) | (UInt32(bytes[off+2]) << 8) | UInt32(bytes[off+3])
                return Float(bitPattern: b)
            }
            out.points[i] = SIMD2(f(i*8), f(i*8 + 4))
            out.valid[i] = bytes[floatBytes + i] != 0
        }
        return out
    }
}
```
(If `SkeletonPayload` uses a different encoding helper, MATCH its style — the round-trip test is the gate, not this exact code.)

- [ ] **Step 5: Run — expect PASS.**
Run: `cd shared/AVLiveWire && swift test --filter Skeleton2DPayloadTests` (and `swift test` for the full suite — no regression).

- [ ] **Step 6: Commit.**
```bash
git add shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift shared/AVLiveWire/Tests/AVLiveWireTests
git commit -m "feat(wire): skeleton2D frame payload"
```

---

### Task 2: iPhone app — send the 2D skeleton (Swift, device-only)

**Files:** Modify `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift`.

**Interfaces:**
- Consumes: `FrameTag.skeleton2D`, `Skeleton2DPayload` (Task 1); the app's `skeleton2D`/`projectPoint` viewport projection.
- Produces: a `usb.send(tag: .skeleton2D, ...)` per tracked body, points normalized 0..1 by viewport.

NOTE: this Swift is NOT buildable in the agent environment (needs ARKit/device). The implementer writes it from the brief; the USER rebuilds (`xcodegen generate` → Xcode → ⌘R) and verifies on device.

- [ ] **Step 1: Send the 2D skeleton in `publishUSB`** (after the existing 3D `.skeleton` send). The 91 viewport-projected points already exist via `ARCamera.projectPoint`; build a `Skeleton2DPayload` with `x = projected.x / viewportSize.width`, `y = projected.y / viewportSize.height` (clamped finite; `valid[i] = isJointTracked(i) && finite`), and send it:
```swift
        var p2 = Skeleton2DPayload()
        let orient = currentInterfaceOrientation()
        for i in 0..<min(Skeleton2DPayload.jointCount, transforms.count) {
            let w = root * transforms[i]
            let p3 = SIMD3<Float>(w.columns.3.x, w.columns.3.y, w.columns.3.z)
            let proj = camera.projectPoint(p3, orientation: orient, viewportSize: viewportSize)
            let nx = Float(proj.x / max(viewportSize.width, 1)),
                ny = Float(proj.y / max(viewportSize.height, 1))
            if nx.isFinite && ny.isFinite {
                p2.points[i] = SIMD2(nx, ny)
                p2.valid[i] = skeleton.isJointTracked(i)
            }
        }
        usb.send(tag: .skeleton2D, pid: Int16(clamping: pid), timestamp: timestamp, payload: p2.encoded())
```
(`camera` + `viewportSize` are the same the app uses for its overlay projection — wire them through to `publishUSB`; read the existing `updateSkeleton2D` for how the app gets `camera`/`viewportSize`/`orient`.)

- [ ] **Step 2: Commit** (the user rebuilds/deploys separately).
```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift
git commit -m "feat(iphone): send 2D projected skeleton"
```

---

### Task 3: Mac decode — `decode_skeleton2D` + state

**Files:** Modify `data_only_viz/scripts/iphone_usb_bridge.py`, `data_only_viz/iphone_usb_source.py`, `data_only_viz/state.py`; add `data_only_viz/tests/test_arkit_body.py`.

**Interfaces:**
- Produces: `TAG_SKELETON2D = 5`; `decode_skeleton2D(payload) -> list[(x, y, valid)] | None` (len 91); `state.persons_arkit_2d: dict[int, np.ndarray]` (91×2) + `persons_arkit_2d_t: dict[int, float]`.

- [ ] **Step 1: Failing test** in `data_only_viz/tests/test_arkit_body.py`:
```python
import struct
from data_only_viz.scripts.iphone_usb_bridge import decode_skeleton2D, JOINT_COUNT

def test_decode_skeleton2d_roundtrip():
    floats = []
    for i in range(JOINT_COUNT):
        floats += [i * 0.001, i * 0.002]
    payload = struct.pack(">" + "f" * (JOINT_COUNT * 2), *floats)
    payload += bytes(1 if i % 2 == 0 else 0 for i in range(JOINT_COUNT))
    out = decode_skeleton2D(payload)
    assert out is not None and len(out) == JOINT_COUNT
    assert abs(out[10][0] - 0.010) < 1e-5 and out[10][2] is True
    assert out[11][2] is False
```

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_arkit_body.py -q`
Expected: ImportError on `decode_skeleton2D`.

- [ ] **Step 3: Add `TAG_SKELETON2D` + `decode_skeleton2D`** in `iphone_usb_bridge.py` (next to `decode_skeleton`):
```python
TAG_SKELETON2D = 5
SKEL2D_FLOAT_BYTES = JOINT_COUNT * 2 * 4
SKEL2D_BYTES = SKEL2D_FLOAT_BYTES + JOINT_COUNT


def decode_skeleton2D(payload: bytes):
    """Return [(x, y, valid), ...] of length 91 (normalized 0..1), or None."""
    if len(payload) != SKEL2D_BYTES:
        return None
    floats = struct.unpack(">" + "f" * (JOINT_COUNT * 2), payload[:SKEL2D_FLOAT_BYTES])
    valid = payload[SKEL2D_FLOAT_BYTES:]
    return [(floats[i * 2], floats[i * 2 + 1], valid[i] != 0) for i in range(JOINT_COUNT)]
```

- [ ] **Step 4: Add the state fields** in `state.py` (near `persons_arkit_joints`):
```python
    persons_arkit_2d: dict[int, "np.ndarray"] = field(default_factory=dict)
    persons_arkit_2d_t: dict[int, float] = field(default_factory=dict)
```

- [ ] **Step 5: Handle `TAG_SKELETON2D` in `iphone_usb_source`** (mirror the `TAG_HANDS`/skeleton handlers; import `TAG_SKELETON2D, decode_skeleton2D`):
```python
                    elif tag == TAG_SKELETON2D and self.state is not None:
                        pts = decode_skeleton2D(payload)
                        if pts is not None:
                            import numpy as np
                            arr = np.array([[x, y] for (x, y, _v) in pts], dtype=np.float32)
                            with self.state.lock():
                                self.state.persons_arkit_2d[pid] = arr
                                self.state.persons_arkit_2d_t[pid] = time.perf_counter()
```

- [ ] **Step 6: Run — expect PASS.**
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_arkit_body.py -q`

- [ ] **Step 7: Commit.**
```bash
git add data_only_viz/scripts/iphone_usb_bridge.py data_only_viz/iphone_usb_source.py data_only_viz/state.py data_only_viz/tests/test_arkit_body.py
git commit -m "feat(pose): decode iphone 2D skeleton"
```

---

### Task 4: Mac body-build from ARKit + cut MediaPipe

**Files:** Modify `data_only_viz/arkit_joint_map.py` (builders + head map), `data_only_viz/multi.py` (use them under iphone-usb, skip MP pose/face); extend `data_only_viz/tests/test_arkit_body.py`.

**Interfaces:**
- Consumes: `ARKIT91_TO_MP33`, `persons_arkit_2d`, `persons_arkit_joints`.
- Produces: `arkit_body_2d(arr2d) -> list[PoseKp]` (MP33, image-normalized, c=1 for mapped slots else 0), `arkit_body_3d(arr3d) -> list[Kp3D]`; `ARKIT91_TO_MP33` gains a head→0 entry.

- [ ] **Step 1: Failing builder test** — append to `test_arkit_body.py`:
```python
import numpy as np
from data_only_viz.arkit_joint_map import arkit_body_2d, ARKIT91_TO_MP33

def test_arkit_body_2d_maps_slots():
    arr = np.zeros((91, 2), dtype=np.float32)
    for ai, _mp in ARKIT91_TO_MP33:
        arr[ai] = [0.3 + ai * 0.001, 0.4]
    body = arkit_body_2d(arr)
    assert len(body) == 33
    # a mapped slot is confident; an unmapped face slot is not
    mapped_mp = ARKIT91_TO_MP33[0][1]
    assert body[mapped_mp].c > 0.5
    assert body[1].c < 0.5    # MP slot 1 (eye) has no ARKit source
```

- [ ] **Step 2: Run — expect FAIL** (`arkit_body_2d` undefined).
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_arkit_body.py::test_arkit_body_2d_maps_slots -q`

- [ ] **Step 3: Add the head map + builders** in `arkit_joint_map.py`. Add a head anchor (the ARKit `head_joint` index — find it in the Apple enum; commonly index 51 in the 91-list; CONFIRM by checking which ARKit index sits above the shoulders in a live frame, else use the neck/spine7. Use `(51, 0)` as the head→nose anchor and note it for live verification). Append it to `ARKIT91_TO_MP33`. Then:
```python
from .pose_filter import PoseKp  # if PoseKp lives there; else from .state
# (use the project's PoseKp/Kp3D types — read multi.py imports)

def arkit_body_2d(arr2d):
    """91x2 normalized ARKit 2D -> MP33 PoseKp list (mapped slots c=1, else c=0)."""
    from .state import PoseKp  # adjust import to the real location
    body = [PoseKp(x=0.5, y=0.5, z=0.0, c=0.0) for _ in range(33)]
    for ai, mp in ARKIT91_TO_MP33:
        if mp < 33 and ai < len(arr2d):
            body[mp] = PoseKp(x=float(arr2d[ai][0]), y=float(arr2d[ai][1]), z=0.0, c=1.0)
    return body

def arkit_body_3d(arr3d):
    """91x3 world ARKit -> MP33 Kp3D list (mapped slots c=1, else c=0)."""
    from .state import Kp3D  # adjust import
    body = [Kp3D(x=0.0, y=0.0, z=0.0, c=0.0) for _ in range(33)]
    for ai, mp in ARKIT91_TO_MP33:
        if mp < 33 and ai < len(arr3d):
            body[mp] = Kp3D(x=float(arr3d[ai][0]), y=float(arr3d[ai][1]), z=float(arr3d[ai][2]), c=1.0)
    return body
```
(Read `multi.py`/`state.py` for the exact `PoseKp`/`Kp3D` constructors and import paths; the test gates correctness.)

- [ ] **Step 4: Run — expect PASS.**
Run: `cd data_only_viz && .venv/bin/python -m pytest tests/test_arkit_body.py -q`

- [ ] **Step 5: Wire into `multi.py` under `--iphone-usb`.** In the per-frame loop: skip the MediaPipe pose+face inference (`pose_res`/`face_res = None if self.iphone_usb else ...`); when `self.iphone_usb`, build `bodies`/`bodies3d` from `state.persons_arkit_2d`/`persons_arkit_joints` (one pid → one body) via `arkit_body_2d`/`arkit_body_3d` instead of the MediaPipe `pose_res` parse; set `faces = []`. Guard the MP-derived `bodies`/`faces` build + the body3d arkit_fuse so they don't run under iphone-usb (the ARKit body is the source). Keep the `/pose/*` emit + the `state` write (now fed by the ARKit body). Read the loop carefully — this mirrors the hands cut (commit `4c0794a`) but for pose+face.

- [ ] **Step 6: Verify syntax + the builder tests still pass.**
`python3 -m py_compile data_only_viz/multi.py` (no output); `cd data_only_viz && .venv/bin/python -m pytest tests/test_arkit_body.py -q` (PASS).

- [ ] **Step 7: Commit.**
```bash
git add data_only_viz/arkit_joint_map.py data_only_viz/multi.py data_only_viz/tests/test_arkit_body.py
git commit -m "feat(pose): build body from arkit, cut mediapipe pose"
```

---

### Task 5: Launcher — drop `arkit_fuse`

**Files:** Modify `launcher/concert/launch_concert.sh`.

- [ ] **Step 1:** Change `export POSE_FILTER=median+kalman+lookahead+ik+arkit_fuse` to `export POSE_FILTER=median+kalman+lookahead+ik` (ARKit is now the source, not a fuse). Lint: `zsh -n launcher/concert/launch_concert.sh`.

- [ ] **Step 2: Commit.**
```bash
git add launcher/concert/launch_concert.sh
git commit -m "chore(launcher): drop arkit_fuse, arkit is source"
```

---

### Task 6: Deploy + live smoke (USER-DRIVEN, iPhone rebuild)

**Files:** none.

- [ ] **Step 1:** `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'`. THE USER rebuilds the iPhone app: `cd iphone-arbody && xcodegen generate`, open in Xcode, ⌘R on the connected iPhone (so it sends `skeleton2D`). Then restart the pose pipeline (full launcher restart, or restart `data_only_viz.main` with the env).
- [ ] **Step 2:** Confirm: the body position tracks from ARKit (stable, no MediaPipe jitter); `/pose/center`/`kin`/`sho_span`/`limb_span` respond to movement; CPU drops (no MediaPipe pose/face inference); the head anchor (`/pose/head`) is sane (adjust the head ARKit index if off); the face mesh + `/pose/mouth` are gone (accepted). Report to the user; iterate the head index / 2D orientation if the position is mirrored/offset.

---

## Self-review

**Spec coverage:** skeleton2D wire tag+payload → Task 1; iPhone send → Task 2; Mac decode+state → Task 3; ARKit body build + cut MediaPipe + head map → Task 4; drop arkit_fuse → Task 5; deploy+iPhone-rebuild+smoke → Task 6. ✓

**Placeholder scan:** the Swift exact encoding + the `PoseKp`/`Kp3D` import paths + the head ARKit index are flagged "read the existing code / confirm live" rather than guessed — these are genuinely environment-specific and gated by the round-trip/builder tests + the live smoke, not inventable from here. All testable logic has concrete code.

**Type consistency:** `Skeleton2DPayload` (91×SIMD2 + valid) ↔ `decode_skeleton2D` (91×(x,y,valid)) ↔ `persons_arkit_2d` (91×2 ndarray) ↔ `arkit_body_2d` (33 PoseKp). `FrameTag.skeleton2D = 5` ↔ `TAG_SKELETON2D = 5`. `ARKIT91_TO_MP33` extended with head→0, consumed by both builders. The matrix's `/pose/*` emit is unchanged (it reads `bodies`/`bodies3d`, now ARKit-fed).

## Note for the controller (live-iteration items)

These can only be nailed on the rig (after the iPhone rebuild): the head ARKit
joint index, the 2D orientation/mirroring (the app's `projectPoint` already
handles interface orientation — reuse it), and whether the dropped `arkit_fuse`
+ ik filter still feels right. Expect 1-2 iPhone-rebuild iterations.
