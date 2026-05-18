# iPhone USB Body-Tracking Link — Design

> **Status:** design approved (brainstorming), pending implementation plan.
> **Date:** 2026-05-18

## Goal

Replace the network (OSC/UDP over WiFi) link between the iOS
`ARBodyTracker` app and the macOS `AVLiveBody` app with a **wired USB
link**, so the body-tracking pipeline runs autonomously on one
iPhone + one Mac with no WiFi, no router, no hotspot, no remote
worker.

## Motivation

AV-Live's body pipeline is currently distributed: the Mac camera
feeds Multi-HMR (on a remote host), and the iPhone ARKit data only
*corrects* it over OSC/UDP. This depends on the network. The owner
wants a self-contained, network-free system.

## Decisions (brainstorming outcomes)

1. **iPhone is the source.** ARKit body tracking + LiDAR + RGB video
   all originate on the iPhone. The Mac no longer uses its own camera.
2. **iPhone streams video.** Multi-HMR is an image-to-SMPL-X model, so
   the iPhone sends the RGB video (not just the skeleton); the Mac runs
   Multi-HMR on that video. The ARKit skeleton + LiDAR correct scale
   and depth.
3. **Transport is USB.** Bluetooth cannot carry video bandwidth; WiFi
   is a network. The cable is the only network-free, high-bandwidth,
   low-latency option.
4. **Single native macOS app.** `AVLiveBody` becomes one Swift app:
   receives USB, runs Multi-HMR in CoreML, renders the mesh. No Python
   in the iPhone-USB path.
5. **Multi-person.** Multi-HMR yields N meshes from the video; the
   single ARKit skeleton corrects the *primary* body only; others are
   Multi-HMR raw. Skeleton-to-mesh association logic is required.
6. **USB transport mechanism:** native Swift `usbmux` client (no
   `peertalk` dependency).

## Architecture

Two apps, one cable.

- **ARBodyTracker (iOS)** — extends the existing
  `iphone-arbody/ARBodyTracker.swiftpm`. Captures the ARKit 91-joint
  skeleton (LiDAR-anchored) and the `ARFrame` RGB image, HEVC-encodes
  the video, frames skeleton + video into one stream, and serves it on
  a local TCP port that the Mac reaches through `usbmuxd`.
- **AVLiveBody (macOS)** — extends the existing
  `launcher/AV-Live-Body` Swift app. Connects to the iPhone over USB,
  demuxes the stream, HEVC-decodes the video, runs CoreML Multi-HMR
  (N meshes), fuses with the ARKit skeleton, renders the meshes, and
  keeps feeding SuperCollider via localhost OSC.

usbmuxd is Apple's USB device-multiplexing daemon (the channel Xcode
uses for a tethered device). The iOS app's TCP listener is never
exposed to any network; the Mac connects to it through the cable via
`/var/run/usbmuxd`.

## Components

### iOS — ARBodyTracker

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `ARBodySession` | `ARBodyTrackingConfiguration` → 91-joint skeleton + `ARFrame.capturedImage` | ARKit (exists, extend) |
| `VideoEncoder` | hardware HEVC encode (VideoToolbox): pixel buffer → compressed access unit | VideoToolbox |
| `WireFormat` | binary framing `[tag, pid, timestamp, length, payload]`; pure, testable | — |
| `USBServer` | TCP `NWListener` on a fixed local port; usbmuxd exposes it to the tethered Mac | Network, WireFormat |
| `ContentView` | UI: AR preview, connection status, start/stop | SwiftUI (exists, extend) |

The existing OSC sender in ARBodyTracker is removed.

### macOS — AVLiveBody

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `USBClient` | native Swift usbmux client: `/var/run/usbmuxd` socket, device list, connect-to-port, attach/detach events, byte stream | — (Unix socket, mockable) |
| `StreamDemuxer` | parse `WireFormat` frames → skeleton frames / video frames; resync on partial buffers | WireFormat |
| `VideoDecoder` | hardware HEVC decode → `CVPixelBuffer` | VideoToolbox |
| `MultiHMRCoreML` | run the CoreML Multi-HMR model on a frame → N SMPL-X meshes | CoreML `.mlpackage` |
| `BodyFusion` | associate the ARKit skeleton with the matching Multi-HMR person; LiDAR scale/depth correction on the primary; others pass through; pure, testable | — |
| `MeshRenderer` / `Skeleton3DRenderer` | RealityKit rendering of meshes/skeletons | RealityKit (exist) |
| `PoseOSCBridge` | emit pose to SuperCollider `:57121` on localhost — preserves AV-Live's audio half | Network (localhost only) |

`ArkitOSCListener` (network) is retired; `USBClient` takes its role
over USB.

## Data flow

```
iPhone   ARKit ──┬─ skeleton 91 joints ─────────────┐
                 └─ ARFrame RGB → VideoEncoder HEVC ─┤
                                          WireFormat ┤→ USBServer (local TCP port)
                                                     │
                              ═══ USB cable / usbmuxd ═══
                                                     │
Mac      USBClient → StreamDemuxer ─┬─ video → VideoDecoder → MultiHMRCoreML → N meshes ┐
                                    └─ skeleton ───────────────────────────────────────┤
                                                                            BodyFusion ┤
                              ┌──────────────────────────────────────────────────────┘
                              ├→ MeshRenderer (N meshes) + Skeleton3DRenderer
                              └→ PoseOSCBridge → SuperCollider :57121 (localhost)
```

`BodyFusion` associates the ARKit skeleton with the nearest Multi-HMR
person (by 2D projection / position) and corrects that person's scale
and depth (`pred_cam_t.z`) from the LiDAR-anchored joints. Other
bodies remain Multi-HMR raw.

**Two rates.** The skeleton streams at ~30 fps (cheap, always fresh).
Video / Multi-HMR runs slower (CoreML throughput, ~2-5 fps on Apple
Silicon). Every frame carries a timestamp; fusion matches a mesh to
the nearest-in-time skeleton. The skeleton is the smooth real-time
layer; the dense mesh is a slower layer, bridged to 30 fps by the
existing mesh interpolation in `AVLiveBody` (commit `0293cde`),
driven by the 30 fps skeleton.

## Wire format

Each frame: a fixed header followed by a payload.

| Field | Type | Notes |
|-------|------|-------|
| `tag` | `u8` | 1 = skeleton, 2 = video, 3 = meta |
| `pid` | `i16` | body id (skeleton/meta); `-1` for video |
| `timestamp` | `f64` | capture time, seconds |
| `length` | `u32` BE | payload byte count |
| `payload` | bytes | per-tag, below |

- **skeleton** — 91 × `(x, y, z)` `f32` world-space + a 91-bit
  validity mask.
- **video** — one HEVC access unit; a flag marks keyframes and
  carries parameter sets (VPS/SPS/PPS) when present.
- **meta** — video dimensions, camera intrinsics, body count.

Exact byte layout is finalized in the implementation plan.

## Error handling

- **USB attach/detach** — `USBClient` subscribes to usbmuxd device
  events and auto-reconnects. Renderers GC stale persons (existing
  `retainSec`).
- **Backpressure** — if Multi-HMR is slower than capture, latest frame
  wins: intermediate video frames are dropped, never queued. The
  skeleton stream stays fresh independently.
- **HEVC decode failure** — frame skipped.
- **CoreML model absent or failing** — fall back to skeleton-only
  rendering (`Skeleton3DRenderer` draws the ARKit skeleton): degraded
  but alive.
- **Frame sync** — timestamp-based nearest match in `BodyFusion`.

## Testing

| Unit | Test |
|------|------|
| `WireFormat` | pure unit: encode→decode roundtrip, all tags, truncated/corrupt frames |
| `USBClient` | unit: usbmux protocol against a mocked Unix socket (canned plist replies), device-list parse, connect handshake, attach/detach events |
| `StreamDemuxer` | roundtrip + resync on partial (non-frame-aligned) buffers |
| `VideoDecoder` | decode a known HEVC sample → expected dimensions |
| `BodyFusion` | pure logic: synthetic skeleton + synthetic Multi-HMR persons → assert association + scale/depth correction |
| `MultiHMRCoreML` | integration: known frame → mesh, sanity bounds |
| iOS (`VideoEncoder`, `ARBodySession`, `USBServer`) | framing unit-tested; ARKit/VideoToolbox need a device — manual/integration |
| End-to-end | iPhone tethered, both apps, N meshes render + latency budget + USB reconnect |

## Scope

**In scope**

- Extend `iphone-arbody/ARBodyTracker.swiftpm`: `VideoEncoder`,
  `WireFormat`, `USBServer`; `ARBodySession` exposes video frames; the
  OSC sender is removed.
- Extend `launcher/AV-Live-Body`: `USBClient`, `StreamDemuxer`,
  `VideoDecoder`, `MultiHMRCoreML` wiring, `BodyFusion`;
  `ArkitOSCListener` retired.
- Keep `PoseOSCBridge` → SuperCollider on localhost.

**Out of scope**

- The Python `data_only_viz` pipeline — untouched; it remains the
  Mac-camera mode. This project is the iPhone-USB path only.
- CoreML Multi-HMR model *conversion* — assumed already done
  (`multihmr_coreml.py` + existing conversion plans). This project
  *consumes* the `.mlpackage`.
- LiDAR scene mesh / ICP fusion (separate plan).
- iOS app signing and deployment — owner action.

## Risks & dependencies

- **CoreML Multi-HMR readiness** — the dense-mesh half depends on a
  working, fast-enough `.mlpackage`. If not ready, that half is
  blocked, but the skeleton-only fallback keeps the project useful —
  not all-or-nothing.
- **Multi-HMR throughput** — ~2-5 fps measured on Apple Silicon. The
  dense mesh updates slowly; the 30 fps skeleton + existing mesh
  interpolation cover the gap.
- **Device pairing** — the iPhone must be trusted/paired with the Mac
  for usbmuxd to expose it.
- **iOS deployment** — building/signing/installing the iOS app is a
  manual owner step.
