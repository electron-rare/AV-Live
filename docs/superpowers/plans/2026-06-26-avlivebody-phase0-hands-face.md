# AVLiveBody Phase 0 — Hands + Face over AVLiveWire (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture hands (Vision hand pose) and face (Vision face landmarks) on the iPhone from the AR rear-camera frames and stream them to the Mac over two new AVLiveWire frame tags, with the Mac consumer exposing them as published state.

**Architecture:** Three layers. (1) `shared/AVLiveWire` gains `FrameTag.hands`/`.face` and `HandsPayload`/`FacePayload` codecs (pure Swift, unit-tested). (2) The iPhone `ARBodySession` runs `VNDetectHumanHandPoseRequest` + `VNDetectFaceLandmarksRequest` on `ARFrame.capturedImage` on a background queue (throttled, drop-if-busy) and sends the new frames. (3) The Mac `USBSkeletonConsumer` routes the new tags into `@Published` properties.

**Tech Stack:** Swift, SwiftPM (AVLiveWire), Xcode projects (iphone-arbody iOS, avlivebody-mac macOS), Apple Vision, ARKit, usbmux/AVLiveWire framing.

## Global Constraints

- AVLiveWire framing is fixed: 19-byte header (`magic 'AVL1' | tag u8 | pid i16 | timestamp f64 | length u32`), big-endian. Do not change the header.
- `FrameTag` already has `skeleton=1, video=2, meta=3` — the NEW tags are `hands = 4` and `face = 5`. (The design doc said 3/4; 3 is taken by `meta`.)
- Encode floats as `appendBE(f.bitPattern)` (UInt32 BE); decode as `Float(bitPattern: UInt32(bigEndianBytes: b[o..<o+4]))` — mirror the existing `SkeletonPayload`/`VideoPayload` codecs in `WirePayloads.swift`.
- Coordinates on the wire are **normalized image coordinates [0,1]** (convert Vision points before sending).
- No emojis. Commit subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no `--no-verify`, no underscore in commit scope (use hyphens).
- Vision must run OFF the main thread on the iPhone with drop-if-busy; never block the AR/encode/send path (same discipline as the Multi-HMR off-main fix). `usb.send` is invoked from `@MainActor` elsewhere — hop sends back to `@MainActor`.
- Branch: work on `main` (trunk-based, per this repo's workflow).

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift` | Modify | add `hands=4`, `face=5` to `FrameTag` |
| `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift` | Modify | `HandsPayload`, `FacePayload` codecs |
| `shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift` | Modify | roundtrip tests for both payloads |
| `avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift` | Modify | route `.hands`/`.face` → `@Published hands/face` |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` | Modify | Vision hand+face on AR frames, send tags 4/5 |

---

## Task 1: AVLiveWire protocol — tags + HandsPayload + FacePayload

Pure-Swift protocol layer, fully unit-tested via `swift test`.

**Files:**
- Modify: `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`
- Modify: `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift`
- Test: `shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift`

**Interfaces:**
- Produces:
  - `FrameTag.hands` (= 4), `FrameTag.face` (= 5)
  - `HandsPayload` with nested `HandsPayload.Hand { isRight: Bool; points: [SIMD3<Float>] }` (21 points, each `(x, y, confidence)`), `static pointsPerHand = 21`, `encoded() -> Data`, `init?(decoding: Data)`
  - `FacePayload { confidence: Float; points: [SIMD2<Float>] }`, `encoded() -> Data`, `init?(decoding: Data)`

- [ ] **Step 1: Write the failing tests**

Append to `shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift` (inside the existing `XCTestCase` subclass — match the file's existing class name):

```swift
    func testHandsPayloadRoundTrip() {
        let left = HandsPayload.Hand(
            isRight: false,
            points: (0..<21).map { SIMD3(Float($0) * 0.01,
                                         Float($0) * 0.02, 0.9) })
        let right = HandsPayload.Hand(
            isRight: true,
            points: (0..<21).map { SIMD3(Float($0) * 0.03,
                                         Float($0) * 0.04, 0.5) })
        let p = HandsPayload(hands: [left, right])
        let decoded = HandsPayload(decoding: p.encoded())
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded?.hands.count, 2)
        XCTAssertEqual(decoded?.hands[0].isRight, false)
        XCTAssertEqual(decoded?.hands[1].isRight, true)
    }

    func testHandsPayloadEmpty() {
        let p = HandsPayload(hands: [])
        let decoded = HandsPayload(decoding: p.encoded())
        XCTAssertEqual(decoded?.hands.count, 0)
    }

    func testHandsPayloadRejectsTruncated() {
        let p = HandsPayload(hands: [
            HandsPayload.Hand(isRight: false,
                              points: Array(repeating: .zero, count: 21))])
        let bad = p.encoded().dropLast()
        XCTAssertNil(HandsPayload(decoding: bad))
    }

    func testFacePayloadRoundTrip() {
        let pts = (0..<76).map { SIMD2(Float($0) * 0.001,
                                       Float($0) * 0.002) }
        let p = FacePayload(confidence: 0.87, points: pts)
        let decoded = FacePayload(decoding: p.encoded())
        XCTAssertEqual(decoded, p)
        XCTAssertEqual(decoded?.points.count, 76)
        XCTAssertEqual(decoded?.confidence, 0.87)
    }

    func testFacePayloadRejectsTruncated() {
        let p = FacePayload(confidence: 0.5,
                            points: [SIMD2(0.1, 0.2)])
        XCTAssertNil(FacePayload(decoding: p.encoded().dropLast()))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "/Users/electron/Documents/Projets/AV-Live/shared/AVLiveWire" && swift test 2>&1 | tail -20`
Expected: FAIL — `cannot find 'HandsPayload' in scope` / `cannot find 'FacePayload' in scope`.

- [ ] **Step 3: Add the new frame tags**

In `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift`, extend the enum:

```swift
public enum FrameTag: UInt8 {
    case skeleton = 1
    case video = 2
    case meta = 3
    case hands = 4
    case face = 5
}
```

- [ ] **Step 4: Add the payload codecs**

Append to `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift`:

```swift
/// Up to N hands; each = chirality + 21 (x, y, confidence) points in
/// normalized image coordinates [0,1].
public struct HandsPayload: Equatable {
    public static let pointsPerHand = 21

    public struct Hand: Equatable {
        public var isRight: Bool
        public var points: [SIMD3<Float>]
        public init(isRight: Bool, points: [SIMD3<Float>]) {
            self.isRight = isRight; self.points = points
        }
    }

    public var hands: [Hand]
    public init(hands: [Hand]) { self.hands = hands }

    public func encoded() -> Data {
        var d = Data()
        d.append(UInt8(min(hands.count, 255)))
        for hand in hands {
            d.append(hand.isRight ? 1 : 0)
            for i in 0..<Self.pointsPerHand {
                let p = i < hand.points.count ? hand.points[i] : .zero
                d.appendBE(p.x.bitPattern)
                d.appendBE(p.y.bitPattern)
                d.appendBE(p.z.bitPattern)
            }
        }
        return d
    }

    public init?(decoding data: Data) {
        let b = [UInt8](data)
        guard let n = b.first else { return nil }
        let per = 1 + Self.pointsPerHand * 12
        guard b.count == 1 + Int(n) * per else { return nil }
        var o = 1
        var result: [Hand] = []
        for _ in 0..<Int(n) {
            let isRight = b[o] != 0; o += 1
            var pts: [SIMD3<Float>] = []
            for _ in 0..<Self.pointsPerHand {
                func f() -> Float {
                    let v = Float(bitPattern:
                        UInt32(bigEndianBytes: b[o..<o+4]))
                    o += 4; return v
                }
                pts.append(SIMD3(f(), f(), f()))
            }
            result.append(Hand(isRight: isRight, points: pts))
        }
        hands = result
    }
}

/// One face: observation confidence + N landmark points in normalized
/// image coordinates [0,1] (Vision `allPoints`, ~76).
public struct FacePayload: Equatable {
    public var confidence: Float
    public var points: [SIMD2<Float>]
    public init(confidence: Float, points: [SIMD2<Float>]) {
        self.confidence = confidence; self.points = points
    }

    public func encoded() -> Data {
        var d = Data()
        d.appendBE(confidence.bitPattern)
        d.appendBE(UInt16(min(points.count, 65535)))
        for p in points {
            d.appendBE(p.x.bitPattern); d.appendBE(p.y.bitPattern)
        }
        return d
    }

    public init?(decoding data: Data) {
        let b = [UInt8](data)
        guard b.count >= 6 else { return nil }
        var o = 0
        func f() -> Float {
            let v = Float(bitPattern: UInt32(bigEndianBytes: b[o..<o+4]))
            o += 4; return v
        }
        confidence = f()
        let n = Int(UInt16(bigEndianBytes: b[o..<o+2])); o += 2
        guard b.count == 6 + n * 8 else { return nil }
        var pts: [SIMD2<Float>] = []
        for _ in 0..<n { pts.append(SIMD2(f(), f())) }
        points = pts
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd "/Users/electron/Documents/Projets/AV-Live/shared/AVLiveWire" && swift test 2>&1 | tail -20`
Expected: PASS (all existing tests + the 5 new ones).

- [ ] **Step 6: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift \
        shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift \
        shared/AVLiveWire/Tests/AVLiveWireTests/WirePayloadsTests.swift
git commit -m "feat(avlivewire): hands and face frame payloads"
```

---

## Task 2: Mac consumer routes hands/face

**Files:**
- Modify: `avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift`

**Interfaces:**
- Consumes: `FrameTag.hands`/`.face`, `HandsPayload`, `FacePayload` (Task 1).
- Produces: on `USBSkeletonConsumer`, `@Published var hands: HandsPayload?` and `@Published var face: FacePayload?`, updated on the main queue for each received frame.

- [ ] **Step 1: Read the current routing**

Read `avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift`, the `route(_:)` method (switch on `frame.header.tag`, currently `.skeleton`/`.video`, plus how `.meta` is handled) and the `@Published` properties near the top (`skeletons`, `connected`).

- [ ] **Step 2: Add published properties**

Near the existing `@Published var skeletons` / `@Published var connected`, add:

```swift
    /// Latest Vision hand landmarks from the iPhone (tag=4).
    @Published var hands: HandsPayload?
    /// Latest Vision face landmarks from the iPhone (tag=5).
    @Published var face: FacePayload?
```

- [ ] **Step 3: Route the new tags**

In `route(_:)`, add cases alongside `.skeleton`/`.video`. Keep the `switch` exhaustive over `FrameTag` (it now has `.skeleton/.video/.meta/.hands/.face`); if a `.meta` case or `default` already exists, leave it and insert these before it:

```swift
        case .hands:
            guard let payload = HandsPayload(decoding: frame.payload)
            else { return }
            DispatchQueue.main.async { [weak self] in
                self?.hands = payload
            }
        case .face:
            guard let payload = FacePayload(decoding: frame.payload)
            else { return }
            DispatchQueue.main.async { [weak self] in
                self?.face = payload
            }
```

If the existing switch has no `.meta` case and no `default`, adding the enum cases in Task 1 will have made it non-exhaustive — add a `case .meta: break` too so it compiles.

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/avbody-dd" && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody -configuration Debug \
  -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines. (The exhaustive-switch requirement is compiler-enforced — a missing case fails the build.)

Note: decode correctness is already unit-tested in Task 1 (payload roundtrips). Live frame flow is verified on-device in Task 3 / the user's run.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift
git commit -m "feat(avlivebody): consume hands and face frames"
```

---

## Task 3: iPhone captures hands + face via Vision and sends them

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift`

**Interfaces:**
- Consumes: `FrameTag.hands`/`.face`, `HandsPayload`, `FacePayload` (Task 1); the existing `usb.send(tag:pid:timestamp:payload:)`.
- Produces: per qualifying AR frame, at most one `.hands` and one `.face` AVLiveWire frame sent over USB.

- [ ] **Step 1: Add Vision import and worker state**

At the top of `ARBodySession.swift`, add `import Vision`. Add stored properties to `ARBodySession` (near `lastFrameTime`):

```swift
    private let visionQueue = DispatchQueue(
        label: "cc.saillant.arbody.vision", qos: .userInitiated)
    private var visionBusy = false
    private var lastVisionTime: TimeInterval = 0
```

- [ ] **Step 2: Add the Vision extraction + send helper**

Add this method to `ARBodySession` (it runs OFF the main actor; mark `nonisolated`). It converts Vision points to normalized image coordinates and sends the two frames. `usb.send` is hopped back to the main actor:

```swift
    nonisolated func runVision(on pixelBuffer: CVPixelBuffer,
                               timestamp t: TimeInterval) {
        let handReq = VNDetectHumanHandPoseRequest()
        handReq.maximumHandCount = 2
        let faceReq = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([handReq, faceReq])

        // ---- hands ----
        // Fixed 21-joint order matching MediaPipe-style indexing.
        let order: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip,
        ]
        var handsOut: [HandsPayload.Hand] = []
        for obs in (handReq.results ?? []).prefix(2) {
            guard let pts = try? obs.recognizedPoints(.all) else { continue }
            let p = order.map { name -> SIMD3<Float> in
                if let rp = pts[name] {
                    // Vision: normalized, bottom-left origin -> flip y.
                    return SIMD3(Float(rp.location.x),
                                 Float(1.0 - rp.location.y),
                                 Float(rp.confidence))
                }
                return .zero
            }
            handsOut.append(HandsPayload.Hand(
                isRight: obs.chirality == .right, points: p))
        }

        // ---- face (most prominent) ----
        var facePayload: FacePayload?
        if let face = (faceReq.results ?? []).first,
           let all = face.landmarks?.allPoints {
            let bb = face.boundingBox
            let pts = all.normalizedPoints.map { np -> SIMD2<Float> in
                // landmark points are relative to the face bbox.
                let x = bb.origin.x + Double(np.x) * bb.size.width
                let y = bb.origin.y + Double(np.y) * bb.size.height
                return SIMD2(Float(x), Float(1.0 - y))
            }
            facePayload = FacePayload(
                confidence: face.confidence, points: pts)
        }

        let handsData = HandsPayload(hands: handsOut).encoded()
        let faceData = facePayload?.encoded()
        Task { @MainActor in
            guard self.usbState == .connected else { return }
            self.usb.send(tag: .hands, pid: -1,
                          timestamp: t, payload: handsData)
            if let faceData {
                self.usb.send(tag: .face, pid: -1,
                              timestamp: t, payload: faceData)
            }
        }
    }
```

- [ ] **Step 3: Call it from the frame handler (throttled, drop-if-busy)**

In `session(_:didUpdate:)`, inside the existing `Task { @MainActor in ... }` block, after the video-encode section and before/after `publishUSB`, add a throttled off-main Vision dispatch (≈15 fps):

```swift
            // Vision hands+face at ~15 fps, off-main, drop if busy.
            if t - self.lastVisionTime >= 1.0 / 15.0, !self.visionBusy {
                self.lastVisionTime = t
                self.visionBusy = true
                let buf = img   // CVPixelBuffer captured for the worker
                self.visionQueue.async {
                    self.runVision(on: buf, timestamp: t)
                    Task { @MainActor in self.visionBusy = false }
                }
            }
```

(`img` is the `frame.capturedImage` already bound earlier in the block.)

- [ ] **Step 4: Build the iPhone app to verify it compiles**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/iphone-arbody" && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/arbody-dd" && \
xcodebuild -project ARBodyTracker.xcodeproj -scheme ARBodyTracker -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath "$DD" -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift
git commit -m "feat(ios): vision hands and face over usb"
```

- [ ] **Step 6: On-device smoke (manual, user)**

Deploy to the iPhone (`xcodebuild` build → `xcrun devicectl device install/launch`, device `00008140-000845660163001C`). On the Mac, run a small AVLiveWire listener (or AVLiveBody with a log) and confirm `tag=4`/`tag=5` frames arrive when a hand / face is in the iPhone camera. Tune the `orientation` (.right vs .up/.left) if hand/face coordinates look rotated. This step is verified by the user on hardware.

---

## Self-Review notes

- **Spec coverage:** §4.2 protocol (tags + payloads) → Task 1; §4.3 consumer routing → Task 2; §4.1 iPhone Vision capture → Task 3. Testing §8 Phase 0 (roundtrip unit tests, consumer build, iPhone build, on-device) → Tasks 1/2/3.
- **Correction vs spec:** spec said tags 3/4; `meta=3` pre-exists, so tags are **4 (hands) / 5 (face)** — recorded in Global Constraints.
- **Type consistency:** `HandsPayload.Hand{isRight,points}`, `FacePayload{confidence,points}` used identically in Tasks 1→2→3. `usb.send(tag:pid:timestamp:payload:)` matches the existing call site.
- **Out of scope (later phases):** consuming hands/face for shader uniforms + 3D hand/face skeleton (Phase 2); multi-person association; depth (2D only).
