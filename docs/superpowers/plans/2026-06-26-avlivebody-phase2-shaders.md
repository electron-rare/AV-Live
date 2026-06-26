# AVLiveBody Phase 2 — Metal shader backgrounds + 3D hand/face skeleton (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the archived app's 10 Metal shader background modes and 3D hand/face skeleton into `avlivebody-mac`, composited behind the RealityKit scene, with the shader uniforms fed from the iPhone stream (body + Phase-0 hands/face).

**Architecture:** A layered `NSView` container hosts an `MTKView` (running `scene.metal` via a ported `SceneRenderer`) behind a transparent `ARView` (the existing `SceneController` content). `RenderSettings` gains `showScene`/`vizMode`; the panel gets a mode picker. A per-frame uniform feed derives the `SceneUniforms` from `USBSkeletonConsumer`'s skeleton + hands + face. The 3D hand/face skeleton renders the Phase-0 Vision landmarks in the ARView at the body's depth.

**Tech Stack:** Swift, SwiftUI, AppKit (`NSViewRepresentable`), RealityKit, Metal/MetalKit, the bundled `scene.metal`.

## Global Constraints

- Base app `avlivebody-mac/` (xcodegen Xcode project, macOS 15, unsigned). Build with `xcodebuild`. New source/resource files need `xcodegen generate` before build (project.yml is directory-glob for sources; `scene.metal` must be declared as a resource).
- All UI/scene types are `@MainActor`.
- `SceneUniforms` Swift struct field order MUST exactly match `scene.metal`'s struct (36 floats, stride 144). The shader is ported verbatim from `launcher/_archive-AV-Live-Body/Sources/AVLiveBody/Resources/scene.metal`.
- Shader must compile offline: `xcrun -sdk macosx metal -c scene.metal -o /tmp/x.air` (exit 0).
- Vision coords from Phase 0 are normalized image coords [0,1], y already flipped to top-left on the iPhone (`HandsPayload`/`FacePayload`).
- No emojis. Commit subject ≤ 50 chars, no AI attribution, no `--no-verify`, no underscore in commit scope.
- Branch: `main` (trunk-based). SourceKit single-file diagnostics are noise; `xcodebuild` is the source of truth.

### Interaction with the "max compute on iPhone" track
Task 3 (uniform feed) derives the shader scalars **on the Mac** from the raw
iPhone landmarks. This derivation is deliberately isolated in ONE function
(`SceneUniformBuilder`) so option A (derive on the iPhone, send a compact
derivatives frame) can later replace its body with a passthrough without
touching the renderer or compositing. Do not scatter derivation logic.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `avlivebody-mac/Sources/AVLiveBody/Resources/scene.metal` | Create (copy A) | shader (10 modes + bg_vertex/bg_fragment) |
| `avlivebody-mac/Sources/AVLiveBody/SceneRenderer.swift` | Create (port A) | MTKView delegate + SceneUniforms + pipeline |
| `avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift` | Create | NSViewRepresentable: MTKView back + ARView front |
| `avlivebody-mac/Sources/AVLiveBody/SceneUniformBuilder.swift` | Create | derive SceneUniforms from skeleton+hands+face |
| `avlivebody-mac/Sources/AVLiveBody/HandFaceSkeleton.swift` | Create | 3D hand/face landmark entities |
| `avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift` | Modify | add `showScene`, `vizMode` |
| `avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift` | Modify | Scene toggle + viz-mode picker |
| `avlivebody-mac/Sources/AVLiveBody/SceneController.swift` | Modify | expose hands/face update + provide ARView for layering |
| `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift` | Modify | use LayeredSceneView; route hands/face + uniforms |
| `avlivebody-mac/project.yml` | Modify | bundle `scene.metal`; ensure MetalKit |

---

## Task 1: Port scene.metal + SceneRenderer

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/Resources/scene.metal`
- Create: `avlivebody-mac/Sources/AVLiveBody/SceneRenderer.swift`
- Modify: `avlivebody-mac/project.yml`

**Interfaces:**
- Produces: `final class SceneRenderer: NSObject, MTKViewDelegate` with `static func make() -> SceneRenderer?`, a public `var uniforms: SceneRenderer.SceneUniforms`, and a nested `struct SceneUniforms` (36 floats, exact `scene.metal` order).

- [ ] **Step 1: Copy the shader**

```bash
cp "/Users/electron/Documents/Projets/AV-Live/launcher/_archive-AV-Live-Body/Sources/AVLiveBody/Resources/scene.metal" \
   "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac/Sources/AVLiveBody/Resources/scene.metal"
```

- [ ] **Step 2: Verify the shader compiles offline**

Run: `xcrun -sdk macosx metal -c "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac/Sources/AVLiveBody/Resources/scene.metal" -o /tmp/scene.air`
Expected: exit 0 (warnings OK, no errors).

- [ ] **Step 3: Declare scene.metal as a bundled resource in project.yml**

In `avlivebody-mac/project.yml`, under the `AVLiveBody` target, add a `resources`/sources entry so `scene.metal` is bundled (it must be copied as a resource, not compiled into the default Metal library, because `SceneRenderer` compiles it at runtime from source). Add to the target:
```yaml
    sources:
      - path: Sources/AVLiveBody
        excludes:
          - Info.plist
      - path: Sources/AVLiveBody/Resources/scene.metal
        buildPhase: resources
```
(If `Sources/AVLiveBody` already globs the file as a Metal compile input, also add `excludes: [Resources/scene.metal]` to the first entry so it is ONLY a resource, never compiled into `default.metallib`.)

- [ ] **Step 4: Create SceneRenderer (port from the archive, Bundle.main)**

Create `SceneRenderer.swift` as a verbatim port of
`launcher/_archive-AV-Live-Body/Sources/AVLiveBody/SceneRenderer.swift` with ONE
change: the resource lookup uses `Bundle.main` (the Xcode app bundle), not
`Bundle.module` (SwiftPM). The full file:

```swift
import Foundation
import Metal
import MetalKit

/// Metal renderer for the 10 background viz modes (storm, tunnel,
/// plasma, kaleido, voronoi, metaballs, starfield, bars, hands3d,
/// openpos). Compiles the bundled scene.metal at runtime; sits as the
/// backing layer under the transparent ARView.
final class SceneRenderer: NSObject, MTKViewDelegate {
    /// Mirror of scene.metal SceneUniforms (36 floats, 144 B). Field
    /// order MUST match the shader exactly.
    struct SceneUniforms {
        var time: Float = 0
        var rms: Float = 0
        var kp_norm: Float = 0
        var netz_dev: Float = 0
        var lightning_flash: Float = 0
        var flare: Float = 0
        var wind_norm: Float = 0
        var bz_norm: Float = 0
        var social_rate: Float = 0
        var pose_alive: Float = 0
        var pose_count: Float = 0
        var width: Float = 1280
        var height: Float = 720
        var viz_mode: Float = 0
        var hand_l_x: Float = 0
        var hand_l_y: Float = 0
        var hand_r_x: Float = 0
        var hand_r_y: Float = 0
        var mouth_open: Float = 0
        var eye_open_l: Float = 0
        var eye_open_r: Float = 0
        var head_tilt: Float = 0
        var head_yaw: Float = 0
        var finger_pinch_l: Float = 0
        var finger_pinch_r: Float = 0
        var body_x: Float = 0
        var body_y: Float = 0
        var body_z: Float = 0
        var body_height: Float = 0
        var arm_spread: Float = 0
        var pose_velocity: Float = 0
        var _pad0: Float = 0
        var _pad1: Float = 0
        var _pad2: Float = 0
        var _pad3: Float = 0
        var _pad4: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bgPipeline: MTLRenderPipelineState
    private let uniformsBuffer: MTLBuffer
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    var uniforms = SceneUniforms()

    static func make() -> SceneRenderer? { SceneRenderer(failable: ()) }

    private init?(failable: Void) {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue() else { return nil }
        self.device = dev
        self.commandQueue = queue
        guard let url = Bundle.main.url(forResource: "scene",
                                        withExtension: "metal"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("SceneRenderer: scene.metal missing from bundle")
            return nil
        }
        let lib: MTLLibrary
        do { lib = try dev.makeLibrary(source: source,
                                       options: MTLCompileOptions()) }
        catch { NSLog("SceneRenderer: compile error %@",
                      String(describing: error)); return nil }
        guard let vfn = lib.makeFunction(name: "bg_vertex"),
              let ffn = lib.makeFunction(name: "bg_fragment") else {
            NSLog("SceneRenderer: bg_vertex/bg_fragment missing")
            return nil
        }
        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vfn
        pd.fragmentFunction = ffn
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        do { self.bgPipeline =
            try dev.makeRenderPipelineState(descriptor: pd) }
        catch { NSLog("SceneRenderer: pipeline failed %@",
                      String(describing: error)); return nil }
        guard let buf = dev.makeBuffer(
            length: MemoryLayout<SceneUniforms>.stride,
            options: .storageModeShared) else { return nil }
        self.uniformsBuffer = buf
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.width = Float(size.width)
        uniforms.height = Float(size.height)
    }

    func draw(in view: MTKView) {
        uniforms.time = Float(CACurrentMediaTime() - startTime)
        uniformsBuffer.contents().bindMemory(
            to: SceneUniforms.self, capacity: 1).pointee = uniforms
        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cb = commandQueue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd)
        else { return }
        enc.setRenderPipelineState(bgPipeline)
        enc.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}
```

- [ ] **Step 5: Layout-guard test**

Add `avlivebody-mac/Tests/AVLiveBodyTests/SceneUniformsTests.swift`:
```swift
import XCTest
@testable import AVLiveBody

final class SceneUniformsTests: XCTestCase {
    func testStride() {
        XCTAssertEqual(MemoryLayout<SceneRenderer.SceneUniforms>.stride, 144)
    }
}
```

- [ ] **Step 6: Regenerate + build + test**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && xcodegen generate && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/avbody-dd" && \
xcodebuild test -project AVLiveBody.xcodeproj -scheme AVLiveBody -destination 'platform=macOS' \
  -derivedDataPath "$DD" 2>&1 | grep -E "error:|SceneUniformsTests|** TEST"
```
Expected: `SceneUniformsTests` passes (`stride == 144`), `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/Resources/scene.metal \
        avlivebody-mac/Sources/AVLiveBody/SceneRenderer.swift \
        avlivebody-mac/Tests/AVLiveBodyTests/SceneUniformsTests.swift \
        avlivebody-mac/project.yml
git commit -m "feat(avlivebody): port metal scene renderer"
```

---

## Task 2: Layered compositing (MTKView behind ARView)

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/SceneController.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`

**Interfaces:**
- Consumes: `SceneRenderer` (Task 1), `SceneController.arView`.
- Produces: `LayeredSceneView: NSViewRepresentable` exposing the created
  `SceneRenderer` to the caller (via a binding or a passed-in instance) and
  hosting MTKView (back, transparent) + `SceneController.arView` (front,
  transparent). `RenderSettings` gains `@Published var showScene: Bool = true`
  and `@Published var vizMode: Int = 0`.

- [ ] **Step 1: Add showScene/vizMode to RenderSettings**

In `RenderSettings.swift`, add:
```swift
    // Metal shader background (Phase 2)
    @Published var showScene: Bool = true
    @Published var vizMode: Int = 0   // 0..9
```

- [ ] **Step 2: Make the ARView transparent in SceneController**

In `SceneController.setUp()`, change the background from black to clear so the
MTKView shows through:
```swift
        arView.environment.background = .color(.clear)
        arView.layer?.isOpaque = false
        arView.layer?.backgroundColor = NSColor.clear.cgColor
```
(Replace the existing `arView.environment.background = .color(.black)` line.)

- [ ] **Step 3: Create LayeredSceneView**

```swift
// avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift
import AppKit
import MetalKit
import RealityKit
import SwiftUI

/// Layered container: MTKView (Metal shader bg, transparent) behind the
/// SceneController's transparent ARView. The owner holds the SceneRenderer
/// so it can push uniforms each frame.
struct LayeredSceneView: NSViewRepresentable {
    let controller: SceneController
    let renderer: SceneRenderer?

    func makeNSView(context: Context) -> NSView {
        controller.setUp()
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        if let renderer {
            let mtk = MTKView(frame: container.bounds,
                              device: MTLCreateSystemDefaultDevice())
            mtk.delegate = renderer
            mtk.colorPixelFormat = .bgra8Unorm
            mtk.framebufferOnly = false
            mtk.layer?.isOpaque = true
            mtk.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            mtk.preferredFramesPerSecond = 60
            mtk.autoresizingMask = [.width, .height]
            container.addSubview(mtk)
            context.coordinator.mtk = mtk
        }

        let arView = controller.arView
        arView.frame = container.bounds
        arView.autoresizingMask = [.width, .height]
        arView.wantsLayer = true
        arView.layer?.isOpaque = false
        arView.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(arView)   // front
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.mtk?.isHidden = false   // visibility via showScene handled by caller setting renderer.uniforms / hidden
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var mtk: MTKView? }
}
```

- [ ] **Step 4: Wire LayeredSceneView into ContentView**

In `AVLiveBodyApp.swift` `ContentView`, add a renderer and swap `SceneView` for
`LayeredSceneView`:
```swift
    private let renderer = SceneRenderer.make()
```
Replace `SceneView(controller: controller)` in the `body` with:
```swift
            LayeredSceneView(controller: controller, renderer: renderer)
```
In `applyAll()`, drive scene visibility + mode onto the renderer:
```swift
        if let r = renderer {
            r.uniforms.viz_mode = Float(settings.vizMode)
        }
```
(Show/hide of the MTKView when `!settings.showScene` is handled in Task 4 via
the panel toggle; for now the scene is always shown.)

- [ ] **Step 5: Regenerate + build**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && xcodegen generate && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/avbody-dd" && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody -configuration Debug -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift \
        avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift \
        avlivebody-mac/Sources/AVLiveBody/SceneController.swift \
        avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift \
        avlivebody-mac/AVLiveBody.xcodeproj/project.pbxproj
git commit -m "feat(avlivebody): layered metal plus arview"
```

---

## Task 3: SceneUniforms feed (Mac-side derivation, isolated)

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/SceneUniformBuilder.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`

**Interfaces:**
- Consumes: `USBSkeletonConsumer.skeletons` (`[Int: SkeletonPayload]`),
  `.hands` (`HandsPayload?`), `.face` (`FacePayload?`); the `SceneRenderer`.
- Produces: `enum SceneUniformBuilder { static func fill(_ u: inout SceneRenderer.SceneUniforms, skeletons:, hands:, face:, prevPelvis: inout SIMD3<Float>?) }` — the SINGLE place deriving shader scalars (so option A can later swap it for an iPhone-derivatives passthrough).

- [ ] **Step 1: Create SceneUniformBuilder**

Derives the body/hand/face channels; leaves data-feed channels at 0. (Indices
follow ARKit body joints — confirm the wrist/head/pelvis indices against
`ARSkeletonDefinition.defaultBody3D` jointNames during implementation; the
constants below are the documented ARKit body3D ordering.)

```swift
// avlivebody-mac/Sources/AVLiveBody/SceneUniformBuilder.swift
import AVLiveWire
import simd

enum SceneUniformBuilder {
    // ARKit defaultBody3D indices (verify against jointNames at impl time).
    private static let hipsIdx = 0
    private static let headIdx = 51
    private static let lWristIdx = 32
    private static let rWristIdx = 7

    static func fill(_ u: inout SceneRenderer.SceneUniforms,
                     skeletons: [Int: SkeletonPayload],
                     hands: HandsPayload?,
                     face: FacePayload?,
                     prevPelvis: inout SIMD3<Float>?) {
        u.pose_count = Float(skeletons.count)
        u.pose_alive = skeletons.isEmpty ? 0 : 1

        if let body = skeletons.values.first {
            func j(_ i: Int) -> SIMD3<Float>? {
                (i < body.joints.count && body.valid[i]) ? body.joints[i] : nil
            }
            if let hips = j(hipsIdx) {
                u.body_x = hips.x; u.body_y = hips.y; u.body_z = hips.z
                if let prev = prevPelvis {
                    let v = simd_length(hips - prev)
                    u.pose_velocity = u.pose_velocity * 0.7 + v * 0.3
                }
                prevPelvis = hips
                if let head = j(headIdx) {
                    u.body_height = abs(head.y - hips.y)
                }
            }
            if let lw = j(lWristIdx), let rw = j(rWristIdx) {
                u.arm_spread = abs(lw.x - rw.x)
            }
        }

        // Hands (Phase-0 Vision, normalized [0,1]).
        u.hand_l_x = 0; u.hand_l_y = 0; u.hand_r_x = 0; u.hand_r_y = 0
        u.finger_pinch_l = 0; u.finger_pinch_r = 0
        for hand in hands?.hands ?? [] {
            let c = centroid(hand.points)           // (x,y)
            let pinch = dist(hand.points, 4, 8)     // thumb_tip..index_tip
            if hand.isRight {
                u.hand_r_x = c.x; u.hand_r_y = c.y; u.finger_pinch_r = pinch
            } else {
                u.hand_l_x = c.x; u.hand_l_y = c.y; u.finger_pinch_l = pinch
            }
        }

        // Face (Phase-0 Vision allPoints). Region-based derivation is
        // refined at impl time; here a robust bbox-ratio proxy.
        if let f = face, f.points.count > 8 {
            let ys = f.points.map { $0.y }, xs = f.points.map { $0.x }
            let h = (ys.max() ?? 0) - (ys.min() ?? 0)
            let w = (xs.max() ?? 0) - (xs.min() ?? 0)
            u.mouth_open = 0      // set from outer/inner-lip points at impl time
            u.eye_open_l = 0; u.eye_open_r = 0
            u.head_tilt = 0; u.head_yaw = 0
            _ = (h, w)
        }
    }

    private static func centroid(_ p: [SIMD3<Float>]) -> SIMD2<Float> {
        guard !p.isEmpty else { return .zero }
        var s = SIMD2<Float>(0, 0)
        for v in p { s.x += v.x; s.y += v.y }
        return s / Float(p.count)
    }
    private static func dist(_ p: [SIMD3<Float>], _ a: Int, _ b: Int)
        -> Float {
        guard a < p.count, b < p.count else { return 0 }
        return simd_length(SIMD2(p[a].x, p[a].y) - SIMD2(p[b].x, p[b].y))
    }
}
```

- [ ] **Step 2: Drive the uniforms each frame from ContentView**

In `AVLiveBodyApp.swift`, add a `@State private var prevPelvis: SIMD3<Float>?`
and feed the renderer when skeleton/hands/face change. Add `.onReceive`
handlers (alongside the existing skeleton one):
```swift
        .onReceive(consumer.$hands) { _ in pushUniforms() }
        .onReceive(consumer.$face) { _ in pushUniforms() }
```
and extend the existing skeleton `.onReceive` to also `pushUniforms()`. Add:
```swift
    @State private var prevPelvis: SIMD3<Float>?
    private func pushUniforms() {
        guard let r = renderer else { return }
        r.uniforms.viz_mode = Float(settings.vizMode)
        SceneUniformBuilder.fill(&r.uniforms,
                                 skeletons: consumer.skeletons,
                                 hands: consumer.hands,
                                 face: consumer.face,
                                 prevPelvis: &prevPelvis)
    }
```

- [ ] **Step 3: Regenerate + build**

Run the same `xcodegen generate && xcodebuild ... build` as Task 2 Step 5.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/SceneUniformBuilder.swift \
        avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift \
        avlivebody-mac/AVLiveBody.xcodeproj/project.pbxproj
git commit -m "feat(avlivebody): feed scene uniforms from stream"
```

---

## Task 4: Viz-mode picker + Scene toggle in the panel

**Files:**
- Modify: `avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`

**Interfaces:**
- Consumes: `RenderSettings.showScene`/`vizMode` (Task 2).
- Produces: panel controls; MTKView hidden when `!showScene`; `vizMode` reflected
  in the renderer.

- [ ] **Step 1: Add a Scene section to SettingsPanel**

In `SettingsPanel.swift`, add after the "Vue" group:
```swift
                group("Scene") {
                    Toggle("Fond shader", isOn: $settings.showScene)
                    Picker("Mode", selection: $settings.vizMode) {
                        ForEach(0..<10, id: \.self) { i in
                            Text(Self.modeName(i)).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                }
```
Add the mode-name helper:
```swift
    static func modeName(_ i: Int) -> String {
        let n = ["storm","tunnel","plasma","kaleido","voronoi",
                 "metaballs","starfield","bars","hands3d","openpos"]
        return n.indices.contains(i) ? "\(i) \(n[i])" : "\(i)"
    }
```

- [ ] **Step 2: Expose MTKView hide to the controller path**

In `LayeredSceneView`, store the renderer/MTKView so visibility can be toggled.
Add to `updateNSView`:
```swift
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.mtk?.isHidden = !showScene
    }
```
and add `let showScene: Bool` to `LayeredSceneView` (passed from ContentView).

- [ ] **Step 3: Pass showScene from ContentView**

In `AVLiveBodyApp.swift`, update the `LayeredSceneView(...)` call to
`LayeredSceneView(controller: controller, renderer: renderer, showScene: settings.showScene)`
and ensure `pushUniforms()` already sets `viz_mode` (Task 3). The `.onReceive(settings.objectWillChange)` from Phase 1 re-renders the representable so `updateNSView` runs with the new `showScene`.

- [ ] **Step 4: Regenerate + build**

Same build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift \
        avlivebody-mac/Sources/AVLiveBody/LayeredSceneView.swift \
        avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift \
        avlivebody-mac/AVLiveBody.xcodeproj/project.pbxproj
git commit -m "feat(avlivebody): viz mode picker and scene toggle"
```

---

## Task 5: 3D hand/face skeleton

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/HandFaceSkeleton.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/SceneController.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`

**Interfaces:**
- Consumes: `consumer.hands` (`HandsPayload?`), `consumer.face` (`FacePayload?`);
  the body pelvis depth from `SceneController`'s skeleton.
- Produces: `HandFaceSkeleton` (marker pools for 21×2 hand points + face points)
  added to the worldAnchor; `SceneController.updateHandFace(hands:face:)`.

- [ ] **Step 1: Create HandFaceSkeleton**

Renders normalized 2D Vision points as small spheres on a plane at a fixed depth
(the body's pelvis z if available, else 0). Normalized [0,1] → scene meters via a
simple span mapping.

```swift
// avlivebody-mac/Sources/AVLiveBody/HandFaceSkeleton.swift
import AVLiveWire
import AppKit
import RealityKit
import simd

@MainActor
final class HandFaceSkeleton {
    let root = Entity()
    private static let r: Float = 0.008
    private static let spanX: Float = 1.2   // maps [0,1] -> [-0.6,0.6] m
    private static let spanY: Float = 0.9

    private let mesh = MeshResource.generateSphere(radius: r)
    private let handMat = SimpleMaterial(color: .cyan, isMetallic: false)
    private let faceMat = SimpleMaterial(color: .magenta, isMetallic: false)
    private var handPool: [ModelEntity] = []
    private var facePool: [ModelEntity] = []
    private var depth: Float = 0

    func setDepth(_ z: Float) { depth = z }

    func update(hands: HandsPayload?, face: FacePayload?) {
        let hpts = (hands?.hands ?? []).flatMap { $0.points }
        layout(&handPool, count: hpts.count, mat: handMat)
        for (i, p) in hpts.enumerated() { place(handPool[i], p.x, p.y) }
        for i in hpts.count..<handPool.count { handPool[i].isEnabled = false }

        let fpts = face?.points ?? []
        layout(&facePool, count: fpts.count, mat: faceMat)
        for (i, p) in fpts.enumerated() { place(facePool[i], p.x, p.y) }
        for i in fpts.count..<facePool.count { facePool[i].isEnabled = false }
    }

    private func place(_ e: ModelEntity, _ nx: Float, _ ny: Float) {
        // normalized top-left [0,1] -> centered meters, y up
        e.transform.translation = SIMD3<Float>(
            (nx - 0.5) * Self.spanX,
            (0.5 - ny) * Self.spanY,
            depth)
        e.isEnabled = true
    }

    private func layout(_ pool: inout [ModelEntity], count: Int,
                        mat: SimpleMaterial) {
        while pool.count < count {
            let e = ModelEntity(mesh: mesh, materials: [mat])
            root.addChild(e); pool.append(e)
        }
    }
}
```

- [ ] **Step 2: Add HandFaceSkeleton to SceneController**

In `SceneController`, add `private(set) var handFace: HandFaceSkeleton?`, create
it in `setUp()` (`let hf = HandFaceSkeleton(); worldAnchor.addChild(hf.root); handFace = hf`), and add:
```swift
    func updateHandFace(hands: HandsPayload?, face: FacePayload?) {
        handFace?.update(hands: hands, face: face)
    }
```

- [ ] **Step 3: Route hands/face from ContentView**

In `AVLiveBodyApp.swift`, in the `pushUniforms()` (or the `.onReceive` for
hands/face), also call:
```swift
        controller.updateHandFace(hands: consumer.hands, face: consumer.face)
```

- [ ] **Step 4: Regenerate + build**

Same build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/HandFaceSkeleton.swift \
        avlivebody-mac/Sources/AVLiveBody/SceneController.swift \
        avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift \
        avlivebody-mac/AVLiveBody.xcodeproj/project.pbxproj
git commit -m "feat(avlivebody): 3d hand and face skeleton"
```

- [ ] **Step 6: Manual visual check (user, on-device end-to-end)**

With the iPhone streaming (body + hands + face) to the Mac: the Metal shader
renders behind the body; selecting modes 0–9 in the panel switches it; the
scene reacts to body/hand movement; cyan hand points + magenta face points track
in 3D. Confirm visually.

---

## Self-Review notes

- **Spec coverage (§6):** scene.metal + SceneRenderer → Task 1; layered MTKView+ARView → Task 2; uniform feed (§6.1 mapping) → Task 3; viz-mode picker → Task 4; 3D hand/face skeleton → Task 5.
- **A-track isolation:** all derivation lives in `SceneUniformBuilder.fill` (Task 3) so option A (iPhone-derived uniforms) replaces only that function body.
- **Placeholder honesty:** Task 3's face derivations (mouth_open/eye_open/head_tilt/yaw) are seeded to 0 with a note to derive from Vision face regions at implementation time — these need the live Vision landmark indices, which the implementer confirms on-device; the body+hand channels are fully derived. The ARKit joint indices in `SceneUniformBuilder` are marked "verify against jointNames" — the implementer must confirm them (ARKit body3D ordering) during Task 3.
- **xcodegen:** every task with a new file runs `xcodegen generate`; the pbxproj is regenerated (the project is directory-glob; `git add` of the pbxproj is included where the prior phase tracked it — if `.gitignore` excludes it, the add is a no-op and a clean checkout relies on `xcodegen generate`, per the README).
- **Risk:** Task 2 (NSView layering of MTKView + ARView transparency) is the highest-risk; the archive's working compositing is the reference. If the ARView does not composite transparently over the MTKView, consult `_archive .../BodyView.swift:36-63`.

> NOTE (open, needs decision before/with Task 3): the exact ARKit `defaultBody3D`
> joint indices for hips/head/wrists, and the Vision face-region derivations for
> mouth/eyes/head pose, must be pinned during implementation. Two genuinely
> unverified spots are flagged inline; treat them as implement-time confirmations,
> not guesses to ship.
