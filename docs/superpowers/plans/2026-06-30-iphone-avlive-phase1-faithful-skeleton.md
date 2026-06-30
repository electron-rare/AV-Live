# Phase 1 — Faithful ARKit Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the real ARKit 91-joint body skeleton in `data_only_viz`, driven by a joint topology sent from the iPhone, instead of the degraded 14-segment MediaPipe-33 funnel.

**Architecture:** The iPhone already streams the full 91-joint 3D + 2D skeleton over AVLiveWire/USB. Phase 1 adds one new self-describing frame (`topology` = joint names + parent indices, sent once per connection), then reroutes the Metal renderer to draw all 91 joints from `state.persons_arkit_2d` + that topology — bypassing `arkit_joint_map.ARKIT91_TO_MP33`. The sound/matrix path (`multi.py` → `/pose/*` OSC) is untouched: it keeps using the MP33 reduction. The new renderer path is behind an env flag (`ARKIT_FULL_SKELETON`, default on) with fallback to the old MP33 rendering.

**Tech Stack:** Swift 5.10 (iPhone + `shared/AVLiveWire` SwiftPM package, XCTest), Python 3.11+ via `uv` (`data_only_viz`, pytest, pyobjc Metal), AVLiveWire framed TCP over usbmuxd.

## Global Constraints

- Python: use `uv` exclusively (never pip/poetry/conda). Run tests with `cd data_only_viz && uv run pytest tests/ -v`.
- Swift package tests: `cd shared/AVLiveWire && swift test --filter <TestClass>`.
- No emojis in code, docs, or commits.
- Commits: subject <= 50 chars, body <= 72 chars/line, no AI attribution, no `--no-verify`, no underscore in the commit scope (hooks enforce).
- This phase keeps AVLiveWire magic `AVL1` and the 19-byte header unchanged. `topology` is added as a new tag (7) on the existing v1 framing — non-breaking. The full v2 header (`AVL2`) is Phase 2, out of scope here.
- Do NOT modify the sound/matrix path. `multi.py` keeps calling `arkit_joint_map.arkit_body_2d/3d` to feed `state.persons_body` / `persons_body3d` for the `/pose/*` OSC sound bridge. Only the renderer changes.
- Shared state in `data_only_viz` is mutated only under `with state.lock():`.
- No `print` in the render loop — use the module logger.
- The iPhone must run in LANDSCAPE for ARKit body tracking (portrait spams `ABPKPersonIDTracker: Portrait image is not supported`).

---

### Task 1: AVLiveWire `topology` tag + `TopologyPayload`

**Files:**
- Modify: `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift:3-10`
- Modify: `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift` (append new struct)
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/TopologyPayloadTests.swift`

**Interfaces:**
- Consumes: `FrameTag`, `Data.appendBE`, `UInt16(bigEndianBytes:)` (existing in `FrameHeader.swift`).
- Produces:
  - `FrameTag.topology` (raw value `7`).
  - `TopologyPayload(jointNames: [String], parents: [Int16])` with `func encoded() -> Data` and `init?(decoding: Data)`.
  - Wire layout (big-endian): `u16 jointCount`, then per joint `u8 nameLen` + `nameLen` UTF-8 bytes, then per joint `i16 parent` (-1 = root).

- [ ] **Step 1: Write the failing test**

Create `shared/AVLiveWire/Tests/AVLiveWireTests/TopologyPayloadTests.swift`:

```swift
import XCTest
@testable import AVLiveWire

final class TopologyPayloadTests: XCTestCase {
    func testFrameTagTopology() {
        XCTAssertEqual(FrameTag.topology.rawValue, 7)
    }

    func testRoundTrip() {
        let names = ["root_joint", "hips_joint", "left_arm_joint"]
        let parents: [Int16] = [-1, 0, 1]
        let p = TopologyPayload(jointNames: names, parents: parents)
        let r = TopologyPayload(decoding: p.encoded())
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.jointNames, names)
        XCTAssertEqual(r!.parents, parents)
    }

    func testRejectsTruncated() {
        // Claims 3 joints but provides no body.
        let bytes: [UInt8] = [0x00, 0x03]
        XCTAssertNil(TopologyPayload(decoding: Data(bytes)))
    }

    func testEmpty() {
        let p = TopologyPayload(jointNames: [], parents: [])
        let r = TopologyPayload(decoding: p.encoded())
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.jointNames, [])
        XCTAssertEqual(r!.parents, [])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd shared/AVLiveWire && swift test --filter TopologyPayloadTests`
Expected: COMPILE FAILURE — `FrameTag.topology` and `TopologyPayload` are undefined.

- [ ] **Step 3: Add the `topology` tag**

In `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`, change the enum (lines 3-10):

```swift
public enum FrameTag: UInt8 {
    case skeleton = 1
    case video = 2
    case meta = 3
    case hands = 4
    case face = 5
    case skeleton2D = 6
    case topology = 7
}
```

- [ ] **Step 4: Add `TopologyPayload`**

Append to `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift`:

```swift
/// Self-describing skeleton topology: joint names + parent indices.
/// Sent once per connection so consumers draw bones generically
/// (parent -> child) with no hardcoded joint mapping.
/// Layout (big-endian): u16 jointCount; per joint [u8 nameLen + utf8];
/// then per joint i16 parent (-1 = root).
public struct TopologyPayload: Equatable {
    public var jointNames: [String]
    public var parents: [Int16]
    public init(jointNames: [String], parents: [Int16]) {
        self.jointNames = jointNames
        self.parents = parents
    }

    public func encoded() -> Data {
        var d = Data()
        d.appendBE(UInt16(min(jointNames.count, 65535)))
        for name in jointNames {
            let bytes = Array(name.utf8.prefix(255))
            d.append(UInt8(bytes.count))
            d.append(contentsOf: bytes)
        }
        for p in parents { d.appendBE(UInt16(bitPattern: p)) }
        return d
    }

    public init?(decoding data: Data) {
        let b = [UInt8](data)
        guard b.count >= 2 else { return nil }
        let n = Int(UInt16(bigEndianBytes: b[0..<2]))
        var o = 2
        var names: [String] = []
        for _ in 0..<n {
            guard o < b.count else { return nil }
            let len = Int(b[o]); o += 1
            guard o + len <= b.count else { return nil }
            names.append(String(decoding: b[o..<o+len], as: UTF8.self))
            o += len
        }
        guard o + n * 2 <= b.count else { return nil }
        var ps: [Int16] = []
        for _ in 0..<n {
            ps.append(Int16(bitPattern: UInt16(bigEndianBytes: b[o..<o+2])))
            o += 2
        }
        jointNames = names
        parents = ps
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd shared/AVLiveWire && swift test --filter TopologyPayloadTests`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift \
        shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift \
        shared/AVLiveWire/Tests/AVLiveWireTests/TopologyPayloadTests.swift
git commit -m "feat(wire): topology payload + tag"
```

---

### Task 2: iPhone emits topology once on connect

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` (init closure ~lines 66-81, add `publishTopology()` near `publishUSB()` ~line 299)

**Interfaces:**
- Consumes: `ARSkeletonDefinition.defaultBody3D.jointNames` (`[String]`), `bodyParents` (`[Int]`, existing member), `usb.send(tag:pid:timestamp:payload:)`, `TopologyPayload` (Task 1).
- Produces: a `.topology` frame (`pid: -1`) sent on each transition into `.connected`.

This task is device/integration wiring; the encodable unit (`TopologyPayload`) is already tested in Task 1. Verification here is a successful build plus the on-device receive check in Task 7.

- [ ] **Step 1: Track the previous USB state and emit on transition**

In `ARBodySession.swift`, the `init()` closure currently is:

```swift
        usb.onState = { [weak self] s in
            Task { @MainActor in self?.usbState = s }
        }
```

Replace it with:

```swift
        usb.onState = { [weak self] s in
            Task { @MainActor in
                guard let self else { return }
                let was = self.usbState
                self.usbState = s
                if s == .connected && was != .connected {
                    self.publishTopology()
                }
            }
        }
```

- [ ] **Step 2: Add `publishTopology()`**

Add this method next to `publishUSB(...)` (after it, around line 339):

```swift
    /// Send the ARKit body joint names + parent indices once, so the Mac
    /// renders bones generically. Static data — available before any body
    /// is tracked, so it is safe to emit right after connect.
    @MainActor
    private func publishTopology() {
        guard usbState == .connected else { return }
        let def = ARSkeletonDefinition.defaultBody3D
        let names = def.jointNames
        let parents = def.parentIndices.map { Int16(clamping: $0) }
        let payload = TopologyPayload(jointNames: names, parents: parents)
        usb.send(tag: .topology, pid: -1,
                 timestamp: lastFrameTime,
                 payload: payload.encoded())
    }
```

- [ ] **Step 3: Build the app to verify it compiles**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live/iphone-arbody && \
xcodegen generate && \
xcodebuild -project ARBodyTracker.xcodeproj -scheme ARBodyTracker \
  -configuration Debug -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` (the `nonisolated(unsafe)` Vision warning may remain; no new errors).

- [ ] **Step 4: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift
git commit -m "feat(iphone): emit skeleton topology on connect"
```

---

### Task 3: Python `decode_topology` + `encode_topology`

**Files:**
- Create: `data_only_viz/arkit_topology.py`
- Test: `data_only_viz/tests/test_arkit_topology.py`

**Interfaces:**
- Produces:
  - `decode_topology(payload: bytes) -> tuple[list[str], list[int]] | None` — mirror of the Swift `TopologyPayload` layout.
  - `encode_topology(names: list[str], parents: list[int]) -> bytes` — used by tests and downstream consumers.
- Consumes: nothing (pure stdlib `struct`).

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_arkit_topology.py`:

```python
"""AVLiveWire topology payload round-trip (mirror of Swift TopologyPayload)."""
from data_only_viz.arkit_topology import decode_topology, encode_topology


def test_round_trip():
    names = ["root_joint", "hips_joint", "left_arm_joint"]
    parents = [-1, 0, 1]
    payload = encode_topology(names, parents)
    out = decode_topology(payload)
    assert out is not None
    got_names, got_parents = out
    assert got_names == names
    assert got_parents == parents


def test_empty():
    payload = encode_topology([], [])
    out = decode_topology(payload)
    assert out == ([], [])


def test_rejects_truncated():
    # Claims 3 joints, provides no body.
    assert decode_topology(b"\x00\x03") is None


def test_rejects_too_short():
    assert decode_topology(b"\x00") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_topology.py -v`
Expected: FAIL — `ModuleNotFoundError: data_only_viz.arkit_topology`.

- [ ] **Step 3: Write the implementation**

Create `data_only_viz/arkit_topology.py`:

```python
"""AVLiveWire topology payload codec.

Mirror of the Swift `TopologyPayload` (shared/AVLiveWire). Layout
(big-endian): u16 jointCount; per joint [u8 nameLen + utf8 name];
then per joint i16 parent (-1 = root).
"""
from __future__ import annotations

import struct


def encode_topology(names: list[str], parents: list[int]) -> bytes:
    out = bytearray()
    out += struct.pack(">H", len(names))
    for nm in names:
        b = nm.encode("utf-8")[:255]
        out.append(len(b))
        out += b
    for p in parents:
        out += struct.pack(">h", p)
    return bytes(out)


def decode_topology(payload: bytes):
    """Return (joint_names, parents) or None if malformed."""
    if len(payload) < 2:
        return None
    n = struct.unpack(">H", payload[:2])[0]
    o = 2
    names: list[str] = []
    for _ in range(n):
        if o >= len(payload):
            return None
        ln = payload[o]
        o += 1
        if o + ln > len(payload):
            return None
        names.append(payload[o:o + ln].decode("utf-8", "replace"))
        o += ln
    if o + n * 2 > len(payload):
        return None
    parents = list(struct.unpack(">" + "h" * n, payload[o:o + n * 2]))
    return names, parents
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_topology.py -v`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/arkit_topology.py data_only_viz/tests/test_arkit_topology.py
git commit -m "feat(presets): python topology codec"
```

Note: scope `presets` avoids an underscore-bearing scope; `data_only_viz` would need a no-underscore alias. Use `iphone` if the hooks reject `presets` here:
`git commit -m "feat(iphone): python topology codec"`.

---

### Task 4: Store topology + 2D validity in shared state

**Files:**
- Modify: `data_only_viz/state.py` (add fields near `persons_arkit_2d`, ~lines 149-150)
- Modify: `data_only_viz/iphone_usb_source.py` (constants ~lines 26-31; tag dispatch ~lines 152-169)
- Test: `data_only_viz/tests/test_arkit_topology_state.py`

**Interfaces:**
- Consumes: `decode_topology` (Task 3), `decode_skeleton2D` (existing import), `state.lock()`.
- Produces, on the shared `State`:
  - `arkit_joint_names: list[str]`
  - `arkit_parents: list[int]`
  - `persons_arkit_2d_valid: dict[int, np.ndarray]` (bool array, shape `(91,)`)
  - module constant `TAG_TOPOLOGY = 7` in `iphone_usb_source.py`.

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_arkit_topology_state.py`:

```python
"""State carries ARKit topology + 2D validity for the renderer."""
from data_only_viz.state import State


def test_state_has_topology_fields():
    s = State()
    assert s.arkit_joint_names == []
    assert s.arkit_parents == []
    assert s.persons_arkit_2d_valid == {}


def test_topology_tag_constant():
    from data_only_viz.iphone_usb_source import TAG_TOPOLOGY
    assert TAG_TOPOLOGY == 7
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_topology_state.py -v`
Expected: FAIL — `AttributeError` on `arkit_joint_names` / `ImportError` on `TAG_TOPOLOGY`.

- [ ] **Step 3: Add the state fields**

In `data_only_viz/state.py`, next to the existing `persons_arkit_2d` fields:

```python
    persons_arkit_2d: dict[int, "np.ndarray"] = field(default_factory=dict)
    persons_arkit_2d_t: dict[int, float] = field(default_factory=dict)
    persons_arkit_2d_valid: dict = field(default_factory=dict)
    arkit_joint_names: list = field(default_factory=list)
    arkit_parents: list = field(default_factory=list)
```

(The first two lines already exist — add the three new ones beneath them.)

- [ ] **Step 4: Wire the source — constant, import, 2D validity, topology dispatch**

In `data_only_viz/iphone_usb_source.py`, add the tag constant near the other `TAG_*`/`_ARKIT_JOINTS` constants (~lines 26-31):

```python
TAG_TOPOLOGY = 7
```

Add the import near the existing decode imports (top of file, where `decode_skeleton`/`decode_skeleton2D` are imported):

```python
from .arkit_topology import decode_topology
```

Replace the `TAG_SKELETON2D` branch (currently stores only points) with one that also stores validity:

```python
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
```

Add a new branch handling the topology tag (place it right after the `TAG_SKELETON2D` branch):

```python
                    elif tag == TAG_TOPOLOGY and self.state is not None:
                        topo = decode_topology(payload)
                        if topo is not None:
                            names, parents = topo
                            with self.state.lock():
                                self.state.arkit_joint_names = names
                                self.state.arkit_parents = parents
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_topology_state.py -v`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add data_only_viz/state.py data_only_viz/iphone_usb_source.py \
        data_only_viz/tests/test_arkit_topology_state.py
git commit -m "feat(iphone): store topology + 2d validity"
```

---

### Task 5: Pure ARKit skeleton segment builder

**Files:**
- Create: `data_only_viz/arkit_skeleton.py`
- Test: `data_only_viz/tests/test_arkit_skeleton.py`

**Interfaces:**
- Produces:
  - `bones_from_parents(parents: list[int]) -> list[tuple[int, int]]` — `(child, parent)` pairs where parent is a valid index.
  - `arkit_segments(arr2d, valid, parents) -> list[tuple[float, float, float, float]]` — `(ax, ay, bx, by)` per drawable bone, in normalized `[0,1]` image coords; skips bones whose either endpoint is invalid.
- Consumes: nothing (pure; `arr2d` is any `(N,2)` indexable, `valid` is `(N,)` or `None`).

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_arkit_skeleton.py`:

```python
"""Pure ARKit skeleton -> line segment builder."""
from data_only_viz.arkit_skeleton import arkit_segments, bones_from_parents


def test_bones_skip_root():
    parents = [-1, 0, 1]
    assert bones_from_parents(parents) == [(1, 0), (2, 1)]


def test_bones_skip_out_of_range():
    parents = [-1, 0, 99]  # 99 has no joint
    assert bones_from_parents(parents) == [(1, 0)]


def test_segments_basic():
    arr2d = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
    valid = [True, True, True]
    parents = [-1, 0, 1]
    segs = arkit_segments(arr2d, valid, parents)
    assert segs == [(0.5, 0.5, 0.0, 0.0), (1.0, 1.0, 0.5, 0.5)]


def test_segments_drop_invalid_endpoint():
    arr2d = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
    valid = [True, False, True]  # joint 1 invalid
    parents = [-1, 0, 1]
    # bone (1,0) drops (1 invalid); bone (2,1) drops (1 invalid)
    assert arkit_segments(arr2d, valid, parents) == []


def test_segments_valid_none_keeps_all():
    arr2d = [(0.0, 0.0), (0.5, 0.5)]
    parents = [-1, 0]
    assert arkit_segments(arr2d, None, parents) == [(0.5, 0.5, 0.0, 0.0)]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_skeleton.py -v`
Expected: FAIL — `ModuleNotFoundError: data_only_viz.arkit_skeleton`.

- [ ] **Step 3: Write the implementation**

Create `data_only_viz/arkit_skeleton.py`:

```python
"""Build line segments from a full ARKit skeleton + parent topology.

Pure functions, no Metal/state dependency, so they are unit-testable.
The renderer feeds the resulting (ax, ay, bx, by) tuples straight into
the GPU line buffer.
"""
from __future__ import annotations


def bones_from_parents(parents: list[int]) -> list[tuple[int, int]]:
    """(child, parent) pairs for every joint with a valid parent."""
    n = len(parents)
    return [(i, p) for i, p in enumerate(parents) if 0 <= p < n]


def arkit_segments(arr2d, valid, parents):
    """Return (ax, ay, bx, by) for each bone with both endpoints valid.

    arr2d: indexable of (x, y) normalized [0,1], length == len(parents).
    valid: indexable of bool (length == len(parents)) or None to keep all.
    parents: parent index per joint (-1 = root).
    """
    n = len(parents)
    segs: list[tuple[float, float, float, float]] = []
    for child, parent in bones_from_parents(parents):
        if child >= n or parent >= n:
            continue
        if valid is not None and (not valid[child] or not valid[parent]):
            continue
        ax, ay = float(arr2d[child][0]), float(arr2d[child][1])
        bx, by = float(arr2d[parent][0]), float(arr2d[parent][1])
        segs.append((ax, ay, bx, by))
    return segs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd data_only_viz && uv run pytest tests/test_arkit_skeleton.py -v`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/arkit_skeleton.py data_only_viz/tests/test_arkit_skeleton.py
git commit -m "feat(iphone): arkit skeleton segment builder"
```

---

### Task 6: Renderer draws the full 91-joint body

**Files:**
- Modify: `data_only_viz/renderer.py` (module-level flag near the top imports; `_update_skeleton` ~lines 311-396)

**Interfaces:**
- Consumes: `arkit_segments` (Task 5); `state.arkit_parents`, `state.persons_arkit_2d`, `state.persons_arkit_2d_valid` (Task 4); existing `self._skel_cpu_buf`, `SKEL_MAX_SEGS`.
- Produces: when `ARKIT_FULL_SKELETON` is on and topology+2D are present, the skeleton line buffer is filled from all 91 ARKit joints instead of the MP33 body; hands and face keep their existing rendering. Falls back to the MP33 body loop otherwise.

This task wires the (already unit-tested) segment builder into the Metal renderer. Metal cannot run headless, so the deliverable is verified on device in Task 7 via the `render: N segs` log (it jumps from ~14 to ~90) and the flag-off fallback.

- [ ] **Step 1: Add the env flag**

At the top of `data_only_viz/renderer.py`, near the other imports/module constants, add:

```python
import os
from .arkit_skeleton import arkit_segments

# Draw the full ARKit 91-joint body (topology-driven) instead of the
# MP33-reduced body. Set ARKIT_FULL_SKELETON=0 to fall back to MP33.
ARKIT_FULL = os.environ.get("ARKIT_FULL_SKELETON", "1") != "0"
```

(If `import os` already exists at the top, do not duplicate it.)

- [ ] **Step 2: Compute the ARKit mode and guard early-return**

In `_update_skeleton`, replace the opening guard:

```python
        if not s.pose_alive():
            return 0

        buf = self._skel_cpu_buf
        segs = 0
```

with:

```python
        use_arkit = (ARKIT_FULL and bool(s.arkit_parents)
                     and bool(s.persons_arkit_2d))
        if not use_arkit and not s.pose_alive():
            return 0

        buf = self._skel_cpu_buf
        segs = 0
```

- [ ] **Step 3: Add a float-segment push helper + draw the ARKit body**

Immediately after the existing `push(A, B, conf, pid)` closure definition (it ends with `return True`), add the float-based helper and the ARKit draw loop:

```python
        def push_seg(ax, ay, bx, by, conf, pid):
            """Like push() but takes raw normalized [0,1] coords."""
            nonlocal segs
            if segs >= SKEL_MAX_SEGS:
                return False
            cax = ax * 2.0 - 1.0; cay = 1.0 - ay * 2.0
            cbx = bx * 2.0 - 1.0; cby = 1.0 - by * 2.0
            i = segs * 10
            buf[i+0] = cax; buf[i+1] = cay; buf[i+2] = 0.0
            buf[i+3] = conf; buf[i+4] = float(pid)
            buf[i+5] = cbx; buf[i+6] = cby; buf[i+7] = 0.0
            buf[i+8] = conf; buf[i+9] = float(pid)
            segs += 1
            return True

        if use_arkit:
            parents = s.arkit_parents
            for pid, arr2d in s.persons_arkit_2d.items():
                valid = s.persons_arkit_2d_valid.get(pid)
                for (ax, ay, bx, by) in arkit_segments(arr2d, valid, parents):
                    if not push_seg(ax, ay, bx, by, 1.0, pid):
                        break
```

- [ ] **Step 4: Skip the MP33 body loop when in ARKit mode**

In the MediaPipe block, the body loop currently starts:

```python
            for i, body_kp in enumerate(s.persons_body):
```

Change it to skip the MP33 body when ARKit drew it (face and hand loops below are unchanged):

```python
            for i, body_kp in enumerate([] if use_arkit else s.persons_body):
```

Apply the same `[] if use_arkit else ...` guard to the single-person fallback body block (`if s.body_present:`) so it does not double-draw:

```python
            if not (s.persons_body or s.persons_face or s.persons_hands):
                if s.body_present and not use_arkit:
```

- [ ] **Step 5: Syntax check (no Metal device needed)**

Run: `cd data_only_viz && uv run python -c "import ast; ast.parse(open('renderer.py').read()); print('ok')"`
Expected: `ok`.

- [ ] **Step 6: Run the full data_only_viz test suite (no regressions)**

Run: `cd data_only_viz && uv run pytest tests/ -v`
Expected: PASS (existing suite stays green; the new topology/skeleton tests pass).

- [ ] **Step 7: Commit**

```bash
git add data_only_viz/renderer.py
git commit -m "feat(iphone): render full arkit body skeleton"
```

---

### Task 7: End-to-end verification on device

**Files:** none (verification + reversibility check).

**Interfaces:**
- Consumes: the full stack (iPhone app rebuilt with Tasks 1-2, `data_only_viz` with Tasks 3-6).

This task confirms the visible win and the flag fallback. No code change — if a check fails, the failing task is reopened.

- [ ] **Step 1: Rebuild + run the iPhone app**

In Xcode (iPhone connected, LANDSCAPE), select `GSM de clemsail` and Run (Cmd-R). Confirm the app connects (USB state -> connected).

- [ ] **Step 2: Launch the AV-Live stack**

Run: `open "$HOME/Desktop/AV-Live Concert.app"` and wait ~60 s for boot.

- [ ] **Step 3: Confirm the full skeleton renders**

Run: `grep -E "render: .* segs" /tmp/concert_viz.log | tail -3`
Expected: the segment count is now ~80-90 (e.g. `render: 88 segs ... body=1`), up from the previous `14 segs`. A person in frame shows a full body skeleton (spine, neck, head, limbs) instead of a 14-segment stick figure.

- [ ] **Step 4: Confirm the topology arrived**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live/data_only_viz && \
uv run python -c "print('topology decode wired; see /tmp/concert_viz.log for segs')"
```
And confirm in `/tmp/concert_viz.log` there are no `decode_topology` errors and segments are present.

- [ ] **Step 5: Verify the fallback flag**

Stop the stack, then run the viz alone with the flag off:
```bash
pkill -9 -f data_only_viz.main 2>/dev/null
cd /Users/electron/Documents/Projets/AV-Live && \
ARKIT_FULL_SKELETON=0 data_only_viz/.venv/bin/python -m data_only_viz.main \
  --pose --iphone-usb > /tmp/viz_fallback.log 2>&1 &
sleep 12 && grep -E "render: .* segs" /tmp/viz_fallback.log | tail -2
```
Expected: segment count drops back to ~14 (MP33 fallback), proving reversibility. Then kill it: `pkill -9 -f data_only_viz.main`.

- [ ] **Step 6: Confirm the sound/matrix path is unaffected**

Run: `grep -E "/pose/|body3d" /tmp/concert_viz.log | tail -5`
Expected: `/pose/*` OSC + `body3d: n=1` still emitted (the MP33 reduction in `multi.py` is untouched), so matrix modulation still works.

---

## Self-Review

**Spec coverage (Phase 1 rows of the spec):**
- "iPhone emits topology" -> Tasks 1-2. Covered.
- "data_only_viz new renderer on the 91 decoded joints + hands, topology-driven" -> Tasks 4-6 (body 91-joint; hands keep existing path). Covered.
- "bypass MP33 funnel for the iPhone path" -> Task 6 (`use_arkit` skips the MP33 body loop). Covered.
- "flag, MP33 fallback" -> `ARKIT_FULL_SKELETON` (Task 6) + verified in Task 7 Step 5. Covered.
- "sound/matrix path untouched" -> Global Constraints + Task 7 Step 6. Covered.

**Placeholder scan:** No TBD/TODO; every code step shows full code; every command has expected output.

**Type consistency:** `TopologyPayload(jointNames:parents:)` (Swift, Task 1) mirrored by `encode_topology(names, parents)` / `decode_topology -> (names, parents)` (Python, Task 3). `arkit_segments(arr2d, valid, parents)` defined in Task 5, consumed identically in Task 6. State fields `arkit_parents`, `persons_arkit_2d`, `persons_arkit_2d_valid` defined in Task 4, consumed in Task 6. `TAG_TOPOLOGY = 7` matches `FrameTag.topology = 7`.

**Out-of-scope note (intentional):** hand 3D lifting, unified pose frame, Swift 6.2 actor refactor, AVL2 header, and removing `arkit_joint_map.py` are later phases (2-6), each with its own plan.
