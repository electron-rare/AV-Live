# Design — AVLiveBody: hand/face capture over AVLiveWire + port the archived viz UI

**Date:** 2026-06-26
**Status:** Approved (brainstorming) — ready for implementation plan
**Base app:** `avlivebody-mac/` (B, iPhone-USB / ARKit, the keeper)
**UI source:** `launcher/_archive-AV-Live-Body/` (A, archived, richer UI)

## 1. Goal

Two coupled outcomes:
1. **Capture hands and face on the iPhone** and stream them to the Mac over
   AVLiveWire, so the Mac has body + hands + face (not just the 91-joint ARKit
   body it has today).
2. **Port the archived app's advanced viz UI** into `avlivebody-mac` (settings
   panel + layer toggles, 3 lights + mesh material, 10 Metal shader background
   modes), now able to use the real hand/face data for full shader reactivity
   and 3D hand/face skeletons.

B keeps its modern transport (iPhone ARKit over usbmux, off-main Multi-HMR,
orbital camera). A has ~2345 LOC of UI vs B's ~236; A's richness was OSC-driven,
so we re-source it from the iPhone stream.

## 2. Non-goals

- No `ARFaceTrackingConfiguration` (TrueDepth front camera; cannot run with the
  rear-camera `ARBodyTrackingConfiguration`). Face comes from Vision on the AR
  rear-camera frames.
- No Mac-side detection of hands/face (capture stays on the iPhone, per choice).
- No multi-person association of face/hands to body PID in v1 — Vision detections
  are sent ungrouped; the UI uses the most prominent for shader scalars
  (association is a later refinement).
- No HUD overlay, no keyboard shortcuts (viz-mode switching lives in the panel).
- No 2D Canvas overlays; no AVCapture preview layer (B uses the iPhone video 3D
  quad).
- No deletion of the archive.

## 3. Architecture

### 3.1 Data pipeline (Phase 0)
```
iPhone ARBodyTracker
  ├─ ARBodyTrackingConfiguration  → 91-joint skeleton  (AVLiveWire tag=1, exists)
  ├─ HEVC encode                  → video              (tag=2, exists)
  ├─ Vision VNDetectHumanHandPose on ARFrame.capturedImage → hands  (tag=3, NEW)
  └─ Vision VNDetectFaceLandmarks  on ARFrame.capturedImage → face   (tag=4, NEW)
        (both throttled, off the main thread; rear camera, same frames as body)
                       │  usbmux TCP :7000, AVLiveWire framing
                       ▼
Mac avlivebody-mac USBSkeletonConsumer
  routes tag=1/2 (existing) + tag=3 hands + tag=4 face
  → @Published hands, @Published face  → UI (skeleton + shader uniforms)
```

### 3.2 Render compositing (Phase 1/2) — port A's layered model
```
NSView container
 ├─ back : MTKView running scene.metal (10 modes), isOpaque=false   [Phase 2]
 └─ front: ARView (transparent) = B's SceneController content
            (skeleton + mesh + iPhone video 3D quad) + 3 lights      [Phase 1]
```
A `RenderSettings` ObservableObject is the single UI-state source; a SwiftUI
`SettingsPanel` (right, collapsible) binds to it; the container/controller
applies changes to layers and entities.

## 4. Phase 0 — hands + face over AVLiveWire (prerequisite)

### 4.1 iPhone capture (`iphone-arbody/`)
- In the AR session delegate (`ARBodySession.swift`), on each `ARFrame` (throttled
  to ~15 fps, separate from the 30 fps body cap), run on a background queue:
  - `VNDetectHumanHandPoseRequest` (maximumHandCount = 2) on `frame.capturedImage`.
  - `VNDetectFaceLandmarksRequest` on the same buffer (cap to 1 face = most
    prominent in v1).
- Convert Vision points to **normalized image coordinates** (0–1) before sending.
- Off-main; never block the AR/encode/send path. If a Vision pass is still running,
  drop the frame (same drop-if-busy discipline as the Multi-HMR fix).

### 4.2 AVLiveWire protocol (`shared/AVLiveWire/`)
Add to `FrameTag`: `hands = 3`, `face = 4` (`FrameHeader.swift`). Framing
unchanged (19-byte header). New payload codecs in `WirePayloads.swift`:
- **HandsPayload (tag=3):** `nHands: u8` then per hand
  `chirality: u8 (0=left,1=right) + 21 × (x: f32, y: f32, c: f32)`.
- **FacePayload (tag=4):** `confidence: f32 + nPoints: u16` then
  `nPoints × (x: f32, y: f32)` (Vision `allPoints`, ~76, normalized image coords).
- Roundtrip encode/decode unit tests in `AVLiveWireTests` (mirror the existing
  `SkeletonPayload`/`VideoPayload` tests). `StreamDemuxer` already yields frames
  by tag — only the new tags + payloads are added.

### 4.3 Mac consumer (`avlivebody-mac/.../usb/USBSkeletonConsumer.swift`)
`route(_:)` gains `case .hands` / `case .face`, decoding to:
- `@Published hands: [HandLandmarks]` (chirality + 21 normalized points)
- `@Published face: FaceLandmarks?` (normalized points + confidence)
Published writes hop to main like `skeletons`.

## 5. Phase 1 — control surface (RealityKit side, no Metal)

(Adapted from A; lower-risk, fixes B's unlit scene, hosts the viz picker.)

- **`RenderSettings`** (new): `showSkeleton/showMesh/showVideo/showWireframe`,
  `metallic`, `roughness` (0–1, def 0.6), `videoOpacity` (0–1), `keyIntensity`/
  `fillIntensity`/`rimIntensity` (0–10000), `fov` (20–120, def 55),
  `backgroundBrightness`, `showPanel`. (Phase 2 adds `showScene`, `vizMode` 0–9,
  and per-channel skeleton toggles for hands/face.)
- **`SettingsPanel`** (new, port A's): sections Couches / Mesh / Lumières / Vue.
- **3 DirectionalLights** (key/fill/rim) in `SceneController` + intensity sliders.
- **Mesh material + wireframe** on `MeshEntity` (metallic/roughness + wireframe
  index set à la A's `MeshRenderer`).
- **`SceneController`** gains: `setSkeletonVisible/setMeshVisible/setVideoVisible/
  setVideoOpacity/setWireframe/updateMeshMaterial/setLightIntensities/setFOV`.

## 6. Phase 2 — Metal shader backgrounds + hand/face skeleton

- Copy `scene.metal` from `_archive .../Resources/scene.metal` into B's bundle
  (offline-compilable: `xcrun -sdk macosx metal -c`).
- Port A's `SceneRenderer.swift` (MTKView delegate + uniform buffer). MTKView is
  the transparent back layer behind the transparent ARView.
- Viz-mode picker (0–9) + Scene on/off in the panel → `RenderSettings`.
- **3D hand + face skeleton** in the ARView (un-deferred): render the Vision hand
  (21 pts/hand + finger bones) and face (landmark points) from
  `consumer.hands`/`consumer.face`, placed at the body's depth (2D landmarks →
  depth borrowed from the ARKit pelvis), toggled in the panel.

### 6.1 `SceneUniforms` (36 floats / 144 B) — feed from the iPhone stream
| Uniform | Source in B | Notes |
|---|---|---|
| `time`, `width`, `height`, `viz_mode` | clock / drawable size / panel | |
| `pose_alive`, `pose_count` | skeleton presence/count | |
| `hand_l_x/y`, `hand_r_x/y` | **Vision hands** (centroid/wrist, norm) | tag=3 |
| `finger_pinch_l/r` | **Vision hands** dist(thumbTip,indexTip) norm | tag=3 |
| `mouth_open` | **Vision face** outer/inner lips vertical gap / face H | tag=4 |
| `eye_open_l/r` | **Vision face** eye region aspect ratio | tag=4 |
| `head_tilt` | **Vision face** atan2 between eye centers | or ARKit head |
| `head_yaw` | **Vision face** nose vs eye-midpoint offset | or ARKit head |
| `body_x/y/z`, `body_height`, `arm_spread` | ARKit body joints | tag=1 |
| `pose_velocity` | EMA(\|pelvis(t)−pelvis(t−1)\|), α=0.3 | tag=1 |
| `rms`, `kp_norm`, `netz_dev`, `lightning_flash`, `flare`, `wind_norm`, `bz_norm`, `social_rate` | **0 (neutral)** | data_only_viz OSC feeds, absent here |
| `_pad0.._pad4` | 0 | |

EMA-smooth derivatives (α≈0.3). B's Swift `SceneUniforms` field order MUST match
`scene.metal` exactly (36 floats, stride 144).

## 7. Limitation (assumed)

- Vision landmarks are **2D** → hand/face skeletons are placed at the body's
  depth (no true 3D for hands/face).
- **Data-feed** shader channels (Schumann/weather/seismic…) stay neutral (those
  come from `data_only_viz`'s OSC bridge, not the iPhone).
- **Multi-person**: hand/face not associated to body PID in v1 (most-prominent
  used for shader scalars).
- **iPhone budget**: body tracking + HEVC encode + 2 Vision passes is heavy →
  hands/face throttled (~15 fps) with drop-if-busy; tune on-device.

## 8. Testing

- **AVLiveWire** (Phase 0): encode/decode roundtrip unit tests for HandsPayload
  and FacePayload; demuxer recognizes tag=3/4. (`AVLiveWireTests`, existing suite
  is green.)
- **iPhone** (Phase 0): builds + deploys; on-device, confirm tag=3/4 frames reach
  the Mac (a listener prints hand/face counts).
- **Mac consumer** (Phase 0): unit-test `route` dispatches tag=3/4 to the right
  decoder with a fabricated frame.
- **Phase 1**: `RenderSettings` defaults; wireframe-index generation (pure fn);
  build; manual — toggles, lights, material visibly work.
- **Phase 2**: `xcrun metal -c scene.metal` exit 0; `SceneUniforms` layout-guard
  test (`MemoryLayout.stride == 144`, field order matches shader); build; manual —
  modes 0–9 render, body/hand/face movement modulates the scene.

Live audio/visual confirmation is the user's (needs display + iPhone + a body).

## 9. File structure

| File | Action | Responsibility |
|---|---|---|
| `shared/AVLiveWire/Sources/AVLiveWire/FrameHeader.swift` | Modify | add `hands=3`, `face=4` to `FrameTag` |
| `shared/AVLiveWire/Sources/AVLiveWire/WirePayloads.swift` | Modify | `HandsPayload`, `FacePayload` codecs |
| `shared/AVLiveWire/Tests/...` | Modify | roundtrip tests |
| `iphone-arbody/.../ARBodySession.swift` | Modify | Vision hand+face on AR frames, throttled, off-main; send tag=3/4 |
| `avlivebody-mac/.../usb/USBSkeletonConsumer.swift` | Modify | route tag=3/4 → `@Published hands/face` |
| `avlivebody-mac/.../RenderSettings.swift` | Create | UI state |
| `avlivebody-mac/.../SettingsPanel.swift` | Create | control panel |
| `avlivebody-mac/.../AVLiveBodyApp.swift` | Modify | ContentView: container + panel; own RenderSettings |
| `avlivebody-mac/.../SceneView.swift` | Modify | layered NSView container (MTKView + ARView) |
| `avlivebody-mac/.../SceneController.swift` | Modify | toggles, lights, material/FOV; hand/face skeleton |
| `avlivebody-mac/.../MeshEntity.swift` | Modify | metallic/roughness + wireframe |
| `avlivebody-mac/.../SceneRenderer.swift` | Create (port A) | MTKView Metal renderer |
| `avlivebody-mac/.../Resources/scene.metal` | Create (copy A) | shader |
| `avlivebody-mac/project.yml` | Modify | bundle scene.metal; MetalKit |

## 10. Anchors (port-from / modify)

| Concern | Archive / existing | New / modify |
|---|---|---|
| AVLiveWire tags/framing | `shared/AVLiveWire/.../FrameHeader.swift` (FrameTag, magic AVL1, 19 B) | add tags + payloads |
| iPhone AR session | `iphone-arbody/.../ARBodySession.swift` | add Vision hand/face |
| Mac consumer | `avlivebody-mac/.../usb/USBSkeletonConsumer.swift` (route by tag) | tag=3/4 |
| Layered compositing | `_archive .../BodyView.swift:23-63` | `SceneView.swift` |
| Settings state/panel | `_archive .../RenderSettings.swift`, `SettingsPanel.swift` | new files |
| Lights | `_archive .../BodyView.swift:72-91` | `SceneController.swift` |
| Mesh material/wireframe | `_archive .../MeshRenderer.swift:94-109` | `MeshEntity.swift` |
| Metal renderer/shader | `_archive .../SceneRenderer.swift`, `Resources/scene.metal` (SceneUniforms 36 f) | new + copy |
| Skeleton/hand/face render | `_archive .../Skeleton3DRenderer.swift` | `SceneController`/`SkeletonEntity` |

## 11. Sequencing

**Phase 0** (hands+face over AVLiveWire) first — independently testable, enables
the rest. **Phase 1** (panel/lights/material) — self-contained, no Metal risk.
**Phase 2** (shader modes + hand/face skeleton) — consumes Phase 0 data + Phase 1
panel. Each phase is independently buildable and testable; each gets its own
implementation plan.
