# Design — iPhone compute-budget measurement overlay

**Date:** 2026-06-26
**Status:** Approved (brainstorming) — ready for implementation plan
**App:** `iphone-arbody/` (ARBodyTracker, iOS)

## 1. Goal

Surface, on the iPhone screen, the runtime metrics needed to decide how much
more compute the device can absorb (the "max compute on the iPhone" direction):
- **ARKit fps** (actual `session(_:didUpdate:)` cadence, smoothed)
- **Vision latency** (duration of `handler.perform([hands, face])`, EMA, ms)
- **Vision drop rate** (frames skipped by the `visionBusy` drop-if-busy guard)
- **Thermal state** (`ProcessInfo.thermalState`: nominal/fair/serious/critical)

These four tell us the spare budget before stacking A (derive shader uniforms
on-device) and B (run SMPL-X mesh on-device). This is step 0 of that track.

## 2. Non-goals

- No sending metrics to the Mac (the operator reads the phone screen; `meta`
  tag stays unused here).
- No fine CPU%/GPU profiling — thermal state + drop rate are the decision
  signals.
- No A (uniform derivation) or B (on-device mesh) work — those follow, gated on
  these numbers.

## 3. Architecture

All metrics are produced inside `ARBodySession` (it already owns the frame loop
and the Vision worker) and published for the SwiftUI UI to read.

```
ARBodySession (@MainActor, ARSessionDelegate)
  session(_:didUpdate:)  ─ measures inter-frame dt → arkitFps (EMA)
                         ─ counts vision attempts vs drops → visionDropRate
  runVision(...)         ─ times handler.perform(...) → visionMs (EMA)
  thermal                ─ ProcessInfo.thermalState (+ change notification)
       │ @Published arkitFps / visionMs / visionDropRate / thermalLabel
       ▼
ContentView (SwiftUI)    ─ small metrics overlay panel
```

## 4. Components

### 4.1 `ARBodySession` metrics (modify)
Add `@Published`:
- `arkitFps: Double` — EMA of `1 / dt` between consecutive `didUpdate` frames
  (α≈0.1). Existing `lastFrameTime` already tracks the previous timestamp.
- `visionMs: Double` — EMA of the `handler.perform([...])` wall time in
  `runVision` (measure with `CACurrentMediaTime()` / `Date`), α≈0.2.
- `visionDropRate: Double` — ratio of dropped frames (the `visionBusy` early
  return path) to Vision attempts, over a rolling window (e.g. last 60
  decisions) so it reflects current load, not lifetime.
- `thermalLabel: String` — "nominal" | "fair" | "serious" | "critical" from
  `ProcessInfo.processInfo.thermalState`, updated on
  `ProcessInfo.thermalStateDidChangeNotification` (and read once at start).

`visionMs` is computed off-main (in `runVision`) and the published write hops to
`@MainActor` (mirror the existing `usb.send` hop). Drop/attempt counters are
mutated on `@MainActor` (where the throttle decision already runs).

### 4.2 `ContentView` overlay (modify)
A compact, always-on metrics panel (corner overlay) showing the four values,
e.g. `fps 28.4 | vis 22 ms | drop 6% | thermal fair`, color-coding thermal
(green nominal/fair, orange serious, red critical). Read-only; does not affect
capture.

## 5. Testing

- **Build:** `xcodebuild ... -destination 'generic/platform=iOS' build` succeeds.
- **Unit (if a pure helper is extracted):** an EMA/drop-rate helper can be unit
  tested with synthetic samples; otherwise the metrics are observed live.
- **On-device (operator):** deploy, run ~1 min with a body + hands + face in
  frame, read fps / vision ms / drop% / thermal. These numbers feed the A/B
  decision. (This is the actual deliverable of the step — a measurement.)

## 6. File structure

| File | Action | Responsibility |
|------|--------|----------------|
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ARBodySession.swift` | Modify | compute + publish the 4 metrics |
| `iphone-arbody/ARBodyTracker.swiftpm/Sources/ARBodyTracker/ContentView.swift` | Modify | metrics overlay panel |

## 7. Sequencing

This is step 0 of the "max compute on iPhone" track (measure → A derive uniforms
on-device → B mesh on-device). A and B get their own design once these numbers
are in hand (B's feasibility depends on the thermal/drop headroom).
