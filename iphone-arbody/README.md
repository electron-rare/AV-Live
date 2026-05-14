# ARBodyTracker — iPhone OSC emitter for AV-Live

Streams ARKit ARBodyAnchor joints (91 per body) over OSC/UDP to GrosMac:

- `:57128` → Python `IphoneOSCListener` in `data_only_viz/` (drives `ArkitFuse` + cam-z lock)
- `:57129` → Swift `ArkitOSCListener` in `launcher/AV-Live-Body/` (diagnostic overlay)

Optional LiDAR depth (`ARFrameSemantics.sceneDepth`) is enabled when the
device supports it (iPhone 12 Pro and later).

## Build & run

The project ships in two forms:

| Form | Path | Use when |
|------|------|----------|
| Swift Package app | `ARBodyTracker.swiftpm/` | Quick local iteration. Signing has to be set manually in Xcode each clone. |
| Xcode project (xcodegen) | `project.yml` + `Config/*.xcconfig` | Reproducible signing across machines. Generate with `xcodegen generate`. |

### First-time setup (Xcode project flavour)

```bash
brew install xcodegen          # one-time
cp Config/Local.xcconfig.example Config/Local.xcconfig
# Edit Config/Local.xcconfig and set DEVELOPMENT_TEAM to your Apple Developer Team ID.
xcodegen generate              # writes ARBodyTracker.xcodeproj
open ARBodyTracker.xcodeproj
```

The generated `ARBodyTracker.xcodeproj/` is gitignored — regenerate any
time `project.yml` or sources change.

### Updating

Add Swift sources under `ARBodyTracker.swiftpm/Sources/ARBodyTracker/`,
then `xcodegen generate` to refresh the project. Both the swiftpm form
and the xcodeproj reference the same source tree.

## Signing

`Config/Local.xcconfig` (gitignored) holds `DEVELOPMENT_TEAM`.
`Config/Shared.xcconfig` (committed) pulls it via `#include?`, falling
back to no team if the local file is missing — the build will then
fail with the familiar "executable is not codesigned" error, which is
the correct signal that the developer needs to provision their own
team ID before deploying to a device.
