# Body Mesh Pipeline — Performance Round 2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the remaining high-ROI optimizations from the 2026-05-13 critic review of the Body Mesh pipeline (O5 Swift memcpy bulk + O6 normals off-MainActor) and harden the TCP protocol with a 1-byte version field for forward compatibility. Plan 1 already shipped the highest-ROI item (O1 numpy serializer).

**Architecture:** Swift-only perf rework on the receiver side; one cross-process protocol change (Python sender + Swift receiver both touch the version byte). The Python sender's wire format gets a new 1-byte `version=1` after `MAGIC`; the Swift receiver tolerates it and rejects unknown versions. Mesh-normal compute moves from MainActor to a `Task.detached` block, with the result handed back to MainActor for the GPU upload.

**Tech Stack:** Swift 6 + RealityKit + Accelerate (vDSP for vector ops), Python 3.11+ numpy.

**Reference critic findings (verified 2026-05-13):**
- 🟠 O5 — `OSCServer.swift:98-113` decodes 10475 vertices via a per-vertex `load(fromByteOffset:)` loop. Gain: 2-5 ms → ~0.05 ms by replacing with a `memcpy` over the contiguous float32 vertex run.
- 🟠 O6 — `MeshRenderer.swift:153-183` recomputes vertex normals on the MainActor every frame even though topology is static. Gain: 3-8 ms of MainActor time freed.
- 🟡 Protocol gap — no version field; future incompat is silent. Cheap to fix while we're already touching both ends.

**Out of scope:**
- O8 (reduce inference resolution 896 → 512) — qualitative tradeoff, requires visual eval.
- CoreML conversion of Multi-HMR — 20-40h effort.
- Accelerate-vDSP SIMD of the actual cross-product loop (the off-MainActor move alone yields the budget gain; vDSP rewrite is a separate optimization).

---

### Task 1: Protocol — version byte (forward compat)

**Files:**
- Modify: `data_only_viz/smplx_osc_sender.py` (`_serialize_persons` — write version byte after MAGIC)
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift` (`decode` — read+validate version byte)

**Context:** Today the frame layout is `[u32 length][MAGIC "SMPX"][i32 n_persons][persons...]`. Insert a `u8 version=1` immediately after `MAGIC`. The Swift receiver rejects unknown versions with an error log and drops the frame.

Frame layout becomes:
```
[u32 length BE→LE][MAGIC "SMPX" 4B][u8 version=1][u8 reserved=0 ×3][i32 n_persons][persons...]
```

The 3 reserved bytes keep `n_persons` aligned to 4-byte boundary (good for any future `memcpy` decoder).

- [ ] **Step 1: Update Python sender**

In `smplx_osc_sender.py._serialize_persons`, find the line that writes `MAGIC + n_persons`. Replace with:

```python
PROTO_VERSION = 1

# In _serialize_persons:
header = MAGIC + bytes([PROTO_VERSION, 0, 0, 0]) + struct.pack("<i", n_persons)
```

(Adapt to actual constant names. Add `PROTO_VERSION = 1` near other module constants if not present.)

- [ ] **Step 2: Update existing serialize test (P3.T1)**

The test `test_serialize_person_layout` in `data_only_viz/tests/test_smplx_osc_sender_serialize.py` asserts offsets. Update the header math:

```python
# Old header: MAGIC(4) + n_persons(4) = 8 bytes
# New header: MAGIC(4) + version+reserved(4) + n_persons(4) = 12 bytes
base = 12  # was 8
per_person_offset = base + 4 + 4 + 12 + 40 + 40
```

Add a new assertion:
```python
version = struct.unpack_from("<B", payload, 4)[0]
assert version == 1
```

- [ ] **Step 3: Update Swift receiver**

In `OSCServer.swift::decode`, after verifying `MAGIC == "SMPX"` (around line 68-70), read the version:

```swift
let version: UInt8 = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt8.self) }
guard version == 1 else {
    NSLog("OSCServer: unsupported protocol version %d, dropping frame", version)
    return nil
}
// Skip 3 reserved bytes; nPersons now at offset 8
let nPersons: Int32 = payload.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) }
// Per-person data starts at offset 12 (was 8)
var offset = 12
```

Adjust the offset arithmetic for the per-person loop accordingly.

- [ ] **Step 4: Run tests + build**

```bash
cd /Users/electron/Documents/Projets/AV-Live && uv run --directory data_only_viz pytest tests/ -v 2>&1 | tail -10
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build -c release 2>&1 | tail -5
```

Expected: 25 passed + 1 pre-existing fail; Swift clean.

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/smplx_osc_sender.py data_only_viz/tests/test_smplx_osc_sender_serialize.py launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
git commit -m "feat(protocol): add SMPX version byte"
```

(40 chars — fits.)

---

### Task 2: Swift receiver — memcpy bulk decode (O5)

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift` (`decode` — per-vertex `load(fromByteOffset:)` loop replaced with bulk copy)

**Context:** Current decode loop iterates 10475 times, calling `load(fromByteOffset:)` 3× per vertex. Each `load` involves bounds checks and arithmetic. Replace with a single bulk read into a `[SIMD3<Float>]` of size 10475, OR keep as `Data.subdata(in:)` + `withUnsafeBytes` block copy if `SIMD3<Float>` proves awkward in Swift.

- [ ] **Step 1: Identify the current vertex-decode loop**

```bash
grep -n "fromByteOffset\|10475\|vertices\|N_VERTS" launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
```

Find the `for _ in 0..<N` loop that reads 3 floats per iteration.

- [ ] **Step 2: Replace with bulk read**

After the per-person header read, the vertex bytes are contiguous at a known offset. Read them as a single `[Float]` (10475 × 3 = 31425 floats) and reshape to vertex array:

```swift
let vertCount = 10475
let vertBytes = vertCount * 3 * 4  // 125700 bytes
let vertOffset = offset  // after header + betas + expression
let vertData = payload.subdata(in: vertOffset..<(vertOffset + vertBytes))

var vertices: [SIMD3<Float>] = Array(repeating: .zero, count: vertCount)
vertData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
    let src = raw.bindMemory(to: Float.self).baseAddress!
    vertices.withUnsafeMutableBytes { dst in
        memcpy(dst.baseAddress!, src, vertBytes)
    }
}
offset += vertBytes
```

(Adapt to the existing `SMPLXPersonData` constructor — the field is likely `vertices: [SIMD3<Float>]`.)

The `memcpy` is sound because `SIMD3<Float>` is layout-compatible with three contiguous `Float`s on Apple Silicon (both are 16-byte aligned but tightly packed when stored in a Swift Array).

**Important:** if `SIMD3<Float>` has padding (it MAY be 16-byte aligned, occupying 16 bytes per element instead of 12), the memcpy is WRONG. Verify with:

```swift
print("MemoryLayout<SIMD3<Float>>.stride =", MemoryLayout<SIMD3<Float>>.stride)
print("MemoryLayout<SIMD3<Float>>.size   =", MemoryLayout<SIMD3<Float>>.size)
```

If `stride > 12`, fallback to a `[Float]` of 31425 elements and do the SIMD3 reshape at the consumer (MeshRenderer). The plan's spec is "vertices are layout-compatible"; if reality differs, escalate `NEEDS_CONTEXT`.

- [ ] **Step 3: Build + run**

```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build -c release 2>&1 | tail -10
```

Expected: clean.

If you wrote a quick stride probe (Step 2 caveat), run the built binary briefly to confirm `stride == size == 12`. If not, escalate.

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
git commit -m "perf(av-live-body): memcpy bulk vertex decode"
```

(46 chars — fits.)

---

### Task 3: MeshRenderer — normals off MainActor (O6)

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`

**Context:** `computeVertexNormals` runs synchronously on MainActor as part of `updateMeshVertices`. Move it to a `Task.detached` (or a dedicated serial DispatchQueue) so it doesn't block the main thread. The result (`[SIMD3<Float>]` of length 10475) is handed back to MainActor for the GPU upload.

- [ ] **Step 1: Inspect current `updateMeshVertices` and `computeVertexNormals`**

```bash
grep -n "computeVertexNormals\|updateMeshVertices\|@MainActor\|withUnsafeMutableBytes" launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift
```

Identify:
- Whether `computeVertexNormals` is a free function, static, or instance method.
- Whether it captures `self` (must NOT, to be safely off-MainActor).
- The size of its input/output buffers.

- [ ] **Step 2: Refactor to make `computeVertexNormals` Sendable + actor-free**

If `computeVertexNormals` takes `(vertices: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>]` as input, it should already be pure. Mark it explicitly `static` or move to a free function (and verify it's `Sendable` by inspection — no global mutable state).

If it currently reads `self.indices` (the static face topology), pass `indices` as an explicit parameter.

- [ ] **Step 3: Dispatch off-MainActor in `updateMeshVertices`**

Rewrite `updateMeshVertices` (or whichever method drives the per-frame update):

```swift
@MainActor
func updateMeshVertices(_ persons: [SMPLXPersonData]) async {
    for person in persons {
        // Compute normals OFF main actor:
        let normals = await Task.detached(priority: .userInitiated) { [verts = person.vertices, idx = self.indices] in
            Self.computeVertexNormals(vertices: verts, indices: idx)
        }.value
        // Back on MainActor — upload to GPU:
        applyToGPU(person.pid, vertices: person.vertices, normals: normals)
    }
}
```

(The exact method names depend on what the file already has. Read first.)

`computeVertexNormals` becomes:

```swift
nonisolated static func computeVertexNormals(
    vertices: [SIMD3<Float>],
    indices: [UInt32]
) -> [SIMD3<Float>] {
    // ... existing body, no self access ...
}
```

If the caller was synchronous (`func updateMeshVertices(_:)` not `async`), make it async OR introduce a `Task { @MainActor in ... }` wrapper at the call site.

- [ ] **Step 4: Verify no MainActor stall in the new path**

The whole point is to keep `await Task.detached` from blocking. If the call site is `Task { @MainActor in renderer.updateMeshVertices(persons) }` (from `OSCServer.parseFrames`), the inner `await` correctly suspends the MainActor task while the detached task runs on a background thread. Good.

Confirm visually that the path is correct. If the existing code does an `async let` pattern or other concurrency primitive, adapt.

- [ ] **Step 5: Build + smoke check**

```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build -c release 2>&1 | tail -10
```

Expected: clean build.

If there are Swift 6 concurrency warnings about captures, the `[verts = person.vertices, idx = self.indices]` capture list is the fix.

- [ ] **Step 6: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift
git commit -m "perf(av-live-body): normals off MainActor"
```

(43 chars — fits.)

---

## Self-Review

**1. Spec coverage:** Task 1 = protocol version byte (forward compat + cheap because we're touching both ends). Task 2 = critic's O5 (Swift memcpy bulk). Task 3 = critic's O6 (normals off MainActor). All listed audit nits addressed; O8 / CoreML / vDSP rewrite explicitly out of scope.

**2. Placeholder scan:** No TBD / TODO / "fill in". Every step has runnable code or a clear escalation path. The SIMD3 stride caveat in Task 2 is real and gives the implementer concrete actions for both branches (`stride == 12` → memcpy; otherwise → escalate).

**3. Type consistency:** `PROTO_VERSION = 1` (uint8) consistent across Python sender and Swift receiver. `SMPLXPersonData.vertices` type is whatever the existing code uses ([SIMD3<Float>] expected); Task 3 doesn't change it. The header offsets in Task 1 update the P3.T1 test in lockstep.

---

## Execution Handoff

Plan complete and saved. Two execution options:
1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Same approach as Plans 1, 3, 2.
