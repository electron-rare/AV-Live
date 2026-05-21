# AVLiveBody macOS — Clean Rewrite Design

> **Status:** design approved (brainstorming), pending implementation plan.
> **Date:** 2026-05-18

## Goal

Rebuild the macOS `AVLiveBody` app from scratch as a clean, native
Xcode application focused solely on the iPhone-USB body pipeline:
display the iPhone camera video and the tracked body (91-joint
skeleton + SMPL-X mesh) in a single RealityKit 3D scene. Drop all the
legacy components that have made incremental work fragile.

## Motivation

The existing `launcher/AV-Live-Body` is a SwiftPM package carrying
years of unrelated functionality — MediaPipe OSC listeners, openFrame-
works-style Metal "viz mode" scenes, a data-feeds HUD, a 33-joint
MediaPipe skeleton renderer, Mac-webcam capture, viz-mode hotkeys, a
multi-layer `BodyView`. Bolting the iPhone-USB pipeline onto it caused
recurring friction: the skeleton render tick was coupled to the
MediaPipe publisher, the app could not take keyboard focus when run as
a bare SwiftPM executable, the camera defaulted to the Mac webcam. A
clean, purpose-built app removes that whole class of problems.

## Decisions (brainstorming outcomes)

1. **Fresh native macOS app, Xcode project**, xcodegen-managed
   (`project.yml` → `.xcodeproj`, matching the `iphone-arbody` iOS
   app). New directory `avlivebody-mac/` in the AV-Live monorepo. The
   old `launcher/AV-Live-Body/` is archived.
2. **Reuse the clean USB pipeline** built previously — the
   `AVLiveWire` package plus `USBMuxProtocol`, `USBClient`,
   `UnixMuxTransport`, `VideoDecoder`, `USBSkeletonConsumer`,
   `MultiHMRCoreML`, `BodyFusion`. These migrate into the new app
   unchanged (they are tested and reviewed).
3. **Rendering: a single RealityKit 3D scene** — the iPhone video is a
   texture on a quad at the back of the scene; the body (skeleton +
   mesh) is in front; an orbitable camera.
4. **Drop all legacy** — MediaPipe OSC listeners, the `SceneRenderer`
   Metal viz modes, `DataFeedsOSCListener` + HUD, the 33-joint
   `Skeleton3DRenderer`, Mac-webcam capture, viz-mode hotkeys, the
   layered `BodyView`, `PoseOSCListener`.
5. Built as a proper `.app` via Xcode, which resolves the keyboard-
   focus problem that affected the `swift run` executable.

## Architecture

A SwiftUI `@main App` with one window. An `AppDelegate` sets
`NSApplication` activation policy to `.regular`. The window hosts one
RealityKit `ARView` (used purely as a general 3D view on macOS — no
ARKit). The `ARView` holds a single scene containing:

- a **video quad** — a flat plane entity at the back, its material
  texture replaced from each decoded iPhone `CVPixelBuffer`;
- the **body** — 91 skeleton joint markers and the dense SMPL-X mesh,
  positioned in front of the video quad;
- an **orbitable camera**.

The USB pipeline (reused components) feeds the scene. The app is a
strict consumer: no network, the only input is the USB cable.

## Components

### Reused — the USB pipeline (migrated unchanged)

| Unit | Responsibility |
|------|----------------|
| `AVLiveWire` (SwiftPM package, stays in `shared/`) | 19-byte frame format, `FrameHeader`/`FrameTag`, `SkeletonPayload`/`VideoPayload`, `StreamDemuxer` |
| `USBMuxProtocol` | usbmux 16-byte-header + plist codec |
| `USBClient` / `MuxTransport` / `UnixMuxTransport` | usbmux device discovery, connect, `AF_UNIX` socket |
| `VideoDecoder` | HEVC `VideoPayload` → `CVPixelBuffer` (`VTDecompressionSession`) |
| `USBSkeletonConsumer` | background USB read loop → `StreamDemuxer`; republishes `.skeleton` body frames + decoded `.video` pixel buffers; auto-reconnect |
| `MultiHMRCoreML` | bundled CoreML model → N SMPL-X persons |
| `BodyFusion` | associate ARKit skeleton ↔ Multi-HMR person, pelvis-depth correction |

These move from `launcher/AV-Live-Body/Sources/AVLiveBody/` into the
new app's source tree. `AVLiveWire` stays in `shared/AVLiveWire`; the
new app declares it as a local package dependency.

### New — rendering (clean, zero legacy)

| Unit | Responsibility |
|------|----------------|
| `AVLiveBodyApp` | `@main` SwiftUI `App`; `AppDelegate` forces `.regular` activation; one window |
| `SceneView` | `NSViewRepresentable` wrapping the RealityKit `ARView` |
| `SceneController` | owns the scene, the orbital camera, assembles the entities; exposes `updateSkeleton`, `updateMesh`, `updateVideo` |
| `VideoQuad` | the back plane entity; updates its `TextureResource` from a `CVPixelBuffer` per frame |
| `SkeletonEntity` | 91 joint marker entities (native 91-joint, no MediaPipe 33-joint schema) |
| `MeshEntity` | the SMPL-X mesh entity (10475 vertices); mesh-building logic cleanly adapted from the old `MeshRenderer` |
| `StatusBar` | a small SwiftUI overlay showing connection state from `USBSkeletonConsumer.connected` |

## Data flow

```
iPhone ──USB── UnixMuxTransport → USBClient → StreamDemuxer → USBSkeletonConsumer
                                                    ├─ .skeleton → SceneController.updateSkeleton → SkeletonEntity
                                                    └─ .video → VideoDecoder → CVPixelBuffer ─┬─ SceneController.updateVideo → VideoQuad
                                                                                              └─ MultiHMRCoreML → BodyFusion → SceneController.updateMesh → MeshEntity
```

Two rates: the skeleton streams at ~30 fps (smooth markers); video and
Multi-HMR run slower (~7 fps for the mesh). The video quad texture
refreshes at the video frame rate.

## Error handling

- **USB disconnect / no iPhone** — `USBSkeletonConsumer` retries every
  second; `StatusBar` shows "waiting for iPhone".
- **CoreML model absent or failing** — the app runs skeleton-only (no
  mesh); not a fatal error.
- **Video decode failure** — the frame is skipped.
- **Reconnect** — handled by the consumer's loop; entities holding
  stale data are cleared after a timeout.

## Testing

- The reused USB components keep their existing unit tests
  (`AVLiveWireTests`, `USBMuxProtocolTests`, `USBClientTests`,
  `BodyFusionTests`, `USBSkeletonConsumerTests`) — carried into the new
  app's test target.
- New rendering units (`VideoQuad`, `SkeletonEntity`, `MeshEntity`,
  `SceneController`) depend on RealityKit/CoreML/VideoToolbox —
  verified by build + on-device/manual run. Any extractable pure logic
  (coordinate mapping, mesh index construction) gets unit tests.
- Build verification: a real Xcode project —
  `xcodebuild -scheme AVLiveBody -destination 'platform=macOS' build`.

## Scope

**In scope**

- New `avlivebody-mac/` Xcode app (xcodegen `project.yml`).
- Migrate the USB pipeline components into the new app.
- The RealityKit scene: `VideoQuad`, `SkeletonEntity`, `MeshEntity`,
  `SceneController`, orbital camera.
- Connection-status UI.
- Archive `launcher/AV-Live-Body/`.

**Out of scope**

- All legacy AVLiveBody functionality (MediaPipe pose, Metal viz
  modes, data-feeds HUD, Mac webcam, viz-mode hotkeys) — deliberately
  dropped, not migrated.
- Changes to the iOS `ARBodyTracker` app or to `AVLiveWire`.

## Migration notes

- The USB component files currently live in
  `launcher/AV-Live-Body/Sources/AVLiveBody/`. They are copied into the
  new app's source tree; the old directory is then archived (moved
  aside / removed from the active build), not deleted from git history.
- `AVLiveWire` is untouched in `shared/AVLiveWire`.
- The new app's `project.yml` declares the local `AVLiveWire` package
  dependency and bundles the Multi-HMR `.mlpackage` as a resource
  (per the earlier owner decision: bundle the validated FP32 model).

## Risks

- **Video-as-texture in RealityKit** — RealityKit has no direct
  "stream of `CVPixelBuffer` → texture" path (`VideoMaterial` is
  driven by an `AVPlayer`, not a decoded buffer stream). `VideoQuad`
  must replace a `TextureResource` (or use `LowLevelTexture`) per
  frame. This is the app's hardest technical point; the implementation
  plan isolates it in `VideoQuad` so it can be iterated independently.
- **macOS RealityKit camera control** — `ARView` on macOS is a general
  3D view; an orbital camera must be set up explicitly (RealityKit
  does not provide macOS orbit controls out of the box).
- **Multi-HMR throughput** — ~7 fps; the mesh layer is slow while the
  skeleton stays real-time. Acceptable; mesh interpolation can be
  added later if needed.
