# AVLiveBody Phase 1 — Settings panel + lights + mesh material (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `avlivebody-mac` an interactive control surface: a `RenderSettings` state object, a SwiftUI settings panel, 3 directional lights (the scene is currently unlit/black), live mesh material (metallic/roughness), camera FOV, and show/hide toggles for skeleton/mesh/video.

**Architecture:** Port the archived app's `RenderSettings` + `SettingsPanel` pattern into B, adapted to B's RealityKit `SceneController`. `RenderSettings` (ObservableObject) is the single UI-state source; `ContentView` overlays the panel in a `ZStack` and pushes changes to `SceneController` via `.onReceive`/`.onChange`; `SceneController` applies them to its entities (lights, mesh material, visibility, camera FOV).

**Tech Stack:** Swift, SwiftUI, RealityKit, Xcode project (avlivebody-mac, macOS 15).

## Global Constraints

- Base app `avlivebody-mac/` is an xcodegen Xcode project; build/test with `xcodebuild` (scheme `AVLiveBody`, configuration Debug). It is unsigned (`CODE_SIGNING_ALLOWED=NO`).
- `SceneController`, `MeshEntity`, `SkeletonEntity`, `VideoQuad` are all `@MainActor`. UI runs on the main actor.
- ARKit→RealityKit coordinate mapping is the existing `arkitToRealityKit` helper — do not change it.
- No emojis. Commit subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no `--no-verify`, no underscore in commit scope (use hyphens).
- French labels in user-facing panel text (matches the archive); code/comments in English.
- Branch: `main` (trunk-based).
- SourceKit single-file diagnostics are noise; the whole-module `xcodebuild` result is the source of truth.

### Scope note (vs spec §5)
**Wireframe is deferred to Phase 2.** RealityKit `MeshDescriptor` has no reliable line primitive; a correct wireframe needs a custom mesh/material technique best built alongside the Phase 2 Metal work. Phase 1 ships metallic/roughness + visibility + lights + FOV (all certain). `showWireframe` is NOT added to `RenderSettings` here.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift` | Create | `@Published` UI state |
| `avlivebody-mac/Tests/AVLiveBodyTests/RenderSettingsTests.swift` | Create | default-value test |
| `avlivebody-mac/Sources/AVLiveBody/SceneController.swift` | Modify | 3 lights + apply methods (visibility/material/FOV/light) |
| `avlivebody-mac/Sources/AVLiveBody/MeshEntity.swift` | Modify | mutable material + `setMaterial`/`setVisible` |
| `avlivebody-mac/Sources/AVLiveBody/SkeletonEntity.swift` | Modify | `setVisible` |
| `avlivebody-mac/Sources/AVLiveBody/VideoQuad.swift` | Modify | `setVisible`/`setOpacity` |
| `avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift` | Create | SwiftUI control panel |
| `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift` | Modify | own RenderSettings; ZStack panel; push to controller |

---

## Task 1: RenderSettings state object

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift`
- Test: `avlivebody-mac/Tests/AVLiveBodyTests/RenderSettingsTests.swift`

**Interfaces:**
- Produces: `@MainActor final class RenderSettings: ObservableObject` with `@Published`:
  `showSkeleton: Bool`, `showMesh: Bool`, `showVideo: Bool`, `meshMetallic: Bool`,
  `meshRoughness: Double`, `videoOpacity: Double`, `keyIntensity: Double`,
  `fillIntensity: Double`, `rimIntensity: Double`, `fieldOfView: Double`,
  `showPanel: Bool`.

- [ ] **Step 1: Write the failing test**

```swift
// avlivebody-mac/Tests/AVLiveBodyTests/RenderSettingsTests.swift
import XCTest
@testable import AVLiveBody

@MainActor
final class RenderSettingsTests: XCTestCase {
    func testDefaults() {
        let s = RenderSettings()
        XCTAssertTrue(s.showSkeleton)
        XCTAssertTrue(s.showMesh)
        XCTAssertTrue(s.showVideo)
        XCTAssertFalse(s.meshMetallic)
        XCTAssertEqual(s.meshRoughness, 0.6, accuracy: 1e-9)
        XCTAssertEqual(s.videoOpacity, 1.0, accuracy: 1e-9)
        XCTAssertEqual(s.keyIntensity, 4000, accuracy: 1e-9)
        XCTAssertEqual(s.fillIntensity, 1500, accuracy: 1e-9)
        XCTAssertEqual(s.rimIntensity, 2000, accuracy: 1e-9)
        XCTAssertEqual(s.fieldOfView, 55, accuracy: 1e-9)
        XCTAssertFalse(s.showPanel)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && \
xcodebuild test -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' 2>&1 | grep -E "error:|Cannot find 'RenderSettings'|Test Suite.*(passed|failed)|** TEST"
```
Expected: FAIL — `Cannot find 'RenderSettings' in scope`.

- [ ] **Step 3: Create RenderSettings**

```swift
// avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift
import SwiftUI

/// Live visual settings for AVLiveBody. ContentView observes this and
/// pushes changes to SceneController. Defaults chosen so the scene is
/// lit and everything visible out of the box.
@MainActor
final class RenderSettings: ObservableObject {
    // Layer visibility
    @Published var showSkeleton: Bool = true
    @Published var showMesh: Bool = true
    @Published var showVideo: Bool = true

    // Mesh material
    @Published var meshMetallic: Bool = false
    @Published var meshRoughness: Double = 0.6

    // Video quad
    @Published var videoOpacity: Double = 1.0

    // Lights (RealityKit DirectionalLight intensities)
    @Published var keyIntensity: Double = 4000
    @Published var fillIntensity: Double = 1500
    @Published var rimIntensity: Double = 2000

    // Camera
    @Published var fieldOfView: Double = 55

    // Panel visibility
    @Published var showPanel: Bool = false
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && \
xcodebuild test -project AVLiveBody.xcodeproj -scheme AVLiveBody \
  -destination 'platform=macOS' 2>&1 | grep -E "error:|Test Suite 'RenderSettingsTests'|** TEST"
```
Expected: `Test Suite 'RenderSettingsTests' ... passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/RenderSettings.swift \
        avlivebody-mac/Tests/AVLiveBodyTests/RenderSettingsTests.swift
git commit -m "feat(avlivebody): render settings state object"
```

---

## Task 2: SceneController apply methods (lights, material, visibility, FOV)

**Files:**
- Modify: `avlivebody-mac/Sources/AVLiveBody/SceneController.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/MeshEntity.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/SkeletonEntity.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/VideoQuad.swift`

**Interfaces:**
- Consumes: `RenderSettings` values (Task 1).
- Produces on `SceneController`:
  `setSkeletonVisible(_: Bool)`, `setMeshVisible(_: Bool)`, `setVideoVisible(_: Bool)`,
  `setVideoOpacity(_: Double)`, `updateMeshMaterial(metallic: Bool, roughness: Double)`,
  `setLightIntensities(key: Double, fill: Double, rim: Double)`, `setFieldOfView(_: Double)`.
  On `MeshEntity`: `setVisible(_: Bool)`, `setMaterial(metallic: Bool, roughness: Double)`.
  On `SkeletonEntity`: `setVisible(_: Bool)`. On `VideoQuad`: `setVisible(_: Bool)`, `setOpacity(_: Double)`.

- [ ] **Step 1: Add visibility/opacity to the entities**

In `MeshEntity.swift`, change the material from `let` to `var` and add methods (place after `update(_:)`):

```swift
    func setVisible(_ visible: Bool) { root.isEnabled = visible }

    func setMaterial(metallic: Bool, roughness: Double) {
        material = SimpleMaterial(
            color: NSColor(white: 0.8, alpha: 1.0),
            roughness: .float(Float(roughness)), isMetallic: metallic)
        for entity in pools.values {
            entity.model?.materials = [material]
        }
    }
```

Change the property declaration from:
```swift
    private let material = SimpleMaterial(
        color: NSColor(white: 0.8, alpha: 1.0),
        roughness: 0.5, isMetallic: false)
```
to:
```swift
    private var material = SimpleMaterial(
        color: NSColor(white: 0.8, alpha: 1.0),
        roughness: 0.5, isMetallic: false)
```

In `SkeletonEntity.swift`, add:
```swift
    func setVisible(_ visible: Bool) { root.isEnabled = visible }
```

In `VideoQuad.swift`, add (the quad uses `UnlitMaterial`; opacity via tint alpha — note the texture is re-applied every frame in `update`, so store the opacity and apply it there too):

```swift
    private var opacity: Double = 1.0

    func setVisible(_ visible: Bool) { entity.isEnabled = visible }

    func setOpacity(_ value: Double) {
        opacity = value
        // Re-tint current material; `update(_:)` will also use `opacity`.
        if var mat = entity.model?.materials.first as? UnlitMaterial {
            mat.color = .init(tint: NSColor(white: 1, alpha: CGFloat(value)))
            entity.model?.materials = [mat]
        }
    }
```
And in `VideoQuad.update(_:)`, change the tint to carry `opacity`:
```swift
        material.color = .init(
            tint: NSColor(white: 1, alpha: CGFloat(opacity)),
            texture: .init(texture))
```

- [ ] **Step 2: Add the 3 lights in SceneController.setUp()**

Add stored properties to `SceneController` (near the other `private let` anchors):
```swift
    private let keyLight = DirectionalLight()
    private let fillLight = DirectionalLight()
    private let rimLight = DirectionalLight()
```

In `setUp()`, after `arView.scene.addAnchor(worldAnchor)`, add (ported from the archive's 3-light rig):
```swift
        keyLight.light.intensity = 4000
        keyLight.orientation = simd_quatf(angle: .pi / 6,
                                          axis: SIMD3(1, 0, 0))
        let keyA = AnchorEntity(world: SIMD3<Float>(1, 2, -1))
        keyA.addChild(keyLight)
        arView.scene.addAnchor(keyA)

        fillLight.light.intensity = 1500
        fillLight.light.color = NSColor(red: 0.7, green: 0.8,
                                        blue: 1.0, alpha: 1.0)
        let fillA = AnchorEntity(world: SIMD3<Float>(-2, 1, -2))
        fillA.addChild(fillLight)
        arView.scene.addAnchor(fillA)

        rimLight.light.intensity = 2000
        let rimA = AnchorEntity(world: SIMD3<Float>(0, 1, -5))
        rimA.addChild(rimLight)
        arView.scene.addAnchor(rimA)
```

- [ ] **Step 3: Add the apply methods to SceneController**

Add (after `updateMesh(_:)`):
```swift
    func setSkeletonVisible(_ v: Bool) { skeleton?.setVisible(v) }
    func setMeshVisible(_ v: Bool) { mesh?.setVisible(v) }
    func setVideoVisible(_ v: Bool) { videoQuad?.setVisible(v) }
    func setVideoOpacity(_ v: Double) { videoQuad?.setOpacity(v) }

    func updateMeshMaterial(metallic: Bool, roughness: Double) {
        mesh?.setMaterial(metallic: metallic, roughness: roughness)
    }

    func setLightIntensities(key: Double, fill: Double, rim: Double) {
        keyLight.light.intensity = Float(key)
        fillLight.light.intensity = Float(fill)
        rimLight.light.intensity = Float(rim)
    }

    func setFieldOfView(_ deg: Double) {
        camera.camera.fieldOfViewInDegrees = Float(deg)
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/avbody-dd" && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody -configuration Debug \
  -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines. (If `SimpleMaterial` roughness init rejects `.float(...)`, use the scalar form `roughness: MaterialScalarParameter(floatLiteral: Float(roughness))` — but `.float(_)` is the standard `MaterialScalarParameter` case.)

- [ ] **Step 5: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/SceneController.swift \
        avlivebody-mac/Sources/AVLiveBody/MeshEntity.swift \
        avlivebody-mac/Sources/AVLiveBody/SkeletonEntity.swift \
        avlivebody-mac/Sources/AVLiveBody/VideoQuad.swift
git commit -m "feat(avlivebody): lights material and visibility apply"
```

---

## Task 3: Settings panel + ContentView wiring

**Files:**
- Create: `avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift`
- Modify: `avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift`

**Interfaces:**
- Consumes: `RenderSettings` (Task 1), `SceneController` apply methods (Task 2).
- Produces: a `SettingsPanel` SwiftUI view bound to `RenderSettings`; `ContentView` owns a `@StateObject RenderSettings`, overlays the panel, and pushes every change to the controller.

- [ ] **Step 1: Create the SettingsPanel view**

```swift
// avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift
import SwiftUI

/// Collapsible right-side control panel bound to RenderSettings.
struct SettingsPanel: View {
    @ObservedObject var settings: RenderSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reglages").font(.headline)

                group("Couches") {
                    Toggle("Squelette", isOn: $settings.showSkeleton)
                    Toggle("Mesh", isOn: $settings.showMesh)
                    Toggle("Video", isOn: $settings.showVideo)
                }

                group("Mesh") {
                    Toggle("Metallique", isOn: $settings.meshMetallic)
                    slider("Rugosite", $settings.meshRoughness,
                           0...1)
                }

                group("Lumieres") {
                    slider("Principale", $settings.keyIntensity,
                           0...10000)
                    slider("Remplissage", $settings.fillIntensity,
                           0...10000)
                    slider("Contre-jour", $settings.rimIntensity,
                           0...10000)
                }

                group("Vue") {
                    slider("Champ de vision", $settings.fieldOfView,
                           20...120)
                    slider("Opacite video", $settings.videoOpacity,
                           0...1)
                }
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func group(_ title: String,
                       @ViewBuilder _ content: () -> some View)
        -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }

    private func slider(_ label: String,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
```

- [ ] **Step 2: Wire RenderSettings + panel into ContentView**

In `AVLiveBodyApp.swift` `ContentView`, add the settings object and overlay. Add the property:
```swift
    @StateObject private var settings = RenderSettings()
```
Replace the `body` with (keeps existing SceneView + StatusBar; adds a panel toggle button and the panel; pushes settings to the controller via `applyAll` on appear/change):
```swift
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SceneView(controller: controller)
            StatusBar(consumer: consumer)
                .frame(maxWidth: .infinity, alignment: .top)
            HStack(alignment: .top) {
                Spacer()
                if settings.showPanel {
                    SettingsPanel(settings: settings)
                        .transition(.move(edge: .trailing))
                }
                Button {
                    withAnimation { settings.showPanel.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .padding(8)
            }
        }
        .onAppear { wire(); applyAll() }
        .onDisappear { consumer.stop() }
        .onReceive(consumer.$skeletons) { skeletons in
            controller.updateSkeleton(skeletons)
        }
        .onReceive(settings.objectWillChange) { _ in
            // objectWillChange fires before the value updates; apply on
            // the next runloop tick so we read the new values.
            DispatchQueue.main.async { applyAll() }
        }
    }

    private func applyAll() {
        controller.setSkeletonVisible(settings.showSkeleton)
        controller.setMeshVisible(settings.showMesh)
        controller.setVideoVisible(settings.showVideo)
        controller.setVideoOpacity(settings.videoOpacity)
        controller.updateMeshMaterial(metallic: settings.meshMetallic,
                                      roughness: settings.meshRoughness)
        controller.setLightIntensities(key: settings.keyIntensity,
                                       fill: settings.fillIntensity,
                                       rim: settings.rimIntensity)
        controller.setFieldOfView(settings.fieldOfView)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/avlivebody-mac" && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/avbody-dd" && \
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody -configuration Debug \
  -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines.

- [ ] **Step 4: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add avlivebody-mac/Sources/AVLiveBody/SettingsPanel.swift \
        avlivebody-mac/Sources/AVLiveBody/AVLiveBodyApp.swift
git commit -m "feat(avlivebody): settings panel and wiring"
```

- [ ] **Step 5: Manual visual check (user)**

Launch the built `.app`. Click the slider button → panel slides in. Toggle Squelette/Mesh/Video → entities show/hide. Move the light sliders → the scene lighting changes (it was black/unlit before). Change Rugosite/Metallique → the mesh material updates (when a mesh is present, i.e. `AVBODY_MULTIHMR=1`). Change Champ de vision → camera zoom changes. This visual confirmation is the user's.

---

## Self-Review notes

- **Spec coverage (§5):** RenderSettings → Task 1; SettingsPanel → Task 3; 3 lights + intensity → Task 2; mesh material → Task 2; SceneController apply methods → Task 2; ContentView ZStack + panel → Task 3. **Wireframe deferred to Phase 2** (RealityKit line-primitive limitation) — documented in the scope note.
- **Type consistency:** apply methods named identically in Task 2 (definitions) and Task 3 (calls): `setSkeletonVisible/setMeshVisible/setVideoVisible/setVideoOpacity/updateMeshMaterial/setLightIntensities/setFieldOfView`. `RenderSettings` field names identical across tasks.
- **Placeholder scan:** none; the `.float(...)` fallback note in Task 2 Step 4 is a concrete alternative, not a placeholder.
- **Out of scope (Phase 2):** wireframe, Metal shader modes + viz picker, 3D hand/face skeleton, `showScene`/`vizMode` settings.
