# AVLiveBody (macOS)

Native macOS Xcode app that renders SMPL-X body meshes in RealityKit
from the USB iPhone body-tracking pipeline (ARBodyTracker -> Multi-HMR
worker -> AVLiveBody scene).

## Prerequisites

- macOS 15+
- Xcode 16+
- `xcodegen` — `brew install xcodegen`

## First-time setup

1. Copy the CoreML model into the app resources (required, gitignored,
   ~195 MB). Without it the app degrades to skeleton-only rendering:

   ```
   cp -R ~/.cache/av-live-multihmr/multihmr_full_672_s.mlpackage \
       avlivebody-mac/Sources/AVLiveBody/Resources/
   ```

2. Create your local xcconfig and set your signing team:

   ```
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   # Edit Config/Local.xcconfig:
   #   DEVELOPMENT_TEAM = <your Apple Developer Team ID>
   ```

## Build

Generate the Xcode project (run after every `project.yml` change) then
open or build from the CLI:

```
cd avlivebody-mac
xcodegen generate
open AVLiveBody.xcodeproj
```

CLI build / test:

```
xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
    -destination 'platform=macOS' build

xcodebuild -project AVLiveBody.xcodeproj -scheme AVLiveBody \
    -destination 'platform=macOS' test
```

## Runtime requirements

A tethered iPhone running the matching `ARBodyTracker` iOS app over USB
is required for body input. See `iphone-arbody/` for the iOS side.

## Architecture

- Design spec:
  `docs/superpowers/specs/2026-05-18-avlivebody-macos-rewrite-design.md`
- Implementation plan:
  `docs/superpowers/plans/2026-05-18-avlivebody-macos-rewrite.md`
