# iPhone Compute-Budget Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show ARKit fps, Vision latency, Vision drop rate, and thermal state on the iPhone screen so we can measure how much compute headroom the device has.

**Architecture:** `ARBodySession` (already owns the frame loop + Vision worker) computes four `@Published` metrics; `ContentView`'s control panel shows them in one line, color-coded by thermal state.

**Tech Stack:** Swift, SwiftUI, ARKit, Apple Vision, Foundation (`ProcessInfo.thermalState`).

## Global Constraints

- iPhone app `iphone-arbody/` (ARBodyTracker). Build via `xcodebuild` for `generic/platform=iOS`, `-allowProvisioningUpdates`. Source lives in the `.swiftpm/Sources` dir, built through `ARBodyTracker.xcodeproj`.
- `ARBodySession` is `@MainActor`. Metrics computed off-main (in `runVision`) hop back to `@MainActor` for the `@Published` write (mirror the existing `usb.send` hop).
- Vision must stay off-main + drop-if-busy; the metrics must NOT change capture behavior, only observe it.
- No emojis. Commit subject ≤ 50 chars, no AI attribution, no `--no-verify`, no underscore in commit scope.
- Build is the automated gate; the real deliverable is the on-device reading (operator).
- Branch: `main` (trunk-based).
- SourceKit single-file diagnostics are noise; the `xcodebuild` result is the source of truth.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` | Modify | compute + publish arkitFps / visionMs / visionDropRate / thermalLabel |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift` | Modify | metrics line in the control panel, thermal color-coded |

---

## Task 1: Budget metrics + overlay

**Files:**
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift`
- Modify: `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift`

**Interfaces:**
- Produces on `ARBodySession`: `@Published var arkitFps: Double`, `@Published var visionMs: Double`, `@Published var visionDropRate: Double`, `@Published var thermalLabel: String`, and `nonisolated static func thermalString(_:) -> String`.

- [ ] **Step 1: Add the published metrics + counters + thermal observer to ARBodySession**

Add near the other `@Published` properties:
```swift
    @Published var arkitFps: Double = 0
    @Published var visionMs: Double = 0
    @Published var visionDropRate: Double = 0
    @Published var thermalLabel: String = "nominal"
```
Add private counters near `lastVisionTime`:
```swift
    private var visionAttempts: Int = 0
    private var visionDrops: Int = 0
```
Add the thermal helper (place after the properties, before `start()`):
```swift
    nonisolated static func thermalString(
        _ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "?"
        }
    }
```
In `init()` (after the existing `videoEncoder.onPayload` setup), seed + observe thermal:
```swift
        thermalLabel = Self.thermalString(
            ProcessInfo.processInfo.thermalState)
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.thermalLabel = Self.thermalString(
                    ProcessInfo.processInfo.thermalState)
            }
        }
```

- [ ] **Step 2: Compute ARKit fps in the frame handler**

In `session(_:didUpdate:)`, inside the `Task { @MainActor in ... }` block, the throttle currently reads:
```swift
            if t - self.lastFrameTime < 1.0 / 30.0 { return }
            self.lastFrameTime = t
```
Replace it with a version that also derives fps from the inter-frame delta:
```swift
            let dt = t - self.lastFrameTime
            if dt < 1.0 / 30.0 { return }
            self.lastFrameTime = t
            if dt > 0, dt < 1.0 {
                let inst = 1.0 / dt
                self.arkitFps = self.arkitFps == 0
                    ? inst : self.arkitFps * 0.9 + inst * 0.1
            }
```

- [ ] **Step 3: Count Vision attempts/drops in the throttled dispatch**

The Phase-0 Vision dispatch currently looks like:
```swift
            if t - self.lastVisionTime >= 1.0 / 15.0, !self.visionBusy {
                self.lastVisionTime = t
                self.visionBusy = true
                let buf = img
                self.visionQueue.async {
                    self.runVision(on: buf, timestamp: t)
                    Task { @MainActor in self.visionBusy = false }
                }
            }
```
Replace it with a version that counts attempts and drops over a 60-sample
rolling window:
```swift
            if t - self.lastVisionTime >= 1.0 / 15.0 {
                self.visionAttempts += 1
                if self.visionBusy {
                    self.visionDrops += 1
                } else {
                    self.lastVisionTime = t
                    self.visionBusy = true
                    let buf = img
                    self.visionQueue.async {
                        self.runVision(on: buf, timestamp: t)
                        Task { @MainActor in self.visionBusy = false }
                    }
                }
                if self.visionAttempts >= 60 {
                    self.visionDropRate =
                        Double(self.visionDrops) / Double(self.visionAttempts)
                    self.visionAttempts = 0
                    self.visionDrops = 0
                }
            }
```

- [ ] **Step 4: Time the Vision pass in runVision**

In `runVision(on:timestamp:)`, wrap the `handler.perform(...)` with timing and publish an EMA. Replace:
```swift
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([handReq, faceReq])
```
with:
```swift
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        let t0 = Date()
        try? handler.perform([handReq, faceReq])
        let ms = Date().timeIntervalSince(t0) * 1000.0
        Task { @MainActor in
            self.visionMs = self.visionMs == 0
                ? ms : self.visionMs * 0.8 + ms * 0.2
        }
```

- [ ] **Step 5: Show the metrics line in ContentView**

In `ContentView.swift` `controlPanel`, after the existing `HStack` that shows
`"bodies: ... frames: ... j/s: ..."`, add a metrics line:
```swift
            Text("fps \(String(format: "%.1f", session.arkitFps))  "
                 + "vis \(Int(session.visionMs)) ms  "
                 + "drop \(Int(session.visionDropRate * 100))%  "
                 + session.thermalLabel)
                .font(.caption2)
                .foregroundColor(thermalColor)
```
Add a computed color property to `ContentView` (near `usbDotColor`):
```swift
    private var thermalColor: Color {
        switch session.thermalLabel {
        case "serious":  return .orange
        case "critical": return .red
        default:         return .green
        }
    }
```

- [ ] **Step 6: Build to verify it compiles**

Run:
```bash
cd "/Users/electron/Documents/Projets/AV-Live/iphone-arbody" && \
DD="/private/tmp/claude-501/-Users-electron-Documents-Projets-AV-Live/8a95bb35-b732-48ee-a725-0e61d6b41061/scratchpad/arbody-dd" && \
xcodebuild -project ARBodyTracker.xcodeproj -scheme ARBodyTracker -configuration Debug \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates -derivedDataPath "$DD" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines.

- [ ] **Step 7: Commit**

```bash
cd "/Users/electron/Documents/Projets/AV-Live"
git add iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift \
        iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift
git commit -m "feat(ios): compute budget metrics overlay"
```

- [ ] **Step 8: On-device read (operator)**

Deploy to the iPhone (build → `xcrun devicectl device install/launch`, device
`00008140-000845660163001C`). Tap Start, stand in frame with hands + face
visible ~1 min, and read the overlay line: `fps`, `vis ms`, `drop %`,
`thermal`. Report these numbers — they decide how far to push A (derive uniforms
on-device) and B (mesh on-device). This reading is the deliverable.

---

## Self-Review notes

- **Spec coverage:** §4.1 metrics (arkitFps/visionMs/visionDropRate/thermalLabel) → Steps 1-4; §4.2 overlay → Step 5; §5 build gate → Step 6, on-device read → Step 8.
- **Placeholder scan:** none; all code is concrete.
- **Type consistency:** `arkitFps/visionMs/visionDropRate/thermalLabel` (Double/Double/Double/String) used identically in ARBodySession (Steps 1-4) and ContentView (Step 5). `thermalString` switch covers all `ProcessInfo.ThermalState` cases.
- **Behavior safety:** the Vision dispatch keeps drop-if-busy (only counts added); fps/drop counters mutate on `@MainActor`; `visionMs` write hops to `@MainActor`. Capture behavior unchanged.
- **Out of scope:** sending metrics to the Mac; A/B work (gated on these numbers).
