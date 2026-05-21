# macOS USB Consumer Implementation Plan (Plan 3a of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the macOS `AVLiveBody` app consume the iPhone's USB stream — connect via `usbmuxd`, demux `AVLiveWire` frames, render the 91-joint skeleton on screen, and HEVC-decode the video — without the Multi-HMR dense-mesh step (deferred to Plan 3b).

**Architecture:** A new `USBSkeletonConsumer` runs the blocking `UnixMuxTransport`/`USBClient` read loop on a dedicated background thread, feeds bytes through `StreamDemuxer`, and republishes `.skeleton` frames as `@Published` ARKit-shaped body frames plus a `.video` callback. `Skeleton3DRenderer`'s long-standing `// TODO: render yellow ARKit markers` (line 138) is completed so the 91-joint USB skeleton actually draws. A new `VideoDecoder` turns `.video` `VideoPayload`s into `CVPixelBuffer`s via `VTDecompressionSession`.

**Tech Stack:** Swift 5 (language mode v5), macOS 15, RealityKit, VideoToolbox, `AVLiveWire` (already a dependency of `AV-Live-Body`), `XCTest`.

**Companion spec:** `docs/superpowers/specs/2026-05-18-iphone-usb-body-link-design.md`
**Prerequisites:** Plan 1 (transport, merged), Plan 2 (iOS capture, merged).
**Out of scope:** `MultiHMRCoreML`, `BodyFusion`, dense-mesh rendering — Plan 3b, gated on a confirmed CoreML Multi-HMR `.mlpackage`.

---

## Verification

`AV-Live-Body` is a macOS target — it builds on the host:

```bash
cd launcher/AV-Live-Body && swift build
cd launcher/AV-Live-Body && swift test
```

Each task ends with `swift build` (and `swift test` where a test was
added) succeeding.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift` | NEW. Background USB read loop → `StreamDemuxer` → `@Published` body frames + video callback |
| `launcher/AV-Live-Body/Sources/AVLiveBody/VideoDecoder.swift` | NEW. `VTDecompressionSession` HEVC decode: `VideoPayload` → `CVPixelBuffer` |
| `launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBSkeletonConsumerTests.swift` | NEW. Unit test for the `SkeletonPayload` → `ArkitBodyFrame` mapping |
| `launcher/AV-Live-Body/Sources/AVLiveBody/Skeleton3DRenderer.swift` | MODIFY. Complete the line-138 TODO: draw 91 USB-skeleton joint markers |
| `launcher/AV-Live-Body/Sources/AVLiveBody/ArkitOSCListener.swift` | REFERENCE only — reuse its nested `ArkitBodyFrame` type |
| `launcher/AV-Live-Body/Sources/AVLiveBody/AVLiveBodyApp.swift` | MODIFY. Own a `USBSkeletonConsumer`, start it in `.onAppear` |
| `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift` | MODIFY. Thread the consumer into `Skeleton3DRenderer.attach` |

---

## Task 1: USBSkeletonConsumer

`USBSkeletonConsumer` owns the blocking USB read loop on a background
`Thread`. It reconnects on drop. It republishes `.skeleton` frames as
`ArkitOSCListener.ArkitBodyFrame` (the existing 91-joint body type, so
`Skeleton3DRenderer` can consume them with no new type) and forwards
`.video` payloads via a callback. It is **not** `@MainActor`: the loop
runs off-main and hops to main only for `@Published` writes — the same
pattern as `ArkitOSCListener`.

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift`
- Test: `launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBSkeletonConsumerTests.swift`

- [ ] **Step 1: Write the failing test**

`launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBSkeletonConsumerTests.swift`:

```swift
import XCTest
import AVLiveWire
@testable import AVLiveBody

final class USBSkeletonConsumerTests: XCTestCase {
    func testSkeletonPayloadMapsToBodyFrame() {
        var p = SkeletonPayload()
        p.joints[0] = SIMD3(1, 2, 3)
        p.valid[0] = true
        p.joints[90] = SIMD3(-4, 5, -6)
        p.valid[90] = true
        let frame = USBSkeletonConsumer.bodyFrame(pid: 7, from: p)
        XCTAssertEqual(frame.pid, 7)
        XCTAssertEqual(frame.joints.count, 91)
        XCTAssertEqual(frame.hasJoint.count, 91)
        XCTAssertEqual(frame.joints[0], SIMD3(1, 2, 3))
        XCTAssertTrue(frame.hasJoint[0])
        XCTAssertEqual(frame.joints[90], SIMD3(-4, 5, -6))
        XCTAssertFalse(frame.hasJoint[1])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd launcher/AV-Live-Body && swift test --filter USBSkeletonConsumerTests`
Expected: FAIL — `USBSkeletonConsumer` undefined.

- [ ] **Step 3: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift`:

```swift
import AVLiveWire
import Combine
import Foundation

/// Connects to the tethered iPhone over USB (usbmuxd), demuxes the
/// AVLiveWire stream, and republishes skeleton frames (as the existing
/// 91-joint `ArkitOSCListener.ArkitBodyFrame`) plus video payloads.
/// The blocking transport runs on a dedicated background thread; only
/// `@Published` writes hop to the main queue.
final class USBSkeletonConsumer: ObservableObject {
    /// 91-joint body frames keyed by pid — same shape `Skeleton3DRenderer`
    /// already consumes from `ArkitOSCListener`.
    @Published var bodies: [Int: ArkitOSCListener.ArkitBodyFrame] = [:]
    @Published var connected = false

    /// Called (on the main queue) for every decoded `.video` frame.
    var onVideo: ((VideoPayload) -> Void)?

    /// TCP port the iPhone `USBServer` listens on (must match the iOS
    /// app's `USBServer.port`).
    static let devicePort: UInt16 = 7000

    private let stateLock = NSLock()
    private var running = false
    private var thread: Thread?

    private var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    func start() {
        stateLock.lock()
        if running { stateLock.unlock(); return }
        running = true
        stateLock.unlock()
        let t = Thread { [weak self] in self?.loop() }
        t.name = "cc.avlive.usbconsumer"
        t.start()
        thread = t
    }

    func stop() {
        stateLock.lock(); running = false; stateLock.unlock()
    }

    /// Pure mapping `SkeletonPayload` -> `ArkitBodyFrame`. Static so it
    /// is unit-testable without a transport.
    static func bodyFrame(pid: Int, from p: SkeletonPayload)
        -> ArkitOSCListener.ArkitBodyFrame {
        var f = ArkitOSCListener.ArkitBodyFrame()
        f.pid = pid
        f.joints = p.joints
        f.hasJoint = p.valid
        f.seenAt = CFAbsoluteTimeGetCurrent()
        return f
    }

    // MARK: - Background read loop

    private func loop() {
        while isRunning {
            guard let transport = UnixMuxTransport() else {
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            let client = USBClient(transport: transport)
            guard let dev = client.listDevices().first,
                  client.connect(deviceID: dev,
                                 port: Self.devicePort) else {
                transport.close()
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            publishConnected(true)
            var demux = StreamDemuxer()
            while isRunning {
                guard let chunk = transport.readStream(),
                      !chunk.isEmpty else { break }
                for frame in demux.feed(chunk) { route(frame) }
            }
            transport.close()
            publishConnected(false)
            if isRunning { Thread.sleep(forTimeInterval: 1.0) }
        }
    }

    private func route(_ frame: StreamDemuxer.Frame) {
        switch frame.header.tag {
        case .skeleton:
            guard let payload =
                SkeletonPayload(decoding: frame.payload) else { return }
            let pid = Int(frame.header.pid)
            let body = Self.bodyFrame(pid: pid, from: payload)
            DispatchQueue.main.async { [weak self] in
                self?.bodies[pid] = body
            }
        case .video:
            guard let payload =
                VideoPayload(decoding: frame.payload) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onVideo?(payload)
            }
        case .meta:
            break
        }
    }

    private func publishConnected(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.connected = value
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd launcher/AV-Live-Body && swift test --filter USBSkeletonConsumerTests`
Expected: PASS, 1 test.

If `ArkitOSCListener.ArkitBodyFrame` has no memberwise mutability or a
different field set than `pid`/`joints`/`hasJoint`/`seenAt`, read
`ArkitOSCListener.swift` and adjust `bodyFrame` to match the actual
struct (it is a `struct ArkitBodyFrame: Equatable` with `var pid`,
`var joints: [SIMD3<Float>]`, `var hasJoint: [Bool]`, `var seenAt`).

- [ ] **Step 5: Run the full suite + commit**

Run: `cd launcher/AV-Live-Body && swift test`
Expected: PASS, all tests (7: prior 6 + this 1).

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBSkeletonConsumerTests.swift
git commit -m "feat(av-live-body): USB skeleton consumer"
```

(subject ≤50 chars; add a short body — the hook rejects subject-only.)

---

## Task 2: VideoDecoder

`VideoDecoder` turns `.video` `VideoPayload`s into `CVPixelBuffer`s. A
keyframe payload carries the HEVC parameter sets prepended (each as a
4-byte big-endian length prefix + NAL bytes — the format Plan 2's iOS
`VideoEncoder` produces); the decoder builds its
`CMVideoFormatDescription` from those, then decodes subsequent access
units.

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/VideoDecoder.swift`

- [ ] **Step 1: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/VideoDecoder.swift`:

```swift
import AVLiveWire
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// HEVC decoder. Feed `VideoPayload`s in; receive `CVPixelBuffer`s via
/// `onFrame`. Keyframe payloads must carry the VPS/SPS/PPS parameter
/// sets prepended as 4-byte-length-prefixed NAL units (the layout the
/// iOS `VideoEncoder` emits); the decoder (re)builds its format
/// description from those.
final class VideoDecoder {
    var onFrame: ((CVPixelBuffer) -> Void)?

    private var session: VTDecompressionSession?
    private var formatDesc: CMVideoFormatDescription?

    /// Decode one access unit.
    func decode(_ payload: VideoPayload) {
        var au = payload.data
        if payload.isKeyframe {
            // Split the prepended parameter sets from the frame data.
            let (params, rest) = Self.splitParameterSets(au)
            if !params.isEmpty {
                rebuildFormat(params)
            }
            au = rest
        }
        guard let fmt = formatDesc, !au.isEmpty else { return }
        if session == nil { makeSession(fmt) }
        guard let session else { return }
        guard let block = Self.blockBuffer(au) else { return }
        var sample: CMSampleBuffer?
        var sampleSize = au.count
        guard CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block,
            formatDescription: fmt, sampleCount: 1, sampleTimingEntryCount: 0,
            sampleTimingArray: nil, sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sample) == noErr, let sample else { return }
        VTDecompressionSessionDecodeFrame(
            session, sampleBuffer: sample, flags: [],
            infoFlagsOut: nil) { [weak self] status, _, image, _, _ in
                guard status == noErr, let image else { return }
                self?.onFrame?(image)
            }
    }

    func stop() {
        if let session { VTDecompressionSessionInvalidate(session) }
        session = nil
        formatDesc = nil
    }

    deinit { stop() }

    // MARK: - Helpers

    /// Parameter sets are 4-byte-length-prefixed NAL units at the head
    /// of a keyframe payload. The first NAL whose type is a VCL slice
    /// marks the start of frame data — but to stay simple and robust,
    /// we treat every leading NAL as a parameter set until the running
    /// concatenation can build a valid HEVC format description; the
    /// remainder is the frame. Returns (parameterSetData, frameData).
    private static func splitParameterSets(_ data: Data)
        -> (Data, Data) {
        // Parameter set NALs for HEVC: VPS=32, SPS=33, PPS=34
        // (nal_unit_type = (firstByte >> 1) & 0x3F).
        var offset = 0
        let bytes = [UInt8](data)
        var paramEnd = 0
        while offset + 4 <= bytes.count {
            let len = (Int(bytes[offset]) << 24)
                | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8)
                | Int(bytes[offset + 3])
            let nalStart = offset + 4
            guard len > 0, nalStart + len <= bytes.count else { break }
            let nalType = (Int(bytes[nalStart]) >> 1) & 0x3F
            if nalType == 32 || nalType == 33 || nalType == 34 {
                offset = nalStart + len
                paramEnd = offset
            } else {
                break
            }
        }
        return (data.prefix(paramEnd),
                data.suffix(from: data.startIndex
                    .advanced(by: paramEnd)))
    }

    private func rebuildFormat(_ paramData: Data) {
        var sets: [[UInt8]] = []
        let bytes = [UInt8](paramData)
        var offset = 0
        while offset + 4 <= bytes.count {
            let len = (Int(bytes[offset]) << 24)
                | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8)
                | Int(bytes[offset + 3])
            let start = offset + 4
            guard len > 0, start + len <= bytes.count else { break }
            sets.append(Array(bytes[start..<start + len]))
            offset = start + len
        }
        guard sets.count >= 3 else { return }
        let pointers = sets.map { UnsafePointer<UInt8>($0) }
        let sizes = sets.map { $0.count }
        var fmt: CMFormatDescription?
        let status = pointers.withUnsafeBufferPointer { pBuf in
            sizes.withUnsafeBufferPointer { sBuf in
                CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: sets.count,
                    parameterSetPointers: pBuf.baseAddress!,
                    parameterSetSizes: sBuf.baseAddress!,
                    nalUnitHeaderLength: 4, extensions: nil,
                    formatDescriptionOut: &fmt)
            }
        }
        if status == noErr, let fmt {
            formatDesc = fmt
            if let session { VTDecompressionSessionInvalidate(session) }
            session = nil
        }
    }

    private func makeSession(_ fmt: CMVideoFormatDescription) {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey:
                kCVPixelFormatType_32BGRA,
        ]
        VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault, formatDescription: fmt,
            decoderSpecification: nil,
            imageBufferAttributes: attrs as CFDictionary,
            outputCallback: nil, decompressionSessionOut: &session)
    }

    private static func blockBuffer(_ data: Data) -> CMBlockBuffer? {
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: data.count, blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0,
            dataLength: data.count, flags: 0,
            blockBufferOut: &block) == noErr, let block else {
            return nil
        }
        var ok = false
        data.withUnsafeBytes { raw in
            if CMBlockBufferReplaceDataBytes(
                with: raw.baseAddress!, blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: data.count) == noErr { ok = true }
        }
        return ok ? block : nil
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd launcher/AV-Live-Body && swift build`
Expected: build succeeds. If a VideoToolbox/CoreMedia signature differs
on this SDK, fix minimally — the behavior (build a format description
from the prepended parameter sets, decode the rest) must be preserved.

- [ ] **Step 3: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/VideoDecoder.swift
git commit -m "feat(av-live-body): HEVC video decoder"
```

---

## Task 3: Render the 91-joint USB skeleton

`Skeleton3DRenderer` already subscribes to a 91-joint ARKit body
publisher into `lastArkit` but never draws it — `Skeleton3DRenderer.swift:138`
is `// TODO: render yellow ARKit markers from lastArkit in update()`.
Complete it: draw the 91 joints as small yellow spheres.

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/Skeleton3DRenderer.swift`

- [ ] **Step 1: Read the renderer**

Read `Skeleton3DRenderer.swift` fully. Note: `PersonEntities` (the
per-pid entity struct), `lastArkit: [Int: ArkitOSCListener.ArkitBodyFrame]`,
`makePerson(pid:parent:)`, the `update(frames:)` 30 fps tick, and the
RealityKit space conversion used for MediaPipe joints
(`SIMD3(k.x, -k.y, -k.z)`).

- [ ] **Step 2: Add 91 ARKit marker entities to `PersonEntities`**

In the `PersonEntities` struct, add a field:

```swift
        var arkitMarkers: [ModelEntity]   // 91 yellow ARKit joint spheres
```

In `makePerson(pid:parent:)`, after the hand spheres are built, create
91 yellow marker spheres (reuse the `jointRadius`-sized sphere mesh, a
yellow `SimpleMaterial`), parent them to `root`, start them disabled,
and include `arkitMarkers:` in the returned `PersonEntities(...)`:

```swift
        let arkitMat = SimpleMaterial(
            color: .systemYellow, roughness: 0.6, isMetallic: false)
        var arkitMarkers: [ModelEntity] = []
        arkitMarkers.reserveCapacity(91)
        for _ in 0..<91 {
            let e = ModelEntity(mesh: sphereMesh, materials: [arkitMat])
            e.isEnabled = false
            root.addChild(e)
            arkitMarkers.append(e)
        }
```

- [ ] **Step 3: Draw the ARKit markers each tick**

Replace the line `// TODO: render yellow ARKit markers from lastArkit in update()`
(`Skeleton3DRenderer.swift:138`) — leave the comment removed — and add,
at the end of `update(frames:)` (after the existing per-pid loop), a
call to a new private method `applyArkit()`. Then add the method:

```swift
    /// Draw the 91-joint ARKit/USB skeletons as yellow joint markers.
    /// ARKit joints are world-space metric; convert to RealityKit
    /// space (x, y, z) -> (x, -y, -z) like the MediaPipe path.
    private func applyArkit() {
        for (pid, entities) in persons {
            guard let frame = lastArkit[pid] else {
                for m in entities.arkitMarkers { m.isEnabled = false }
                continue
            }
            let n = min(91, entities.arkitMarkers.count,
                        frame.joints.count)
            for i in 0..<n {
                let marker = entities.arkitMarkers[i]
                if frame.hasJoint[i] {
                    let j = frame.joints[i]
                    marker.transform.translation =
                        SIMD3<Float>(j.x, -j.y, -j.z)
                    marker.isEnabled = true
                } else {
                    marker.isEnabled = false
                }
            }
            for i in n..<entities.arkitMarkers.count {
                entities.arkitMarkers[i].isEnabled = false
            }
        }
    }
```

Note: `applyArkit()` iterates `persons`, which is only populated for
pids seen in the MediaPipe `frames`. If the USB skeleton must show
when there is no MediaPipe pose, also create a `PersonEntities` for
each pid present in `lastArkit`. To keep Task 3 minimal, in
`update(frames:)` before `applyArkit()`, ensure entities exist for
ARKit-only pids:

```swift
        for pid in lastArkit.keys where persons[pid] == nil {
            persons[pid] = makePerson(pid: pid, parent: anchor)
            lastSeenAt[pid] = now
        }
```

- [ ] **Step 4: Verify build + tests**

Run: `cd launcher/AV-Live-Body && swift build` — Expected: succeeds.
Run: `cd launcher/AV-Live-Body && swift test` — Expected: all tests
still pass (no regression).

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/Skeleton3DRenderer.swift
git commit -m "feat(av-live-body): render 91-joint USB skeleton"
```

---

## Task 4: Wire the consumer into the app

Construct `USBSkeletonConsumer` in the app, start/stop it with the
scene, and feed it into `Skeleton3DRenderer` in place of (or alongside)
`ArkitOSCListener`.

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/AVLiveBodyApp.swift`
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift`

- [ ] **Step 1: Read the two files**

Read `AVLiveBodyApp.swift` and `BodyView.swift`. Identify: where the
`@StateObject` listeners are declared in `ContentView`, where `.onAppear`
starts them, how `ArkitOSCListener` is passed into `BodyView`, and where
`BodyView.makeNSView` calls `skel3d.attach(to:listener:arkitListener:)`.

- [ ] **Step 2: Own and start the consumer**

In `AVLiveBodyApp.swift`'s `ContentView`, add a `@StateObject`:

```swift
    @StateObject private var usbConsumer = USBSkeletonConsumer()
```

In `.onAppear`, alongside the existing listener `.start()` calls, add
`usbConsumer.start()`. If there is an `.onDisappear`, add
`usbConsumer.stop()`.

- [ ] **Step 3: Thread the consumer to the renderer**

`Skeleton3DRenderer.attach` currently takes
`arkitListener: ArkitOSCListener?`. The simplest correct change: give
`USBSkeletonConsumer` the same role. Add an overload / extra parameter
so `attach` can subscribe to `usbConsumer.$bodies` exactly as it
subscribes to `arkitListener.$bodies` (both publish
`[Int: ArkitOSCListener.ArkitBodyFrame]`). Concretely, in
`Skeleton3DRenderer.attach`, accept `usbConsumer: USBSkeletonConsumer?`
and, if non-nil, subscribe its `$bodies` into `lastArkit` with the same
sink already used for `arkitListener` (the `arkitSub` Combine
subscription). Pass `usbConsumer` from `ContentView` → `BodyView` →
`makeNSView` → `skel3d.attach(...)`, mirroring how `arkitListener` is
already threaded.

If `arkitListener` (the OSC one) is now redundant, it may be passed as
`nil`; do not delete `ArkitOSCListener` in this plan (other code or
Plan 3b cleanup may still reference it).

- [ ] **Step 4: Verify build**

Run: `cd launcher/AV-Live-Body && swift build` — Expected: succeeds.
Run: `cd launcher/AV-Live-Body && swift test` — Expected: no regression.

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/AVLiveBodyApp.swift launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift
git commit -m "feat(av-live-body): wire USB consumer to renderer"
```

---

## Task 5: Final verification

- [ ] **Step 1: Clean build + full test suite**

```bash
cd launcher/AV-Live-Body && swift build && swift test
```

Expected: build succeeds; all tests pass (7: prior 6 + Task 1's).

- [ ] **Step 2: Confirm the integration seam**

`USBSkeletonConsumer.devicePort` (7000) must equal the iOS app's
`USBServer.port`. Verify:

```bash
grep -rn "port.*7000\|devicePort" \
  launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift \
  iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/USBServer.swift
```

Expected: both sides use `7000`.

- [ ] **Step 3: Commit any fix** (only if Step 2 found a mismatch).

---

## Self-Review

- **Spec coverage:** This plan implements the spec's `USBClient`
  consumption inside `AVLiveBody`, the `VideoDecoder` unit, and the
  skeleton render path. `MultiHMRCoreML`, `BodyFusion`, and dense-mesh
  rendering are explicitly Plan 3b (gated on a confirmed CoreML
  Multi-HMR `.mlpackage`).
- **Placeholders:** none — new files have complete code; modify tasks
  cite exact files and the line-138 TODO, and instruct the implementer
  to read exact context for `AVLiveBodyApp.swift`/`BodyView.swift`
  (whose current line numbers are not reproduced here).
- **Type consistency:** `USBSkeletonConsumer.bodyFrame` returns
  `ArkitOSCListener.ArkitBodyFrame`; `Skeleton3DRenderer` already
  stores `lastArkit: [Int: ArkitOSCListener.ArkitBodyFrame]`, so the
  consumer is type-compatible with the existing `arkitSub` path.
  `VideoDecoder` consumes `VideoPayload` exactly as Plan 2's
  `VideoEncoder` produces it (parameter sets prepended, 4-byte
  big-endian length prefixes).
- **Known risks:** (1) `BodyView` owns `Skeleton3DRenderer`, so Task 4
  threads a new object through `ContentView` → `BodyView` → `attach` —
  multi-file, follow the existing `arkitListener` threading exactly.
  (2) `StreamDemuxer.findMagic` copies the whole buffer per `feed()`;
  for HEVC video this is a perf risk — acceptable for Plan 3a, revisit
  if frame rate suffers. (3) The HEVC parameter-set split in
  `VideoDecoder` assumes the iOS encoder's exact prepend layout —
  this is the Plan 2 ↔ Plan 3a integration seam; validate on real
  device data.
