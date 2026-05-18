# AVLiveBody macOS Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fresh native macOS Xcode app, `avlivebody-mac/`, that consumes the iPhone-USB body pipeline and renders the camera video + 91-joint skeleton + SMPL-X mesh in one RealityKit 3D scene — no legacy code.

**Architecture:** A SwiftUI app whose single window hosts one RealityKit `ARView` (used as a plain 3D view). The proven USB pipeline components (`AVLiveWire`, usbmux client, `VideoDecoder`, `USBSkeletonConsumer`, `MultiHMRCoreML`, `BodyFusion`) are migrated in; new clean rendering units (`SceneController`, `VideoQuad`, `SkeletonEntity`, `MeshEntity`) build the scene. The old `launcher/AV-Live-Body` is archived.

**Tech Stack:** Swift 5, macOS 15, Xcode + xcodegen, RealityKit, CoreML, VideoToolbox, the local `AVLiveWire` SwiftPM package, `XCTest`.

**Companion spec:** `docs/superpowers/specs/2026-05-18-avlivebody-macos-rewrite-design.md`

---

## Verification

The app is a real Xcode project. Per task:

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`. Unit tests (migrated) run with the
`xcodebuild ... test` action.

---

## File Structure

```
avlivebody-mac/
  project.yml                              xcodegen manifest
  Config/Shared.xcconfig                   committed build settings
  Config/Local.xcconfig.example            DEVELOPMENT_TEAM template
  Sources/AVLiveBody/
    AVLiveBodyApp.swift                    @main + AppDelegate
    SceneView.swift                        NSViewRepresentable -> ARView
    SceneController.swift                  owns scene/camera/entities
    VideoQuad.swift                        video-textured back plane
    SkeletonEntity.swift                   91 joint markers
    MeshEntity.swift                       SMPL-X 10475-vertex mesh
    StatusBar.swift                        connection-status overlay
    Info.plist
    usb/USBMuxProtocol.swift               migrated verbatim
    usb/USBClient.swift                    migrated verbatim
    usb/VideoDecoder.swift                 migrated verbatim
    usb/USBSkeletonConsumer.swift          migrated, cleaned
    usb/MultiHMRCoreML.swift               migrated verbatim
    usb/BodyFusion.swift                   migrated, cleaned
    Resources/smplx_faces.bin              SMPL-X face indices
    Resources/multihmr_full_672_s.mlpackage  bundled model (gitignored)
  Tests/AVLiveBodyTests/                   migrated unit tests
```

`AVLiveWire` stays in `shared/AVLiveWire`; the app depends on it.

---

## Task 1: Scaffold the Xcode project

**Files:**
- Create: `avlivebody-mac/project.yml`
- Create: `avlivebody-mac/Config/Shared.xcconfig`
- Create: `avlivebody-mac/Config/Local.xcconfig.example`
- Create: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`
- Create: `avlivebody-mac/Sources/AVLiveBody/Info.plist`

- [ ] **Step 1: Create `avlivebody-mac/project.yml`**

```yaml
name: AVLiveBody
options:
  bundleIdPrefix: cc.saillant
  deploymentTarget:
    macOS: "15.0"
  createIntermediateGroups: true

configFiles:
  Debug: Config/Shared.xcconfig
  Release: Config/Shared.xcconfig

packages:
  AVLiveWire:
    path: ../shared/AVLiveWire

targets:
  AVLiveBody:
    type: application
    platform: macOS
    deploymentTarget: "15.0"
    sources:
      - path: Sources/AVLiveBody
        excludes:
          - Info.plist
    dependencies:
      - package: AVLiveWire
        product: AVLiveWire
    configFiles:
      Debug: Config/Shared.xcconfig
      Release: Config/Shared.xcconfig
    settings:
      base:
        PRODUCT_NAME: AVLiveBody
        PRODUCT_BUNDLE_IDENTIFIER: cc.saillant.AVLiveBody
        INFOPLIST_FILE: Sources/AVLiveBody/Info.plist
        GENERATE_INFOPLIST_FILE: NO
        CODE_SIGN_STYLE: Automatic
        SWIFT_VERSION: "5.10"
        ENABLE_HARDENED_RUNTIME: YES
  AVLiveBodyTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/AVLiveBodyTests
    dependencies:
      - target: AVLiveBody
      - package: AVLiveWire
        product: AVLiveWire
```

- [ ] **Step 2: Create the config files**

`avlivebody-mac/Config/Shared.xcconfig`:

```
#include? "Local.xcconfig"

MACOSX_DEPLOYMENT_TARGET = 15.0
SWIFT_VERSION = 5.10
CODE_SIGN_STYLE = Automatic
```

`avlivebody-mac/Config/Local.xcconfig.example`:

```
// Copy to Config/Local.xcconfig and set your Apple Developer Team ID.
// Config/Local.xcconfig is gitignored.
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

- [ ] **Step 3: Create the minimal app + Info.plist**

`avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`:

```swift
import Cocoa
import SwiftUI

/// Forces a regular, keyboard-focusable foreground app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

@main
struct AVLiveBodyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            Text("AVLiveBody")
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
```

`avlivebody-mac/Sources/AVLiveBody/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AVLiveBody</string>
    <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSCameraUsageDescription</key>
    <string>Receives the tethered iPhone camera over USB.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Connects to the tethered iPhone over USB (usbmuxd).</string>
</dict>
</plist>
```

- [ ] **Step 4: Generate and build**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`, an empty window app.

- [ ] **Step 5: Commit** (the generated `.xcodeproj` is gitignored — add an `avlivebody-mac/.gitignore` with `*.xcodeproj/` and `Config/Local.xcconfig`)

```bash
git add avlivebody-mac/project.yml avlivebody-mac/Config avlivebody-mac/Sources avlivebody-mac/.gitignore
git commit -m "feat(avlivebody-mac): scaffold xcode app"
```

---

## Task 2: Migrate the USB transport files

These files are copied verbatim from `launcher/AV-Live-Body/Sources/AVLiveBody/` — they are self-contained and depend only on `AVLiveWire` + system frameworks.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/USBMuxProtocol.swift` (copy of the existing file)
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/USBClient.swift` (copy)
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/VideoDecoder.swift` (copy)

- [ ] **Step 1: Copy the three files**

```bash
mkdir -p avlivebody-mac/Sources/AVLiveBody/usb
cp launcher/AV-Live-Body/Sources/AVLiveBody/USBMuxProtocol.swift \
   launcher/AV-Live-Body/Sources/AVLiveBody/USBClient.swift \
   launcher/AV-Live-Body/Sources/AVLiveBody/VideoDecoder.swift \
   avlivebody-mac/Sources/AVLiveBody/usb/
```

- [ ] **Step 2: Migrate the unit tests for them**

```bash
mkdir -p avlivebody-mac/Tests/AVLiveBodyTests
cp launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBMuxProtocolTests.swift \
   launcher/AV-Live-Body/Tests/AVLiveBodyTests/USBClientTests.swift \
   avlivebody-mac/Tests/AVLiveBodyTests/
```

- [ ] **Step 3: Build + test**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' test
```

Expected: `** TEST SUCCEEDED **`, the USBMux/USBClient tests pass.

- [ ] **Step 4: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/usb avlivebody-mac/Tests
git commit -m "feat(avlivebody-mac): migrate usb transport"
```

---

## Task 3: Migrate USBSkeletonConsumer (cleaned)

The old `USBSkeletonConsumer` converts `SkeletonPayload` into the
legacy `ArkitOSCListener.ArkitBodyFrame`. The new app drops
`ArkitOSCListener` entirely, so the consumer publishes
`[Int: SkeletonPayload]` directly.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift`

- [ ] **Step 1: Create the cleaned file**

```swift
import AVLiveWire
import Combine
import CoreVideo
import Foundation

/// Connects to the tethered iPhone over USB (usbmuxd), demuxes the
/// AVLiveWire stream, republishes skeleton payloads (keyed by pid)
/// and forwards decoded camera frames. Blocking transport runs on a
/// dedicated background thread; only `@Published` writes hop to main.
final class USBSkeletonConsumer: ObservableObject {
    /// 91-joint skeleton payloads keyed by pid.
    @Published var skeletons: [Int: SkeletonPayload] = [:]
    @Published var connected = false

    /// Called on the main queue for every decoded camera frame.
    var onVideoFrame: ((CVPixelBuffer) -> Void)?

    /// TCP port the iPhone `USBServer` listens on.
    static let devicePort: UInt16 = 7000

    private let videoDecoder = VideoDecoder()
    private let stateLock = NSLock()
    private var running = false
    private var thread: Thread?

    init() {
        videoDecoder.onFrame = { [weak self] pixelBuffer in
            DispatchQueue.main.async {
                self?.onVideoFrame?(pixelBuffer)
            }
        }
    }

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

    private func loop() {
        while isRunning {
            guard let transport = UnixMuxTransport() else {
                NSLog("USBSkeletonConsumer: no usbmuxd; retry")
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            let client = USBClient(transport: transport)
            let devices = client.listDevices()
            guard let dev = devices.first,
                  client.connect(deviceID: dev,
                                 port: Self.devicePort) else {
                NSLog("USBSkeletonConsumer: no device; retry")
                transport.close()
                Thread.sleep(forTimeInterval: 1.0); continue
            }
            NSLog("USBSkeletonConsumer: connected to device %d", dev)
            publishConnected(true)
            var demux = StreamDemuxer()
            while isRunning {
                guard let chunk = transport.readStream(),
                      !chunk.isEmpty else { break }
                for frame in demux.feed(chunk) { route(frame) }
            }
            transport.close()
            publishConnected(false)
            NSLog("USBSkeletonConsumer: disconnected")
            if isRunning { Thread.sleep(forTimeInterval: 1.0) }
        }
    }

    private func route(_ frame: StreamDemuxer.Frame) {
        switch frame.header.tag {
        case .skeleton:
            guard let payload =
                SkeletonPayload(decoding: frame.payload) else { return }
            let pid = Int(frame.header.pid)
            DispatchQueue.main.async { [weak self] in
                self?.skeletons[pid] = payload
            }
        case .video:
            guard let payload =
                VideoPayload(decoding: frame.payload) else { return }
            videoDecoder.decode(payload)
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

- [ ] **Step 2: Build**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/usb/USBSkeletonConsumer.swift
git commit -m "feat(avlivebody-mac): usb skeleton consumer"
```

---

## Task 4: Migrate MultiHMRCoreML + BodyFusion (cleaned)

Copy `MultiHMRCoreML.swift` verbatim. Adapt `BodyFusion` to take
`[Int: SkeletonPayload]` instead of the legacy `ArkitBodyFrame`.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/MultiHMRCoreML.swift` (copy)
- Create: `avlivebody-mac/Sources/AVLiveBody/usb/BodyFusion.swift`
- Test: `avlivebody-mac/Tests/AVLiveBodyTests/BodyFusionTests.swift`

- [ ] **Step 1: Copy MultiHMRCoreML.swift**

```bash
cp launcher/AV-Live-Body/Sources/AVLiveBody/MultiHMRCoreML.swift \
   avlivebody-mac/Sources/AVLiveBody/usb/
```

- [ ] **Step 2: Write the BodyFusion test**

`avlivebody-mac/Tests/AVLiveBodyTests/BodyFusionTests.swift`:

```swift
import XCTest
import AVLiveWire
@testable import AVLiveBody

final class BodyFusionTests: XCTestCase {
    private func skeleton(pelvisZ: Float) -> SkeletonPayload {
        var p = SkeletonPayload()
        p.joints[0] = SIMD3(0, 0, pelvisZ)
        p.valid[0] = true
        return p
    }

    func testPelvisDepthOverride() {
        let mesh = MultiHMRPerson(
            vertices: [SIMD3<Float>](repeating: .zero, count: 1),
            translation: SIMD3(0, 0, -1.0), score: 0.9)
        let fused = BodyFusion.fuse(
            persons: [mesh], skeletons: [0: skeleton(pelvisZ: -2.5)])
        XCTAssertEqual(fused[0].translation.z, -2.5, accuracy: 1e-4)
    }

    func testPassthroughWhenNoSkeleton() {
        let mesh = MultiHMRPerson(
            vertices: [SIMD3<Float>](repeating: .zero, count: 1),
            translation: SIMD3(0, 0, -1.0), score: 0.9)
        let fused = BodyFusion.fuse(persons: [mesh], skeletons: [:])
        XCTAssertEqual(fused[0].translation.z, -1.0, accuracy: 1e-4)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd avlivebody-mac && xcodegen generate && xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody -destination 'platform=macOS' test`
Expected: FAIL — `BodyFusion` undefined.

- [ ] **Step 4: Write BodyFusion.swift**

`avlivebody-mac/Sources/AVLiveBody/usb/BodyFusion.swift`:

```swift
import AVLiveWire
import Foundation
import simd

/// Associates Multi-HMR meshes with USB skeletons and corrects the
/// mesh pelvis depth. Pure, stateless — unit-testable.
enum BodyFusion {
    /// SMPL-X / ARKit body root (hips) joint index.
    static let pelvisJoint = 0

    static func fuse(persons: [MultiHMRPerson],
                     skeletons: [Int: SkeletonPayload])
        -> [MultiHMRPerson] {
        let pelvisZs: [Float] = skeletons.values.compactMap { s in
            guard pelvisJoint < s.valid.count,
                  s.valid[pelvisJoint] else { return nil }
            return s.joints[pelvisJoint].z
        }
        guard !pelvisZs.isEmpty,
              let primaryIdx = persons.indices.max(by: {
                  persons[$0].score < persons[$1].score
              }) else { return persons }
        var out = persons
        out[primaryIdx].translation.z = pelvisZs[0]
        return out
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run the `test` command. Expected: `BodyFusionTests` pass.

- [ ] **Step 6: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/usb/MultiHMRCoreML.swift avlivebody-mac/Sources/AVLiveBody/usb/BodyFusion.swift avlivebody-mac/Tests/AVLiveBodyTests/BodyFusionTests.swift
git commit -m "feat(avlivebody-mac): multi-hmr and body fusion"
```

---

## Task 5: SceneController + SceneView

`SceneController` owns the RealityKit scene, an orbital camera, and
the entity roots. `SceneView` is the `NSViewRepresentable` bridge.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/SceneController.swift`
- Create: `avlivebody-mac/Sources/AVLiveBody/SceneView.swift`

- [ ] **Step 1: Write `SceneController.swift`**

```swift
import Foundation
import RealityKit
import simd

/// Owns the single RealityKit scene: the video quad, the body root,
/// and an orbital camera. The app calls `updateVideo/updateSkeleton/
/// updateMesh` from the main queue.
@MainActor
final class SceneController {
    let arView = ARView(frame: .zero)

    private let cameraAnchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let worldAnchor = AnchorEntity(world: .zero)

    private(set) var videoQuad: VideoQuad?
    private(set) var skeleton: SkeletonEntity?
    private(set) var mesh: MeshEntity?

    /// Orbital camera state.
    private var orbitYaw: Float = 0
    private var orbitPitch: Float = 0
    private var orbitRadius: Float = 3.0

    func setUp() {
        arView.environment.background = .color(.black)
        arView.scene.addAnchor(worldAnchor)

        camera.camera.fieldOfViewInDegrees = 55
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)
        applyCamera()

        let q = VideoQuad()
        worldAnchor.addChild(q.entity)
        videoQuad = q

        let s = SkeletonEntity()
        worldAnchor.addChild(s.root)
        skeleton = s

        let m = MeshEntity()
        worldAnchor.addChild(m.root)
        mesh = m

        installOrbitGestures()
    }

    func updateVideo(_ pixelBuffer: CVPixelBuffer) {
        videoQuad?.update(pixelBuffer)
    }

    func updateSkeleton(_ skeletons: [Int: SkeletonPayload]) {
        skeleton?.update(skeletons)
    }

    func updateMesh(_ persons: [MultiHMRPerson]) {
        mesh?.update(persons)
    }

    // MARK: - Orbital camera

    private func applyCamera() {
        let cy = cos(orbitYaw), sy = sin(orbitYaw)
        let cp = cos(orbitPitch), sp = sin(orbitPitch)
        let pos = SIMD3<Float>(orbitRadius * cp * sy,
                               orbitRadius * sp,
                               orbitRadius * cp * cy)
        cameraAnchor.transform.translation = pos
        camera.look(at: .zero, from: pos, relativeTo: nil)
    }

    private func installOrbitGestures() {
        let pan = NSPanGestureRecognizer(
            target: OrbitTarget.shared, action: #selector(
                OrbitTarget.handlePan(_:)))
        OrbitTarget.shared.controller = self
        arView.addGestureRecognizer(pan)
    }

    fileprivate func orbit(dx: Float, dy: Float) {
        orbitYaw += dx * 0.01
        orbitPitch = max(-1.4, min(1.4, orbitPitch + dy * 0.01))
        applyCamera()
    }
}

/// Bridges the AppKit pan gesture to `SceneController.orbit`.
final class OrbitTarget: NSObject {
    static let shared = OrbitTarget()
    weak var controller: SceneController?
    private var last: CGPoint = .zero

    @objc func handlePan(_ g: NSPanGestureRecognizer) {
        let p = g.translation(in: g.view)
        if g.state == .began { last = p }
        let dx = Float(p.x - last.x)
        let dy = Float(p.y - last.y)
        last = p
        Task { @MainActor in
            self.controller?.orbit(dx: dx, dy: -dy)
        }
    }
}
```

- [ ] **Step 2: Write `SceneView.swift`**

```swift
import RealityKit
import SwiftUI

/// SwiftUI bridge that hands the SceneController's ARView to the
/// window and runs `setUp()` once.
struct SceneView: NSViewRepresentable {
    let controller: SceneController

    func makeNSView(context: Context) -> ARView {
        controller.setUp()
        return controller.arView
    }

    func updateNSView(_ view: ARView, context: Context) {}
}
```

- [ ] **Step 3: Build**

`VideoQuad`, `SkeletonEntity`, `MeshEntity` do not exist yet — this
task will not build alone. Proceed to Tasks 6-8, then build at Task 8.
(Stub note: the build is verified at the end of Task 8.)

- [ ] **Step 4: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/SceneController.swift avlivebody-mac/Sources/AVLiveBody/SceneView.swift
git commit -m "feat(avlivebody-mac): scene controller + view"
```

---

## Task 6: SkeletonEntity

91 joint marker spheres under a root entity.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/SkeletonEntity.swift`

- [ ] **Step 1: Write the file**

```swift
import AVLiveWire
import Foundation
import RealityKit
import simd

/// Renders 91-joint skeletons as yellow marker spheres. One marker
/// pool per pid. ARKit world coords -> RealityKit space (x, -y, -z).
@MainActor
final class SkeletonEntity {
    let root = Entity()

    private static let jointCount = 91
    private static let markerRadius: Float = 0.012

    private var pools: [Int: [ModelEntity]] = [:]
    private let mesh = MeshResource.generateSphere(radius: markerRadius)
    private let material = SimpleMaterial(
        color: .systemYellow, roughness: 0.6, isMetallic: false)

    func update(_ skeletons: [Int: SkeletonPayload]) {
        // Drop pools for pids no longer present.
        for pid in pools.keys where skeletons[pid] == nil {
            pools[pid]?.forEach { $0.removeFromParent() }
            pools.removeValue(forKey: pid)
        }
        for (pid, payload) in skeletons {
            let pool = pools[pid] ?? makePool()
            pools[pid] = pool
            let n = min(Self.jointCount, payload.joints.count,
                        payload.valid.count)
            for i in 0..<n {
                let marker = pool[i]
                if payload.valid[i] {
                    let j = payload.joints[i]
                    marker.transform.translation =
                        SIMD3<Float>(j.x, -j.y, -j.z)
                    marker.isEnabled = true
                } else {
                    marker.isEnabled = false
                }
            }
        }
    }

    private func makePool() -> [ModelEntity] {
        var pool: [ModelEntity] = []
        pool.reserveCapacity(Self.jointCount)
        for _ in 0..<Self.jointCount {
            let e = ModelEntity(mesh: mesh, materials: [material])
            e.isEnabled = false
            root.addChild(e)
            pool.append(e)
        }
        return pool
    }
}
```

- [ ] **Step 2: Commit** (build verified at Task 8)

```bash
git add avlivebody-mac/Sources/AVLiveBody/SkeletonEntity.swift
git commit -m "feat(avlivebody-mac): 91-joint skeleton entity"
```

---

## Task 7: VideoQuad

A flat plane whose unlit material texture is replaced from each
decoded `CVPixelBuffer`. This is the spec's flagged hard point —
RealityKit has no direct pixel-buffer-stream texture path; we rebuild
a `TextureResource` per frame from a `CGImage`.

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/VideoQuad.swift`

- [ ] **Step 1: Write the file**

```swift
import CoreImage
import CoreVideo
import Foundation
import RealityKit

/// A flat plane at the back of the scene, textured with the iPhone
/// camera video. `update(_:)` is called on the main queue per frame.
@MainActor
final class VideoQuad {
    let entity = ModelEntity()

    private let ciContext = CIContext()
    /// Plane is 1.6 m wide, 16:9; positioned 2 m behind the body.
    private static let width: Float = 1.6
    private static let height: Float = 0.9
    private static let zBack: Float = -2.0

    init() {
        let plane = MeshResource.generatePlane(
            width: Self.width, height: Self.height)
        var material = UnlitMaterial()
        material.color = .init(tint: .white)
        entity.model = ModelComponent(mesh: plane,
                                      materials: [material])
        entity.transform.translation =
            SIMD3<Float>(0, 0, Self.zBack)
    }

    /// Replace the plane's texture from a decoded camera frame.
    func update(_ pixelBuffer: CVPixelBuffer) {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(
            ci, from: ci.extent) else { return }
        guard let texture = try? TextureResource(
            image: cg,
            options: .init(semantic: .color)) else { return }
        var material = UnlitMaterial()
        material.color = .init(tint: .white,
                               texture: .init(texture))
        entity.model?.materials = [material]
    }
}
```

Note: per-frame `CGImage` + `TextureResource` creation is the known
performance hot spot. It is isolated here so a later iteration can
switch to `LowLevelTexture` / a Metal-backed update without touching
callers.

- [ ] **Step 2: Commit** (build verified at Task 8)

```bash
git add avlivebody-mac/Sources/AVLiveBody/VideoQuad.swift
git commit -m "feat(avlivebody-mac): video quad"
```

---

## Task 8: MeshEntity

Renders the SMPL-X dense mesh (10475 vertices) from Multi-HMR. The
triangle indices are loaded from a bundled `smplx_faces.bin` (the same
face-index binary the old app used: a flat array of `UInt32` triplets).

**Files:**
- Create (copy): `avlivebody-mac/Sources/AVLiveBody/Resources/smplx_faces.bin`
- Create: `avlivebody-mac/Sources/AVLiveBody/MeshEntity.swift`

- [ ] **Step 1: Copy the face-index resource**

```bash
mkdir -p avlivebody-mac/Sources/AVLiveBody/Resources
cp launcher/AV-Live-Body/Sources/AVLiveBody/Resources/smplx_faces.bin \
   avlivebody-mac/Sources/AVLiveBody/Resources/
```

Declare it in `project.yml` — add under the `AVLiveBody` target a
`resources` style copy by adding to `sources` a buildPhase, or simply
keep it in `Sources/AVLiveBody/Resources` (xcodegen copies unknown
files as resources of the folder reference). Verify after Step 3 that
`Bundle.main.url(forResource: "smplx_faces", withExtension: "bin")`
resolves; if not, add an explicit resource entry to `project.yml`.

- [ ] **Step 2: Write `MeshEntity.swift`**

```swift
import Foundation
import RealityKit
import simd

/// Renders SMPL-X dense body meshes (10475 vertices) from Multi-HMR.
/// Triangle indices come from the bundled `smplx_faces.bin`
/// (flat UInt32 triplets).
@MainActor
final class MeshEntity {
    let root = Entity()

    private static let vertexCount = 10475
    private let faces: [UInt32]
    private var pools: [Int: ModelEntity] = [:]
    private let material = SimpleMaterial(
        color: .init(white: 0.8, alpha: 1.0),
        roughness: 0.5, isMetallic: false)

    init() {
        faces = MeshEntity.loadFaces()
    }

    /// Build/refresh one mesh per detected person.
    func update(_ persons: [MultiHMRPerson]) {
        for (idx, person) in persons.enumerated() {
            let entity = pools[idx] ?? {
                let e = ModelEntity()
                root.addChild(e)
                pools[idx] = e
                return e
            }()
            guard let mesh = buildMesh(person.vertices) else { continue }
            entity.model = ModelComponent(mesh: mesh,
                                          materials: [material])
            // RealityKit space conversion + fused translation.
            let t = person.translation
            entity.transform.translation =
                SIMD3<Float>(t.x, -t.y, -t.z)
            entity.isEnabled = true
        }
        for idx in pools.keys where idx >= persons.count {
            pools[idx]?.isEnabled = false
        }
    }

    private func buildMesh(_ verts: [SIMD3<Float>])
        -> MeshResource? {
        guard verts.count == Self.vertexCount,
              !faces.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "smplx")
        // Model->RealityKit space (x, -y, -z).
        descriptor.positions = MeshBuffer(verts.map {
            SIMD3<Float>($0.x, -$0.y, -$0.z)
        })
        descriptor.primitives = .triangles(faces)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func loadFaces() -> [UInt32] {
        guard let url = Bundle.main.url(
            forResource: "smplx_faces", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else {
            NSLog("MeshEntity: smplx_faces.bin missing")
            return []
        }
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: UInt32.self))
        }
    }
}
```

- [ ] **Step 3: Build the whole app (Tasks 5-8 together)**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **` — `SceneController`, `SceneView`,
`SkeletonEntity`, `VideoQuad`, `MeshEntity` all compile together. Fix
any RealityKit signature mismatch minimally (the RealityKit mesh /
texture APIs are the likely friction points; preserve behavior).

- [ ] **Step 4: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/MeshEntity.swift avlivebody-mac/Sources/AVLiveBody/Resources avlivebody-mac/project.yml
git commit -m "feat(avlivebody-mac): smpl-x mesh entity"
```

---

## Task 9: Wire the app together

Replace the placeholder window with the scene, own the consumer + the
CoreML pipeline, show a status bar.

**Files:**
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`
- Create: `avlivebody-mac/Sources/AVLiveBody/StatusBar.swift`
- Create (copy): `avlivebody-mac/Sources/AVLiveBody/Resources/multihmr_full_672_s.mlpackage`

- [ ] **Step 1: Bundle the CoreML model**

```bash
cp -R ~/.cache/av-live-multihmr/multihmr_full_672_s.mlpackage \
   avlivebody-mac/Sources/AVLiveBody/Resources/
```

It is gitignored (`*.mlpackage`) — a build input, never committed. If
absent, STOP — see voie 2 / `data_only_viz/scripts/coreml_full_probe.py`.

- [ ] **Step 2: Write `StatusBar.swift`**

```swift
import SwiftUI

/// A thin overlay showing the USB connection state.
struct StatusBar: View {
    @ObservedObject var consumer: USBSkeletonConsumer

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(consumer.connected ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(consumer.connected
                 ? "iPhone connected (USB)"
                 : "waiting for iPhone…")
                .font(.caption)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(8)
        .background(.black.opacity(0.5))
    }
}
```

- [ ] **Step 3: Rewrite `AVLiveBodyApp.swift`**

```swift
import Cocoa
import CoreVideo
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

@main
struct AVLiveBodyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @StateObject private var consumer = USBSkeletonConsumer()
    @State private var controller = SceneController()
    private let multiHMR = MultiHMRCoreML()
    /// Placeholder intrinsics until a `.meta` frame supplies real ones.
    private let cameraK: [Float] = [
        672, 0, 336, 0, 672, 336, 0, 0, 1,
    ]

    var body: some View {
        ZStack(alignment: .top) {
            SceneView(controller: controller)
            StatusBar(consumer: consumer)
        }
        .onAppear { wire() }
        .onReceive(consumer.$skeletons) { skeletons in
            controller.updateSkeleton(skeletons)
        }
    }

    private func wire() {
        consumer.onVideoFrame = { pixelBuffer in
            controller.updateVideo(pixelBuffer)
            if let hmr = multiHMR {
                let raw = hmr.infer(pixelBuffer, cameraK: cameraK)
                let fused = BodyFusion.fuse(
                    persons: raw, skeletons: consumer.skeletons)
                controller.updateMesh(fused)
            }
        }
        consumer.start()
    }
}
```

- [ ] **Step 4: Build**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift avlivebody-mac/Sources/AVLiveBody/StatusBar.swift avlivebody-mac/project.yml
git commit -m "feat(avlivebody-mac): wire scene, consumer, status"
```

---

## Task 10: Archive the old app + final verification

**Files:**
- Modify: `launcher/CLAUDE.md` (note the archival)

- [ ] **Step 1: Archive the old AVLiveBody**

```bash
git mv launcher/AV-Live-Body launcher/_archive-AV-Live-Body
```

Add a one-line note at the top of `launcher/_archive-AV-Live-Body/`
(create `ARCHIVED.md`): "Superseded by `avlivebody-mac/` on
2026-05-18 — see `docs/superpowers/specs/2026-05-18-avlivebody-macos-rewrite-design.md`."

- [ ] **Step 2: Full clean build + tests**

```bash
cd avlivebody-mac && xcodegen generate && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' clean build test
```

Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add launcher/_archive-AV-Live-Body/ARCHIVED.md launcher/CLAUDE.md
git commit -m "chore: archive legacy AV-Live-Body"
```

---

## Self-Review

- **Spec coverage:** Every spec component is built — scaffold (T1),
  USB transport (T2), `USBSkeletonConsumer` (T3), `MultiHMRCoreML` +
  `BodyFusion` (T4), `SceneController`/`SceneView` (T5),
  `SkeletonEntity` (T6), `VideoQuad` (T7), `MeshEntity` (T8), app
  wiring + `StatusBar` (T9), archival (T10). The data flow
  (consumer → controller → entities) is wired in T9.
- **Placeholders:** none — every step has concrete code or an exact
  command. T5 Step 3 deliberately defers the build to T8 because
  `SceneController` references entities created in T6-T8; this
  ordering note is explicit, not a placeholder.
- **Type consistency:** `USBSkeletonConsumer` publishes
  `[Int: SkeletonPayload]`; `SceneController.updateSkeleton` and
  `SkeletonEntity.update` consume exactly that. `BodyFusion.fuse`
  takes `[Int: SkeletonPayload]` (cleaned from the legacy
  `ArkitBodyFrame`) and `[MultiHMRPerson]`; `MultiHMRCoreML.infer`
  produces `[MultiHMRPerson]`; `MeshEntity.update` consumes it.
  `VideoDecoder.onFrame`/`USBSkeletonConsumer.onVideoFrame`/
  `SceneController.updateVideo` all carry `CVPixelBuffer`.
- **Known risks** (from the spec): `VideoQuad`'s per-frame
  `CGImage`+`TextureResource` rebuild is a perf hot spot — isolated in
  one unit. `SceneController`'s orbital camera uses an AppKit pan
  gesture bridged via `OrbitTarget`. The RealityKit `MeshDescriptor`/
  `TextureResource` APIs are the most likely to need a minor
  signature fix on the live SDK — T8 Step 3 calls this out.
