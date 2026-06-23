# oscope-sphere — Design Spec

- **Date:** 2026-05-18
- **Status:** design approved, pending implementation plan
- **Repo:** `electron-rare/AV-Live` (monorepo) — new sibling project `oscope-sphere/`
- **Origin:** brainstorming session, derived from `oscope-of`

## 1. Goal

A minimal openFrameworks app that captures the Hantek 6022 oscilloscope
(both channels) and renders a single 3D sphere combining a spectrogram
and a waveform. No demoparty content — just the sphere.

It reuses `oscope-of`'s hardware-capture and signal-analysis layer and
discards its ~80 KB demoparty renderer.

## 2. Scope

In scope:

- Hantek 6022 dual-channel USB capture (reused from `oscope-of`)
- Per-channel FFT and waveform extraction (reused)
- A single sphere rendered with three composable visual layers (A+B+C)
- Demo-mode fallback when no scope is connected

Out of scope (YAGNI):

- OSC send/receive (`oscope-of`'s `OscClient`)
- Post-FX chain, the 41 backgrounds, the 15 demoparties
- GUI panels — keyboard and mouse only
- Recording or frame export

## 3. Reused from oscope-of

Copied verbatim into `oscope-sphere/src/`. These files are small, stable,
and self-contained; copying (rather than sharing across an openFrameworks
Makefile boundary) keeps the project buildable in isolation. Drift risk is
low because the capture layer is mature.

| File | Role |
|------|------|
| `ScopeData.h` | SPSC lock-free ring buffer of CH1/CH2 samples, `[-1,1]` |
| `HantekDevice.{h,cpp}` | libusb capture thread for Hantek 6022, feeds the ring |
| `AudioAnalyzer.{h,cpp}` | downsample (scope rate → 48 kHz) + FFT bands |
| `FFT.{h,cpp}` | Cooley-Tukey radix-2, no external dependency |

Public interfaces used:

- `ScopeRing::readLatest(outCh1, outCh2, n)` — latest `n` samples, per channel
- `HantekDevice::start()/stop()/status()`, `HantekDevice::ring()`
- `AudioAnalyzer::update(ch1, ch2, sr)`, `magDown()` (1024 bins, ~23.4 Hz/bin)

**Per-channel spectrum trick.** `AudioAnalyzer::update(ch1, ch2, sr)` mixes
its two arguments to mono before the FFT. To get a per-channel spectrum
without editing the file, instantiate two analyzers and feed each
`update(chX, chX, sr)` — mixing a signal with itself yields that signal.
`analyzerCh1` is fed `(buf1, buf1)`, `analyzerCh2` is fed `(buf2, buf2)`.

**Hardware constraint.** 24/48 MS/s are single-channel-only on the
OpenHantek6022 firmware. Because both channels are required, capture is
configured at **16 MS/s**.

## 4. Channel convention

The sphere is split at the equator: **northern hemisphere = CH1**,
**southern hemisphere = CH2**. This convention holds across all three
layers, so the object always reads as one coherent stereo body.

## 5. The three layers (A + B + C)

All three target the same sphere subject. Keys `1`/`2`/`3` toggle layers
A/B/C independently; default is all three on.

### Layer A — Core sphere: spectrogram skin + waveform displacement

- **Geometry:** one icosphere VBO (subdivided, ~10k–40k vertices).
- **Skin (spectrogram):** a scrolling 2D texture. X = time (longitude),
  Y = frequency on a log scale (latitude). Northern rows = CH1 `magDown`
  log-resampled, southern rows = CH2. Each frame writes one new column at
  the ring write index. The fragment shader samples it and applies a
  colormap (magma / inferno).
- **Displacement (waveform):** the vertex shader displaces each vertex
  along its normal by the live waveform amplitude. Northern vertices read
  the CH1 waveform texture, southern vertices read CH2. The sphere
  geometry "breathes" in stereo.

### Layer B — Waveform orbit rings

Two 3D line-loop rings orbiting the sphere in perpendicular planes.
Ring 1 = CH1, ring 2 = CH2. Each ring is a circle of `M` points whose
radius is `baseOrbitRadius + channelWaveformSample(angle)`. The rings
ripple with the live signal — a stereo Lissajous-flavoured cage.

### Layer C — Point-cloud shell

The same sphere rendered as `GL_POINTS` particles. Each particle's radial
position uses the waveform displacement (as in layer A); its color is the
spectrogram value at its `(latitude, longitude)`. Northern particles = CH1,
southern = CH2. Layer C composites additively over (or instead of) the
solid skin.

### Compositing and controls

- `1`/`2`/`3` — toggle layers A/B/C; `c` — cycle colormap; `space` — freeze
- Mouse drag — orbit camera; slow automatic rotation otherwise
- The spectrogram scroll is decoupled from camera rotation

## 6. Architecture and components

| Unit | Purpose | Depends on |
|------|---------|-----------|
| `HantekDevice` (reused) | USB capture thread → `ScopeRing` | libusb |
| `AudioAnalyzer` ×2 (reused) | per-channel downsample + FFT | `FFT` |
| `SphereViz` (new) | owns icosphere VBO + spectrogram texture ring; draws layers A and C | oF GL |
| `OrbitRings` (new) | owns the two ring meshes; draws layer B | oF GL |
| `ofApp` (new) | wires capture → analysis → viz; camera; layer toggles; HUD; demo mode | all of the above |

New unit interfaces:

```cpp
class SphereViz {
    void setup(int subdivisions);
    // log-resamples each channel's magnitudes, advances the texture ring
    void pushSpectrogramColumn(const std::vector<float>& magCh1,
                               const std::vector<float>& magCh2);
    // uploads the per-channel waveform displacement textures
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);
    void drawSkin();    // layer A
    void drawPoints();  // layer C
    void setColormap(int id);
};

class OrbitRings {
    void setup(int pointsPerRing);
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);
    void draw();        // layer B
};
```

## 7. Data flow

```
HantekDevice thread ── libusb bulk ──> ScopeRing (ch1, ch2 floats [-1,1])

ofApp::update():
  ring.readLatest(buf1, buf2, N)
  analyzerCh1.update(buf1, buf1, sr)        -> magDown ch1
  analyzerCh2.update(buf2, buf2, sr)        -> magDown ch2
  sphereViz.pushSpectrogramColumn(magCh1, magCh2)   // advance texture
  sphereViz.setWaveform(buf1, buf2)                 // displacement textures
  orbitRings.setWaveform(buf1, buf2)

ofApp::draw():
  cam.begin()
    if layerA: sphereViz.drawSkin()
    if layerC: sphereViz.drawPoints()
    if layerB: orbitRings.draw()
  cam.end()
  drawHud()   // capture status
```

## 8. File layout

```
oscope-sphere/
  Makefile  config.make  addons.make  .gitignore  CLAUDE.md  README.md
  src/
    main.cpp
    ofApp.{h,cpp}
    HantekDevice.{h,cpp}    (copied from oscope-of)
    AudioAnalyzer.{h,cpp}   (copied)
    FFT.{h,cpp}             (copied)
    ScopeData.h             (copied)
    SphereViz.{h,cpp}       (new — layers A and C)
    OrbitRings.{h,cpp}      (new — layer B)
  bin/data/shaders/
    sphere.vert  sphere.frag   (layer A skin + layer C points)
```

- `addons.make` is empty — no `ofxOsc`, `ofxGui`, or `ofxOpenCv`.
- `Makefile` / `config.make` are copied from `oscope-of`, with `APPNAME`
  set to `oscope-sphere`.
- Window: GL 3.2 core, GLSL 150, 1920×1080, MSAA 8× — same as
  `oscope-of/src/main.cpp`.
- Requires an openFrameworks install (same prerequisite as `oscope-of`).

## 9. Error handling and demo mode

`HantekDevice::start()` returns a `HantekStatus`. On `NotFound`,
`FirmwareNeeded`, or `UsbError`, `ofApp` enters demo mode: it synthesizes
CH1 (a sine sweep) and CH2 (a distinct sine plus noise) into the same
pipeline, so all three layers stay alive without hardware. The HUD shows:

- `SCOPE OK`
- `DEMO — scope not found`
- `DEMO — firmware needed (see docs/HANTEK_SETUP.md)`

Unplugging the scope mid-run must not crash (graceful fallback, per the
`oscope-of` convention). No heap allocations in `update()` / `draw()` —
FFT buffers, VBOs, and textures are preallocated in `setup()`.

## 10. Testing

- **FFT / AudioAnalyzer:** a known sine in → expected peak bin. Verify the
  per-channel trick: `update(chX, chX, sr)` ⇒ `monoDown` equals the
  downsampled `chX`.
- **SphereViz:** spectrogram ring-buffer wrap index after `K > W` column
  pushes; log-resample mapping is monotonic.
- **OrbitRings:** point count and radius-modulation bounds.
- **GL rendering:** verified manually with a connected scope plus a signal
  generator / audio output. This layer cannot be unit-tested; results will
  be reported as observed, never claimed as "passing" without a visual check.

## 11. Assumptions made during brainstorming

Override any of these if wrong:

- New sibling folder `oscope-sphere/`; `oscope-of` is left untouched.
- Capture files are copied, not shared — accepted minor duplication.
- Capture default is 16 MS/s (dual-channel hardware constraint).
- Channel convention: northern hemisphere = CH1, southern = CH2.
- Work happens in `/tmp/AV-Live` because `~/Documents/Projets/AV-Live`
  is TCC-locked on this machine; the result must be moved or pushed.
