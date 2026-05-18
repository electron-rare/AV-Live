# iPhone Capture Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS `ARBodyTracker` app stream the camera RGB video (HEVC) over the USB transport alongside the ARKit skeleton, and retire the legacy OSC/UDP sender — so the iPhone is a self-contained, network-free capture source.

**Architecture:** `ARBodySession` already captures the ARKit 91-joint skeleton and sends it as `AVLiveWire` `.skeleton` frames through `USBServer` (built in Plan 1). This plan adds a `VideoEncoder` (VideoToolbox hardware HEVC) that encodes each `ARFrame.capturedImage` and sends it as `.video` frames through the same `USBServer`. The OSC/UDP fanout (`/body3d/kp` to `host:57128/57129`) and its `ContentView` config fields are removed.

**Tech Stack:** Swift 5.10, ARKit, VideoToolbox, CoreMedia, `AVLiveWire` (local package), iOS 17. Build verification via `xcodebuild`.

**Companion spec:** `docs/superpowers/specs/2026-05-18-iphone-usb-body-link-design.md`
**Prerequisite:** Plan 1 (`docs/superpowers/plans/2026-05-18-iphone-usb-transport.md`) — merged.

---

## Verification note

The iOS app is an iOS-only target; it cannot be built with `swift build`
on a macOS host. The verification command for every task is:

```bash
cd iphone-arbody && xcodegen generate && \
xcodebuild -project ARBodyTracker.xcodeproj -scheme ARBodyTracker \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`. VideoToolbox HEVC encoding and ARKit
body tracking only run fully on a physical device — runtime behavior is
an owner on-device check, out of this plan's automated scope.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/VideoEncoder.swift` | NEW. VideoToolbox HEVC hardware encoder: `CVPixelBuffer` → `VideoPayload` via callback |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` | MODIFY. Add video encoding in `session(_:didUpdate:)`; remove OSC fanout |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift` | MODIFY. Remove OSC host/port config UI |

---

## Task 1: VideoEncoder

`VideoEncoder` wraps a `VTCompressionSession` configured for HEVC. It
accepts `CVPixelBuffer`s and invokes `onPayload` with a `VideoPayload`
(keyframe flag + the access-unit bytes; for keyframes the HEVC
parameter sets are prepended so the Mac decoder is self-sufficient).

**Files:**
- Create: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/VideoEncoder.swift`

- [ ] **Step 1: Create the file**

```swift
import AVLiveWire
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// Hardware HEVC encoder. Feed `CVPixelBuffer`s from ARKit frames in;
/// receive one `VideoPayload` per encoded access unit via `onPayload`.
/// Keyframe payloads carry the VPS/SPS/PPS parameter sets prepended,
/// each as a 4-byte-length-prefixed NAL unit, so the Mac decoder can
/// build its format description without a side channel.
final class VideoEncoder {
    var onPayload: ((VideoPayload) -> Void)?

    private var session: VTCompressionSession?
    private let lock = NSLock()

    /// Create the compression session for a given frame size.
    func start(width: Int32, height: Int32) {
        stop()
        var s: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width, height: height,
            codecType: kCMVideoCodecType_HEVC,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &s)
        guard status == noErr, let s else {
            NSLog("VideoEncoder: VTCompressionSessionCreate failed %d",
                  status)
            return
        }
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime,
                             value: kCFBooleanTrue)
        VTSessionSetProperty(s,
            key: kVTCompressionPropertyKey_AllowFrameReordering,
            value: kCFBooleanFalse)
        VTSessionSetProperty(s,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: 30 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(s)
        session = s
    }

    /// Encode one frame. `pts` is the capture timestamp in seconds.
    func encode(_ pixelBuffer: CVPixelBuffer, pts: Double) {
        lock.lock(); let s = session; lock.unlock()
        guard let s else { return }
        let time = CMTime(seconds: pts, preferredTimescale: 1_000_000)
        VTCompressionSessionEncodeFrame(
            s, imageBuffer: pixelBuffer, presentationTimeStamp: time,
            duration: .invalid, frameProperties: nil,
            infoFlagsOut: nil) { [weak self] status, _, sample in
                guard status == noErr, let sample else { return }
                self?.handle(sample)
            }
    }

    func stop() {
        lock.lock(); let s = session; session = nil; lock.unlock()
        if let s {
            VTCompressionSessionInvalidate(s)
        }
    }

    deinit { stop() }

    // MARK: - Sample → VideoPayload

    private func handle(_ sample: CMSampleBuffer) {
        let isKeyframe = !Self.notSync(sample)
        var out = Data()
        if isKeyframe, let fmt = CMSampleBufferGetFormatDescription(sample) {
            out.append(Self.parameterSets(fmt))
        }
        if let block = CMSampleBufferGetDataBuffer(sample) {
            var lengthOut = 0
            var ptr: UnsafeMutablePointer<Int8>?
            if CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil,
                totalLengthOut: &lengthOut,
                dataPointerOut: &ptr) == noErr, let ptr {
                out.append(UnsafeBufferPointer(
                    start: UnsafeRawPointer(ptr)
                        .assumingMemoryBound(to: UInt8.self),
                    count: lengthOut))
            }
        }
        guard !out.isEmpty else { return }
        onPayload?(VideoPayload(isKeyframe: isKeyframe, data: out))
    }

    /// True if the sample is NOT a sync (key) frame.
    private static func notSync(_ sample: CMSampleBuffer) -> Bool {
        guard let arr = CMSampleBufferGetSampleAttachmentsArray(
            sample, createIfNecessary: false),
            CFArrayGetCount(arr) > 0 else { return false }
        let dict = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0),
                                 to: CFDictionary.self)
        let key = Unmanaged.passUnretained(
            kCMSampleAttachmentKey_NotSync).toOpaque()
        return CFDictionaryContainsKey(dict, key)
    }

    /// Concatenate the HEVC VPS/SPS/PPS parameter sets, each as a
    /// 4-byte big-endian length prefix followed by the NAL bytes.
    private static func parameterSets(
        _ fmt: CMFormatDescription) -> Data {
        var count = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            fmt, parameterSetIndex: 0, parameterSetPointerOut: nil,
            parameterSetSizeOut: nil, parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: nil)
        var data = Data()
        for i in 0..<count {
            var ptr: UnsafePointer<UInt8>?
            var size = 0
            guard CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                fmt, parameterSetIndex: i,
                parameterSetPointerOut: &ptr,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil) == noErr,
                let ptr else { continue }
            var be = UInt32(size).bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
            data.append(UnsafeBufferPointer(start: ptr, count: size))
        }
        return data
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run the verification command from the "Verification note" section above.
Expected: `** BUILD SUCCEEDED **` (the new file compiles within the
target).

- [ ] **Step 3: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/VideoEncoder.swift
git commit -m "feat(ios): VideoToolbox HEVC encoder"
```

(subject ≤50 chars; add a short body — the commit hook rejects
subject-only messages; no AI attribution.)

---

## Task 2: Stream video from ARBodySession

Wire `VideoEncoder` into the ARKit frame loop. On each `didUpdate`
frame already processed for skeletons, also encode `capturedImage` and
send the resulting `VideoPayload` over the existing `USBServer`.

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift`

- [ ] **Step 1: Add the encoder property and its payload wiring**

In `ARBodySession`, next to `private let usb = USBServer()` (currently
line 45), add:

```swift
    private let videoEncoder = VideoEncoder()
    private var videoStarted = false
```

In `init()`, after the `usb.onState = { ... }` block, add the encoder
output wiring:

```swift
        videoEncoder.onPayload = { [weak self] payload in
            Task { @MainActor in
                guard let self, self.usbState == .connected else {
                    return
                }
                self.usb.send(tag: .video, pid: -1,
                              timestamp: self.lastFrameTime,
                              payload: payload.encoded())
            }
        }
```

- [ ] **Step 2: Encode the captured image in the frame loop**

In `session(_:didUpdate:)`, inside the `Task { @MainActor in ... }`
block, after `self.lastFrameTime = t` and before the anchor loop,
add video encoding:

```swift
            // Start the encoder lazily once the first frame size is
            // known, then encode every (throttled) frame.
            let img = frame.capturedImage
            let w = Int32(CVPixelBufferGetWidth(img))
            let h = Int32(CVPixelBufferGetHeight(img))
            if !self.videoStarted, w > 0, h > 0 {
                self.videoEncoder.start(width: w, height: h)
                self.videoStarted = true
            }
            if self.videoStarted {
                self.videoEncoder.encode(img, pts: t)
            }
```

- [ ] **Step 3: Stop the encoder on stop()**

In `stop()`, after `usb.stop()`, add:

```swift
        videoEncoder.stop()
        videoStarted = false
```

- [ ] **Step 4: Verify it compiles**

Run the verification command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift
git commit -m "feat(ios): stream HEVC video over USB"
```

---

## Task 3: Remove the legacy OSC sender

The OSC/UDP fanout is the network dependency the autonomous USB design
removes. Delete it from `ARBodySession`.

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift`

- [ ] **Step 1: Delete OSC members and methods**

In `ARBodySession.swift`, delete:
- the stored properties `host`, `pythonPort`, `swiftPort` (currently
  lines 39-41) and `conns` (line 44);
- the `configure(host:pythonPort:swiftPort:sendEnvMesh:)` method —
  replace it with a parameterless `configure(sendEnvMesh:)`:
  ```swift
  func configure(sendEnvMesh: Bool) {
      self.sendEnvMesh = sendEnvMesh
  }
  ```
- the call `openUDP()` in `start()`;
- in `stop()`, the lines `for c in conns { c.cancel() }` and
  `conns.removeAll()`;
- the entire `// MARK: - UDP fanout` section: `openUDP()` and
  `sendDatagram(_:)`;
- the `publishJoints(pid:body:)` method and its call site in
  `session(_:didUpdate:)` (`self.publishJoints(pid: count, body: body)`);
- the `sendOSC(addr:args:)` call for `/body3d/count` in
  `session(_:didUpdate:)`;
- the `// MARK: - OSC minimal encoder` section: the `OSCArg` enum,
  `sendOSC(addr:args:)`, and `appendOSCString(_:into:)`.

After deletion, `Network` is still needed (`USBServer` uses it
indirectly — actually `USBServer` imports its own `Network`). Remove
`import Network` from `ARBodySession.swift` only if no symbol from it
remains; if `NWConnection`/`NWEndpoint` no longer appear in the file,
remove the import.

- [ ] **Step 2: Verify it compiles**

Run the verification command. Expected: `** BUILD SUCCEEDED **`. If the
build reports an unused `import` or an unresolved symbol, fix it
minimally (remove the dead import, or keep it if still referenced).

- [ ] **Step 3: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift
git commit -m "refactor(ios): drop legacy OSC sender"
```

---

## Task 4: Simplify ContentView

`ContentView` exposes OSC host/port text fields that no longer have a
backing. Remove them; keep the USB status indicator and Start/Stop.

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift`

- [ ] **Step 1: Remove OSC state and UI**

In `ContentView`:
- delete the `@State` properties `host`, `pythonPort`, `swiftPort`
  (currently lines 7-9);
- in `controlPanel`, delete the `HStack { Text("Host") ... }` block and
  the `HStack { Text("Py") ... Text("Swift") ... }` block (the two
  rows of OSC text fields, currently lines 85-102);
- in the Start/Stop button action, replace the `session.configure(
  host:pythonPort:swiftPort:sendEnvMesh:)` call with
  `session.configure(sendEnvMesh: sendEnvMesh)`.

Keep: `sendEnvMesh` toggle, Start/Stop button, status text, the USB
status dot/label, and the bodies/frames/jointsPerSec line.

- [ ] **Step 2: Verify it compiles**

Run the verification command. Expected: `** BUILD SUCCEEDED **`. The
three `#Preview` blocks at the end of the file construct
`ContentView(useMockBackground:useMockSkeleton:)` — those parameters
are unaffected; the previews must still compile.

- [ ] **Step 3: Commit**

```bash
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift
git commit -m "refactor(ios): drop OSC config from ContentView"
```

---

## Task 5: Final build verification

- [ ] **Step 1: Full clean build**

```bash
cd iphone-arbody && xcodegen generate && \
xcodebuild -project ARBodyTracker.xcodeproj -scheme ARBodyTracker \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug clean build
```

Expected: `** BUILD SUCCEEDED **`, zero errors.

- [ ] **Step 2: Confirm no OSC references remain**

```bash
grep -rn -E "OSC|57128|57129|openUDP|sendDatagram" \
  iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/
```

Expected: no matches in `ARBodySession.swift` or `ContentView.swift`.
(`USBServer.swift` and `VideoEncoder.swift` never had OSC.) Comments
mentioning history are acceptable; live OSC code is not.

- [ ] **Step 3: Commit any cleanup** (only if Step 2 found stragglers)

---

## Self-Review

- **Spec coverage:** This plan implements the spec's `VideoEncoder`
  unit and the `ARBodySession` "exposes video frames / OSC sender
  removed" requirement. `ARBodySession` already builds and sends
  `SkeletonPayload` over `USBServer` (delivered via the recovery
  branch + Plan 1), so no skeleton-path task is needed. `ContentView`
  simplification follows from OSC removal.
- **Placeholders:** none — every step has concrete code or an exact
  command and expected output.
- **Type consistency:** `VideoPayload`, `FrameTag.video`,
  `USBServer.send(tag:pid:timestamp:payload:)` are used consistently
  with their Plan 1 / `AVLiveWire` definitions. `VideoEncoder.start`
  takes `Int32` width/height matching `CVPixelBufferGetWidth`'s `Int`
  cast to `Int32`.
- **Known risk:** the `VideoEncoder` VideoToolbox code compiles on the
  simulator but HEVC hardware encoding and the exact access-unit /
  parameter-set byte layout can only be validated on a physical
  device. Plan 3's `VideoDecoder` must agree with the framing chosen
  here (length-prefixed parameter sets prepended to keyframe payloads);
  this is the integration seam to verify when Plan 3 is built.
