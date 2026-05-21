# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

iPhone-only app that streams ARKit `ARBodyAnchor` joints (91 per body) to
the AV-Live stack on a tethered Mac. Part of the parent `AV-Live/`
monorepo — read `../CLAUDE.md` for global conventions (commit style,
French/English split, no emoji, etc.).

## Two build forms, one source tree

Both flavours compile the same files under
`ARBodyTracker.swiftpm/Sources/ARBodyTracker/`:

| Form | When to use | How |
|------|-------------|-----|
| `ARBodyTracker.swiftpm/` (Swift Package) | Quick local iteration; previews | open `Package.swift` in Xcode |
| `ARBodyTracker.xcodeproj` (generated) | Device deploy with reproducible signing | `xcodegen generate` from `project.yml` |

The `.xcodeproj` is **gitignored** — regenerate after every change to
`project.yml` or after adding sources. `Config/Local.xcconfig` (also
gitignored) carries `DEVELOPMENT_TEAM`; copy from
`Config/Local.xcconfig.example` on a fresh clone.

## Common commands

```bash
brew install xcodegen                       # one-time
cp Config/Local.xcconfig.example Config/Local.xcconfig  # set DEVELOPMENT_TEAM
xcodegen generate                           # writes ARBodyTracker.xcodeproj
open ARBodyTracker.xcodeproj                # then ⌘R on a connected iPhone

# AVLiveWire — shared wire-format package (consumed by both the iOS
# app and launcher/AV-Live-Body on macOS). Tests live with it.
cd ../shared/AVLiveWire && swift test
cd ../shared/AVLiveWire && swift test --filter LoopbackTests
```

`xcodegen generate` is the one command to remember: any time `project.yml`
or the dep on `../shared/AVLiveWire` changes, the generated project must
be rebuilt before opening Xcode.

## Architecture

```
ARBodyTrackerApp ── ContentView ── ARViewContainer (ARView)
                       │            │
                       │            └─ ARBodySession (ARSessionDelegate)
                       │                  ├─ OSC fanout (UDP) ─► host:57128 (Python data_only_viz)
                       │                  │                      host:57129 (Swift AV-Live-Body)
                       │                  ├─ USBServer (TCP :7000, AVLiveWire frames)
                       │                  └─ @Published skeleton2D ──┐
                       └─ SkeletonOverlay (SwiftUI Canvas) ◄─────────┘
```

- **`ARBodySession`** owns the `ARSession` configured with
  `ARBodyTrackingConfiguration` (RGB-only; LiDAR `sceneDepth` is not
  available on this config, do not re-add it — it crashes the session).
  Throttles to 30 fps. Projects joints to 2D via
  `ARCamera.projectPoint(_:orientation:viewportSize:)`; the viewport
  size is fed back from the SwiftUI `GeometryReader`.
- **Transport** is dual: legacy OSC/UDP (still default), and a new
  USB/TCP path using `AVLiveWire` framed messages. The Mac side bridges
  via `usbmuxd`; the iOS side just listens on a fixed local port. No
  WiFi involved on the USB path.
- **`AVLiveWire`** (in `../shared/AVLiveWire`) defines a fixed 19-byte
  big-endian header (`AVL1` magic + tag + pid + timestamp + length) and
  an incremental `StreamDemuxer`. Both the iOS `USBServer` and the
  macOS consumer link against it so the wire format lives in exactly
  one place.
- **`SkeletonOverlay`** draws joints and bones from a published
  `SkeletonSnapshot`; bone parent indices come from
  `ARSkeletonDefinition.defaultBody3D.parentIndices` at runtime. For
  Xcode previews the snapshot/parents are replaced by a 16-joint
  stick-figure mock (ARKit's `neutralBodySkeleton3D` returns nil off
  device).

## Gotchas

- **Frame semantics:** `ARBodyTrackingConfiguration` rejects
  `.sceneDepth` (world-tracking only) and spams `ABPKPersonIDTracker:
  Portrait image is not supported` per-frame if
  `.personSegmentationWithDepth` is added. Keep `feats` empty unless a
  newly-needed semantic is verified against
  `ARBodyTrackingConfiguration.supportsFrameSemantics(_:)`.
- **Signing without an Apple ID logged into Xcode:** with
  `CODE_SIGN_STYLE = Automatic`, Xcode needs the account in
  Settings → Accounts to download a profile. If only the keychain
  cert is present, the build fails with "No Account for Team …".
  Reconnect the account, or fall back to a manually installed profile
  via `CODE_SIGN_STYLE = Manual` + `PROVISIONING_PROFILE_SPECIFIER`.
- **`UIDeviceFamily` warning:** `Info.plist` and `TARGETED_DEVICE_FAMILY`
  duplicate the device family. The build setting wins; the Info.plist
  key only generates a warning and can be removed if desired.
