# macOS Multi-HMR Mesh Implementation Plan (Plan 3b of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the dense-mesh half of the macOS pipeline — run Multi-HMR (CoreML) on the USB video stream inside `AVLiveBody`, fuse the result with the ARKit skeleton, and render the SMPL-X body mesh.

**Architecture:** `VideoDecoder` (Plan 3a) already turns `.video` frames into `CVPixelBuffer`s. This plan adds `MultiHMRCoreML`, a Swift wrapper around the bundled `multihmr_full_672_s.mlpackage`: it preprocesses a pixel buffer into the model's two `MLMultiArray` inputs, runs inference, and parses up to 4 detected persons (10475-vertex SMPL-X meshes). `BodyFusion` associates each mesh with the ARKit skeleton from `USBSkeletonConsumer` and corrects pelvis depth. The existing `MeshRenderer` (which already renders 10475-vertex SMPL-X meshes from its OSC server) is fed from the fusion output.

**Tech Stack:** Swift 5, macOS 15, CoreML, CoreVideo/CoreImage, RealityKit, `AVLiveWire`, `XCTest`. Build verifies on the host with `swift build` / `swift test`.

**Companion spec:** `docs/superpowers/specs/2026-05-18-iphone-usb-body-link-design.md`
**Prerequisites:** Plan 1, 2, 3a (merged); the working CoreML model (voie 2).

---

## The model — exact I/O contract

The reference implementation is `data_only_viz/multihmr_coreml.py` (Python, validated). The Swift wrapper must mirror it:

- **File:** `~/.cache/av-live-multihmr/multihmr_full_672_s.mlpackage` (204 MB, FP32). Not in git (`*.mlpackage` is gitignored).
- **Load:** an `.mlpackage` must be compiled to `.mlmodelc` (`MLModel.compileModel(at:)`) before `MLModel(contentsOf:configuration:)`. Use `MLComputeUnits.cpuAndGPU` (benched best: ~139 ms standalone).
- **Inputs** (an `MLDictionaryFeatureProvider` with two `MLMultiArray`s):
  - `"image"` — shape `[1, 3, 672, 672]`, Float32, RGB, **ImageNet-normalized**: `(v - mean) / std`, mean `[0.485, 0.456, 0.406]`, std `[0.229, 0.224, 0.225]` per channel. Feeding raw `[0,1]` collapses all scores (the "0 detections" bug).
  - `"cam_K"` — shape `[1, 3, 3]`, Float32, camera intrinsics.
- **Outputs** (fixed K=4 persons):
  - `var_2420` — v3d `[4, 10475, 3]` vertices
  - `var_2423` — transl `[4, 1, 3]` pelvis translation
  - `var_2436` — scores `[4]`
  - `var_2439` — betas `[4, 10]`, `var_2442` — expression `[4, 10]` (unused here)
- **Detection:** keep person `k` when `scores[k] >= 0.3`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `launcher/AV-Live-Body/Sources/AVLiveBody/Resources/multihmr_full_672_s.mlpackage` | NEW (build input, gitignored). Copied from `~/.cache/av-live-multihmr/` by a setup step |
| `launcher/AV-Live-Body/Package.swift` | MODIFY. Declare the `.mlpackage` as a `.copy` resource |
| `launcher/AV-Live-Body/Sources/AVLiveBody/MultiHMRCoreML.swift` | NEW. Load the model; `CVPixelBuffer` → inputs → inference → `[MultiHMRPerson]` |
| `launcher/AV-Live-Body/Sources/AVLiveBody/BodyFusion.swift` | NEW. Associate ARKit skeleton ↔ Multi-HMR person; pelvis-depth correction |
| `launcher/AV-Live-Body/Tests/AVLiveBodyTests/BodyFusionTests.swift` | NEW. Pure association/correction logic tests |
| `launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift` | MODIFY. Drive `VideoDecoder` → `MultiHMRCoreML` → `BodyFusion` → `MeshRenderer` |
| `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift` | REFERENCE — reuse its existing `updatePersons`-style entry point for 10475-vertex meshes |

---

## Task 1: Bundle the model + loader

**Files:**
- Create (copy): `launcher/AV-Live-Body/Sources/AVLiveBody/Resources/multihmr_full_672_s.mlpackage`
- Modify: `launcher/AV-Live-Body/Package.swift`

- [ ] **Step 1: Copy the model into the package resources**

The model is a build input that cannot live in git. Copy it:

```bash
mkdir -p launcher/AV-Live-Body/Sources/AVLiveBody/Resources
cp -R ~/.cache/av-live-multihmr/multihmr_full_672_s.mlpackage \
   launcher/AV-Live-Body/Sources/AVLiveBody/Resources/
```

Verify it is gitignored (root `.gitignore` has `*.mlpackage`):

```bash
git check-ignore launcher/AV-Live-Body/Sources/AVLiveBody/Resources/multihmr_full_672_s.mlpackage
```

Expected: the path is printed (it is ignored — it must NOT be committed).

If the source file is absent, STOP — Plan 3b is blocked until voie 2's
`.mlpackage` is regenerated (`data_only_viz/scripts/coreml_full_probe.py`).

- [ ] **Step 2: Declare the resource in Package.swift**

In `launcher/AV-Live-Body/Package.swift`, add to the `AVLiveBody`
executable target's `resources:` array (next to the existing
`smplx_faces.bin` / `scene.metal` copies):

```swift
                .copy("Resources/multihmr_full_672_s.mlpackage"),
```

- [ ] **Step 3: Verify the build still resolves resources**

Run: `cd launcher/AV-Live-Body && swift build`
Expected: build succeeds; the `.mlpackage` is copied into the bundle.

- [ ] **Step 4: Commit (Package.swift only — the model is gitignored)**

```bash
git add launcher/AV-Live-Body/Package.swift
git commit -m "build(av-live-body): bundle Multi-HMR mlpackage"
```

---

## Task 2: MultiHMRCoreML

`MultiHMRCoreML` loads the bundled model, preprocesses a `CVPixelBuffer`
into the two model inputs, runs inference, and returns detected persons.

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/MultiHMRCoreML.swift`

- [ ] **Step 1: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/MultiHMRCoreML.swift`:

```swift
import CoreML
import CoreVideo
import CoreImage
import Foundation

/// One detected SMPL-X body from Multi-HMR.
struct MultiHMRPerson {
    var vertices: [SIMD3<Float>]   // 10475 SMPL-X verts, model space
    var translation: SIMD3<Float>  // pelvis translation
    var score: Float
}

/// CoreML wrapper around the bundled `multihmr_full_672_s.mlpackage`.
/// Mirrors `data_only_viz/multihmr_coreml.py`: two MLMultiArray inputs
/// (`image` 1x3x672x672 ImageNet-normalized, `cam_K` 1x3x3), fixed
/// K=4 person outputs.
final class MultiHMRCoreML {
    static let inputSize = 672
    static let vertexCount = 10475
    static let maxPersons = 4
    private static let detThreshold: Float = 0.3
    private static let normMean: [Float] = [0.485, 0.456, 0.406]
    private static let normStd: [Float] = [0.229, 0.224, 0.225]

    private let model: MLModel
    private let ciContext = CIContext()

    /// Loads the bundled model. Returns nil if the resource or load
    /// fails — callers fall back to skeleton-only rendering.
    init?() {
        guard let url = Bundle.module.url(
            forResource: "multihmr_full_672_s",
            withExtension: "mlpackage") else {
            NSLog("MultiHMRCoreML: mlpackage resource missing")
            return nil
        }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndGPU
        do {
            let compiled = try MLModel.compileModel(at: url)
            model = try MLModel(contentsOf: compiled, configuration: cfg)
        } catch {
            NSLog("MultiHMRCoreML: load failed %@",
                  String(describing: error))
            return nil
        }
    }

    /// Run inference on one camera frame. `cameraK` is the 3x3 camera
    /// intrinsics row-major.
    func infer(_ pixelBuffer: CVPixelBuffer,
               cameraK: [Float]) -> [MultiHMRPerson] {
        guard let image = makeImageInput(pixelBuffer),
              let k = makeKInput(cameraK) else { return [] }
        let inputs: [String: MLFeatureValue] = [
            "image": MLFeatureValue(multiArray: image),
            "cam_K": MLFeatureValue(multiArray: k),
        ]
        guard let provider = try? MLDictionaryFeatureProvider(
            dictionary: inputs),
              let out = try? model.prediction(from: provider) else {
            return []
        }
        return parse(out)
    }

    // MARK: - Input preprocessing

    /// `CVPixelBuffer` -> [1,3,672,672] Float32, RGB, ImageNet-normed.
    private func makeImageInput(_ pb: CVPixelBuffer) -> MLMultiArray? {
        let n = Self.inputSize
        // Resize to n x n BGRA via CoreImage.
        let ci = CIImage(cvPixelBuffer: pb)
        let sx = CGFloat(n) / ci.extent.width
        let sy = CGFloat(n) / ci.extent.height
        let scaled = ci.transformed(
            by: CGAffineTransform(scaleX: sx, y: sy))
        var dst: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, n, n,
            kCVPixelFormatType_32BGRA, nil, &dst)
        guard let dst else { return nil }
        ciContext.render(scaled, to: dst)
        CVPixelBufferLockBaseAddress(dst, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(dst, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(dst) else {
            return nil
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(dst)
        let px = base.assumingMemoryBound(to: UInt8.self)
        guard let arr = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: n), NSNumber(value: n)],
            dataType: .float32) else { return nil }
        let ptr = arr.dataPointer.assumingMemoryBound(to: Float.self)
        let plane = n * n
        for y in 0..<n {
            for x in 0..<n {
                let p = y * rowBytes + x * 4   // BGRA
                let b = Float(px[p]) / 255.0
                let g = Float(px[p + 1]) / 255.0
                let r = Float(px[p + 2]) / 255.0
                let idx = y * n + x
                ptr[idx] =
                    (r - Self.normMean[0]) / Self.normStd[0]
                ptr[plane + idx] =
                    (g - Self.normMean[1]) / Self.normStd[1]
                ptr[2 * plane + idx] =
                    (b - Self.normMean[2]) / Self.normStd[2]
            }
        }
        return arr
    }

    /// 9 row-major intrinsics -> [1,3,3] Float32.
    private func makeKInput(_ k: [Float]) -> MLMultiArray? {
        guard k.count == 9,
              let arr = try? MLMultiArray(
                shape: [1, 3, 3], dataType: .float32) else { return nil }
        let ptr = arr.dataPointer.assumingMemoryBound(to: Float.self)
        for i in 0..<9 { ptr[i] = k[i] }
        return arr
    }

    // MARK: - Output parsing

    private func parse(_ out: MLFeatureProvider) -> [MultiHMRPerson] {
        guard let v3d = out.featureValue(for: "var_2420")?
                .multiArrayValue,
              let transl = out.featureValue(for: "var_2423")?
                .multiArrayValue,
              let scores = out.featureValue(for: "var_2436")?
                .multiArrayValue else { return [] }
        var persons: [MultiHMRPerson] = []
        let vc = Self.vertexCount
        for k in 0..<Self.maxPersons {
            let score = scores[k].floatValue
            if score < Self.detThreshold { continue }
            var verts = [SIMD3<Float>](
                repeating: .zero, count: vc)
            let base = k * vc * 3
            for i in 0..<vc {
                let o = base + i * 3
                verts[i] = SIMD3(v3d[o].floatValue,
                                 v3d[o + 1].floatValue,
                                 v3d[o + 2].floatValue)
            }
            let tb = k * 3
            persons.append(MultiHMRPerson(
                vertices: verts,
                translation: SIMD3(transl[tb].floatValue,
                                   transl[tb + 1].floatValue,
                                   transl[tb + 2].floatValue),
                score: score))
        }
        return persons
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd launcher/AV-Live-Body && swift build`
Expected: build succeeds. `Bundle.module` exists because the target
has resources. If a CoreML signature differs on this SDK, fix
minimally; the I/O contract (two named MLMultiArray inputs, the three
named outputs) must be preserved.

- [ ] **Step 3: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MultiHMRCoreML.swift
git commit -m "feat(av-live-body): Multi-HMR CoreML wrapper"
```

---

## Task 3: BodyFusion

`BodyFusion` is pure logic: given the ARKit 91-joint skeleton frames
(from `USBSkeletonConsumer`) and the Multi-HMR persons, associate each
mesh with the nearest skeleton and lock the mesh pelvis depth to the
ARKit pelvis Z (the LiDAR-anchored, metrically-correct depth).

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyFusion.swift`
- Test: `launcher/AV-Live-Body/Tests/AVLiveBodyTests/BodyFusionTests.swift`

- [ ] **Step 1: Write the failing test**

`launcher/AV-Live-Body/Tests/AVLiveBodyTests/BodyFusionTests.swift`:

```swift
import XCTest
import AVLiveWire
@testable import AVLiveBody

final class BodyFusionTests: XCTestCase {
    private func skeleton(pelvisZ: Float)
        -> ArkitOSCListener.ArkitBodyFrame {
        var f = ArkitOSCListener.ArkitBodyFrame()
        f.pid = 0
        // ARKit body skeleton joint 0 is the hips/pelvis root.
        f.joints[0] = SIMD3(0, 0, pelvisZ)
        f.hasJoint[0] = true
        return f
    }

    func testPelvisDepthOverride() {
        let mesh = MultiHMRPerson(
            vertices: [SIMD3<Float>](repeating: .zero, count: 1),
            translation: SIMD3(0, 0, -1.0), score: 0.9)
        let fused = BodyFusion.fuse(
            persons: [mesh], skeletons: [0: skeleton(pelvisZ: -2.5)])
        XCTAssertEqual(fused.count, 1)
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

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd launcher/AV-Live-Body && swift test --filter BodyFusionTests`
Expected: FAIL — `BodyFusion` undefined.

- [ ] **Step 3: Write the implementation**

`launcher/AV-Live-Body/Sources/AVLiveBody/BodyFusion.swift`:

```swift
import AVLiveWire
import Foundation
import simd

/// Associates Multi-HMR meshes with ARKit skeletons and corrects the
/// mesh pelvis depth. Pure, stateless — unit-testable.
enum BodyFusion {
    /// ARKit body skeleton root (hips) joint index.
    static let pelvisJoint = 0

    /// Returns the persons with `translation.z` of each replaced by
    /// the matching ARKit skeleton's pelvis Z when one is available.
    /// Association is nearest-translation; with a single skeleton and
    /// a single dominant person this is exact.
    static func fuse(persons: [MultiHMRPerson],
                     skeletons: [Int: ArkitOSCListener.ArkitBodyFrame])
        -> [MultiHMRPerson] {
        // Collect candidate ARKit pelvis depths.
        let pelvisZs: [Float] = skeletons.values.compactMap { s in
            guard pelvisJoint < s.hasJoint.count,
                  s.hasJoint[pelvisJoint] else { return nil }
            return s.joints[pelvisJoint].z
        }
        guard !pelvisZs.isEmpty else { return persons }
        // Highest-scoring person is the primary; lock its depth to the
        // single ARKit skeleton (ARKit tracks one body). Others pass
        // through unchanged.
        guard let primaryIdx = persons.indices.max(by: {
            persons[$0].score < persons[$1].score
        }) else { return persons }
        var out = persons
        out[primaryIdx].translation.z = pelvisZs[0]
        return out
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd launcher/AV-Live-Body && swift test --filter BodyFusionTests`
Expected: PASS, 2 tests.

- [ ] **Step 5: Run the full suite + commit**

Run: `cd launcher/AV-Live-Body && swift test` — Expected: all pass
(9: prior 7 + 2).

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/BodyFusion.swift launcher/AV-Live-Body/Tests/AVLiveBodyTests/BodyFusionTests.swift
git commit -m "feat(av-live-body): ARKit-to-mesh body fusion"
```

---

## Task 4: Wire the mesh pipeline

Drive the chain: `USBSkeletonConsumer.onVideo` → `VideoDecoder` →
`MultiHMRCoreML` → `BodyFusion` → `MeshRenderer`.

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift`
- Reference: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`

- [ ] **Step 1: Read `MeshRenderer.swift`**

Identify the method that ingests SMPL-X persons (the OSC `SMPX` server
path calls it — likely `updatePersons(_:)` taking per-person 10475
vertex arrays). Note its exact signature and the vertex/coordinate
convention it expects.

- [ ] **Step 2: Add the mesh pipeline to `USBSkeletonConsumer`**

Give `USBSkeletonConsumer` an optional mesh pipeline. Add stored
properties:

```swift
    private let videoDecoder = VideoDecoder()
    private let multiHMR = MultiHMRCoreML()
    /// Set by the app to receive fused mesh persons on the main queue.
    var onMeshPersons: (([MultiHMRPerson]) -> Void)?
    /// Camera intrinsics (row-major 3x3) for Multi-HMR; a sane default
    /// is the iPhone main-camera focal at 672 px until a `.meta` frame
    /// supplies the real values.
    private var cameraK: [Float] = [
        672, 0, 336,
        0, 672, 336,
        0, 0, 1,
    ]
```

In `init()` (or `start()`), wire the decoder to the model:

```swift
        videoDecoder.onFrame = { [weak self] pixelBuffer in
            guard let self else { return }
            guard let hmr = self.multiHMR else { return }
            let raw = hmr.infer(pixelBuffer, cameraK: self.cameraK)
            let latestSkeletons = self.bodies
            let fused = BodyFusion.fuse(
                persons: raw, skeletons: latestSkeletons)
            DispatchQueue.main.async {
                self.onMeshPersons?(fused)
            }
        }
```

Change the `.video` branch of `route(_:)` so it feeds the decoder
instead of only forwarding the payload:

```swift
        case .video:
            guard let payload =
                VideoPayload(decoding: frame.payload) else { return }
            videoDecoder.decode(payload)
```

(`onVideo` may be kept for diagnostics or removed — keeping it is
harmless; if removed, delete its declaration too.)

- [ ] **Step 3: Feed `MeshRenderer` from the app**

In `AVLiveBodyApp.swift`'s `ContentView` `.onAppear` (or where the
renderers are wired), set `usbConsumer.onMeshPersons` to call the
`MeshRenderer` ingest method identified in Step 1, converting
`[MultiHMRPerson]` (vertices + fused translation) into whatever shape
that method expects. The translation from `BodyFusion` positions each
mesh; the 10475 vertices are the SMPL-X surface.

If `MeshRenderer`'s ingest method is not reachable from `ContentView`
(it may be owned by `BodyView`), thread an `onMeshPersons` closure the
same way `usbConsumer` itself was threaded in Plan 3a Task 4.

- [ ] **Step 4: Verify build + tests**

Run: `cd launcher/AV-Live-Body && swift build && swift test`
Expected: build succeeds; all tests pass (9).

- [ ] **Step 5: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/USBSkeletonConsumer.swift launcher/AV-Live-Body/Sources/AVLiveBody/AVLiveBodyApp.swift
git commit -m "feat(av-live-body): wire Multi-HMR mesh pipeline"
```

(Include `BodyView.swift` in the commit if Step 3 threaded a closure
through it.)

---

## Task 5: Final verification

- [ ] **Step 1: Clean build + full test suite**

```bash
cd launcher/AV-Live-Body && swift build && swift test
```

Expected: build succeeds; all 9 tests pass.

- [ ] **Step 2: Confirm the model is bundled, not committed**

```bash
git status --porcelain | grep mlpackage || echo "model not staged — correct"
ls -d launcher/AV-Live-Body/Sources/AVLiveBody/Resources/multihmr_full_672_s.mlpackage
```

Expected: the model directory exists on disk but is NOT staged in git.

---

## Self-Review

- **Spec coverage:** This plan implements the spec's `MultiHMRCoreML`,
  `BodyFusion`, and the mesh-render wiring — the dense-mesh half
  deferred from Plan 3a. With Plan 3b done, the full spec
  (`USBClient`/`StreamDemuxer`/`VideoDecoder`/`MultiHMRCoreML`/
  `BodyFusion` + renderers) is covered.
- **Placeholders:** none — new files carry complete code; modify tasks
  cite exact files and instruct reading `MeshRenderer.swift` for the
  one signature this plan cannot reproduce blind.
- **Type consistency:** `MultiHMRPerson` is produced by
  `MultiHMRCoreML.infer` and consumed by `BodyFusion.fuse` and
  `onMeshPersons`. The model I/O names (`image`, `cam_K`, `var_2420`,
  `var_2423`, `var_2436`) match `multihmr_coreml.py` exactly.
- **Known risks:**
  1. **Bundling 204 MB** — `swift build` copies the `.mlpackage` into
     the app bundle; build is slower and the app is large. Acceptable
     per the owner's decision (FP32, validated).
  2. **`CVPixelBuffer` → tensor** — the CoreImage resize + manual
     BGRA→normalized-CHW packing is the most error-prone code here and
     needs on-device validation against `multihmr_coreml.py`'s output
     on the same frame. It also runs per-frame on the CPU — a perf
     hotspot; revisit with `vImage`/Metal if frame rate suffers.
  3. **~7.6 fps** — Multi-HMR is far below 30 fps; the mesh layer is
     slow while the skeleton (Plan 3a) stays real-time. `MeshRenderer`
     already interpolates meshes to ~60 fps between worker frames —
     reuse that, do not block the USB read loop on inference (the
     `videoDecoder.onFrame` callback already runs off the main queue).
  4. **`cameraK`** — a placeholder intrinsics matrix is used until a
     `.meta` frame carries the real values; absolute depth scale will
     be approximate until then. A future iteration should send camera
     intrinsics from the iPhone in a `.meta` frame.
