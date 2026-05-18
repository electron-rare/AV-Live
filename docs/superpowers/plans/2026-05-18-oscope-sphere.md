# oscope-sphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal openFrameworks app that captures the dual-channel Hantek 6022 oscilloscope and renders it as a single 3D sphere with three composable layers — spectrogram skin, waveform displacement, orbit rings, and point cloud.

**Architecture:** A new `oscope-sphere/` project, sibling of `oscope-of/` in the AV-Live monorepo. It copies oscope-of's mature capture/analysis layer (4 files) and adds new code split into pure-C++ units (`SpectrogramBuffer`, `DemoSignal` — unit-tested) and GL units (`SphereViz`, `OrbitRings`, `ofApp` — manual visual verification). The sphere is split at the equator: northern hemisphere = CH1, southern = CH2.

**Tech Stack:** C++17, openFrameworks (GL 3.2 core, GLSL 150), libusb-1.0, plain `clang++` for the pure-C++ test harness.

---

## Prerequisites

- Work happens in the cloned working copy at `/tmp/AV-Live` — `~/Documents/Projets/AV-Live` is TCC-locked on this machine. All paths below are repo-relative.
- Tasks 1-3 (pure C++) need only `clang++` and compile standalone.
- Tasks 4-9 (GL) need an openFrameworks install. The project must sit at `<OF_ROOT>/apps/myApps/oscope-sphere/` **or** be built with `OF_ROOT` pointed at the openFrameworks root (`config.make` uses `OF_ROOT = ../../..` by default, like oscope-of). The Hantek scope is optional — the app falls back to demo mode without it.
- GL verification steps are **manual visual checks**. Report what is observed; never claim a visual result without having looked at the window.

## File Structure

```
oscope-sphere/
  Makefile              copied verbatim from oscope-of
  config.make           copied verbatim from oscope-of (libusb auto-detect)
  addons.make           empty
  .gitignore            build artifacts
  CLAUDE.md  README.md  project docs (Task 9)
  src/
    main.cpp            window bootstrap (GL 3.2 core, 1920x1080)
    ofApp.{h,cpp}       wiring: capture -> analysis -> viz, camera, HUD, keys
    HantekDevice.{h,cpp}   copied from oscope-of  — USB capture
    AudioAnalyzer.{h,cpp}  copied from oscope-of  — downsample + FFT
    FFT.{h,cpp}            copied from oscope-of  — radix-2 FFT
    ScopeData.h            copied from oscope-of  — SPSC ring buffer
    SpectrogramBuffer.{h,cpp}  NEW pure C++ — rolling log-freq columns
    DemoSignal.{h,cpp}         NEW pure C++ — synthetic signal fallback
    SphereViz.{h,cpp}          NEW GL — icosphere, skin (A), points (C)
    OrbitRings.{h,cpp}         NEW GL — two waveform rings (B)
  bin/data/shaders/
    sphere.vert  sphere.frag   GLSL 150 core
  tests/
    check.h             tiny assertion macros
    test_analysis.cpp   FFT + per-channel trick
    test_spectrogram.cpp  SpectrogramBuffer
    test_demo.cpp       DemoSignal
    run_tests.sh        compile + run all pure-C++ tests
```

---

## Task 1: Project scaffold and reused-file sanity tests

Creates the project directory, copies the four reused files, and proves the reused FFT/AudioAnalyzer behave as the design assumes (FFT peak detection, and the `update(chX, chX)` per-channel trick).

**Files:**
- Create: `oscope-sphere/` directory and `oscope-sphere/src/`, `oscope-sphere/tests/`, `oscope-sphere/bin/data/shaders/`
- Create: `oscope-sphere/addons.make`, `oscope-sphere/.gitignore`
- Copy: `oscope-of/src/{FFT.h,FFT.cpp,AudioAnalyzer.h,AudioAnalyzer.cpp,ScopeData.h,HantekDevice.h,HantekDevice.cpp}` → `oscope-sphere/src/`
- Create: `oscope-sphere/tests/check.h`, `oscope-sphere/tests/test_analysis.cpp`

- [ ] **Step 1: Create directories and copy reused files**

Run from `/tmp/AV-Live`:

```bash
mkdir -p oscope-sphere/src oscope-sphere/tests oscope-sphere/bin/data/shaders
cp oscope-of/src/FFT.h oscope-of/src/FFT.cpp \
   oscope-of/src/AudioAnalyzer.h oscope-of/src/AudioAnalyzer.cpp \
   oscope-of/src/ScopeData.h \
   oscope-of/src/HantekDevice.h oscope-of/src/HantekDevice.cpp \
   oscope-sphere/src/
touch oscope-sphere/addons.make
```

- [ ] **Step 2: Create `oscope-sphere/.gitignore`**

```gitignore
obj/
bin/oscope-sphere
bin/oscope-sphere_debug
bin/oscope-sphere.app/
*.o
*.d
```

- [ ] **Step 3: Create `oscope-sphere/tests/check.h`**

```cpp
#pragma once
#include <cstdio>

inline int g_checks = 0;
inline int g_fails  = 0;

#define CHECK(cond)                                                       \
    do {                                                                  \
        ++g_checks;                                                       \
        if (!(cond)) {                                                    \
            ++g_fails;                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);    \
        }                                                                 \
    } while (0)

#define REPORT()                                                          \
    do {                                                                  \
        std::printf("%d/%d checks passed\n", g_checks - g_fails, g_checks);\
        return g_fails ? 1 : 0;                                           \
    } while (0)
```

- [ ] **Step 4: Write the failing test `oscope-sphere/tests/test_analysis.cpp`**

```cpp
#include "check.h"
#include "FFT.h"
#include "AudioAnalyzer.h"
#include <cmath>
#include <vector>

using oscope::AudioAnalyzer;
using oscope::FFT;

static int argmax(const std::vector<float>& v) {
    int best = 1;
    float bv = -1.0f;
    for (int i = 1; i < static_cast<int>(v.size()); ++i)
        if (v[i] > bv) { bv = v[i]; best = i; }
    return best;
}

static std::vector<float> tone(double freqHz, double srHz, std::size_t n) {
    std::vector<float> s(n);
    for (std::size_t i = 0; i < n; ++i)
        s[i] = static_cast<float>(std::sin(2.0 * M_PI * freqHz * i / srHz));
    return s;
}

// FFT of a sine landing exactly on bin 64 must peak at bin 64.
static void test_fft_peak() {
    const std::size_t N = 2048;
    std::vector<float> in(N);
    for (std::size_t i = 0; i < N; ++i)
        in[i] = static_cast<float>(std::sin(2.0 * M_PI * 64.0 * i / N));
    FFT fft(N);
    std::vector<float> mag;
    fft.magnitude(in, mag);
    CHECK(mag.size() == N / 2);
    int peak = argmax(mag);
    CHECK(peak >= 63 && peak <= 65);
}

// Feeding update(chX, chX) must isolate chX — proves the dual-analyzer
// trick: AudioAnalyzer mixes 0.5*(a+b), so 0.5*(x+x) == x.
static void test_per_channel_isolation() {
    const double sr = 48000.0;            // deci == 1, no decimation
    auto a = tone(1000.0, sr, 2048);      // bin width 23.4 Hz -> bin ~43
    auto b = tone(5000.0, sr, 2048);      // -> bin ~213
    AudioAnalyzer an1, an2;
    an1.update(a, a, static_cast<float>(sr));
    an2.update(b, b, static_cast<float>(sr));
    int p1 = argmax(an1.magDown());
    int p2 = argmax(an2.magDown());
    CHECK(p1 >= 41 && p1 <= 45);
    CHECK(p2 >= 211 && p2 <= 217);
    CHECK(p1 != p2);
}

int main() {
    test_fft_peak();
    test_per_channel_isolation();
    REPORT();
}
```

- [ ] **Step 5: Run the test to verify it compiles and passes**

Run from `/tmp/AV-Live/oscope-sphere`:

```bash
clang++ -std=c++17 -O0 -g -Isrc \
  tests/test_analysis.cpp src/FFT.cpp src/AudioAnalyzer.cpp \
  -o /tmp/osph-test-analysis && /tmp/osph-test-analysis
```

Expected: `4/4 checks passed`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere
git commit -m "$(cat <<'EOF'
build: scaffold oscope-sphere project

Create the project tree, copy oscope-of's capture and analysis layer
(FFT, AudioAnalyzer, ScopeData, HantekDevice), and add a standalone
test harness covering FFT peak detection and the per-channel trick.
EOF
)"
```

---

## Task 2: SpectrogramBuffer — rolling log-frequency column store

A pure-C++ unit (no GL) that holds the scrolling spectrogram. Each pushed column log-resamples both channels' FFT magnitudes into a single column: CH1 in the northern rows, CH2 in the southern rows, high frequencies toward the poles.

**Files:**
- Create: `oscope-sphere/src/SpectrogramBuffer.h`
- Create: `oscope-sphere/src/SpectrogramBuffer.cpp`
- Create: `oscope-sphere/tests/test_spectrogram.cpp`

- [ ] **Step 1: Write the failing test `oscope-sphere/tests/test_spectrogram.cpp`**

```cpp
#include "check.h"
#include "SpectrogramBuffer.h"
#include <vector>

using oscope::SpectrogramBuffer;

// writeIndex advances modulo width.
static void test_write_index_wraps() {
    SpectrogramBuffer buf(8, 4);
    std::vector<float> z(1024, 0.0f);
    for (int i = 0; i < 10; ++i) buf.pushColumn(z, z);
    CHECK(buf.writeIndex() == 2);                 // 10 % 8
    CHECK(static_cast<int>(buf.data().size()) == 8 * 4);
}

// High-frequency energy must land near the poles for both channels.
static void test_high_freq_maps_to_poles() {
    SpectrogramBuffer buf(4, 8);   // H=8 -> CH1 rows 4..7, CH2 rows 0..3
    std::vector<float> hi(1024, 0.0f);
    hi[1023] = 100.0f;             // energy at the top FFT bin
    buf.pushColumn(hi, hi);        // both channels: high-frequency content
    const std::vector<float>& d = buf.data();
    const int W = buf.width();
    CHECK(d[7 * W + 0] > d[4 * W + 0]);   // CH1: north pole > equator
    CHECK(d[0 * W + 0] > d[3 * W + 0]);   // CH2: south pole > equator
}

int main() {
    test_write_index_wraps();
    test_high_freq_maps_to_poles();
    REPORT();
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `/tmp/AV-Live/oscope-sphere`:

```bash
clang++ -std=c++17 -O0 -g -Isrc tests/test_spectrogram.cpp \
  -o /tmp/osph-test-spectro 2>&1 | head -3
```

Expected: FAIL — `fatal error: 'SpectrogramBuffer.h' file not found`.

- [ ] **Step 3: Create `oscope-sphere/src/SpectrogramBuffer.h`**

```cpp
#pragma once
#include <vector>

namespace oscope {

// Pure-C++ rolling spectrogram column store. No GL dependency.
// Layout: row-major, data()[row * width + col].
// Height is forced even. Rows [H/2, H) hold CH1 (equator -> north pole),
// rows [0, H/2) hold CH2 (equator -> south pole). Frequency is log-scaled
// along the rows; magnitudes are normalised to [0,1] via a -60..0 dB map.
class SpectrogramBuffer {
public:
    SpectrogramBuffer(int width, int height);

    // magCh1 / magCh2: raw FFT magnitudes. Log-resampled into one column
    // at the current write index, which then advances modulo width.
    void pushColumn(const std::vector<float>& magCh1,
                    const std::vector<float>& magCh2);

    int width()  const { return width_; }
    int height() const { return height_; }
    int writeIndex() const { return writeIndex_; }
    const std::vector<float>& data() const { return data_; }

private:
    static float logResample(const std::vector<float>& mag, float frac01);
    static float norm01(float magnitude);

    int width_;
    int height_;
    int writeIndex_ = 0;
    std::vector<float> data_;
};

} // namespace oscope
```

- [ ] **Step 4: Create `oscope-sphere/src/SpectrogramBuffer.cpp`**

```cpp
#include "SpectrogramBuffer.h"
#include <algorithm>
#include <cmath>

namespace oscope {

SpectrogramBuffer::SpectrogramBuffer(int width, int height)
    : width_(std::max(1, width)),
      height_(std::max(2, height - (height % 2))) {
    data_.assign(static_cast<std::size_t>(width_) * height_, 0.0f);
}

float SpectrogramBuffer::logResample(const std::vector<float>& mag,
                                     float frac01) {
    if (mag.size() < 2) return 0.0f;
    const float lo = 1.0f;
    const float hi = static_cast<float>(mag.size() - 1);
    const float f  = std::clamp(frac01, 0.0f, 1.0f);
    const float bin = lo * std::pow(hi / lo, f);
    const int i0 = static_cast<int>(bin);
    const int i1 = std::min(i0 + 1, static_cast<int>(mag.size()) - 1);
    const float t = bin - static_cast<float>(i0);
    return mag[i0] * (1.0f - t) + mag[i1] * t;
}

float SpectrogramBuffer::norm01(float magnitude) {
    const float db = 20.0f * std::log10(std::max(magnitude, 1e-6f));
    return std::clamp((db + 60.0f) / 60.0f, 0.0f, 1.0f);
}

void SpectrogramBuffer::pushColumn(const std::vector<float>& magCh1,
                                   const std::vector<float>& magCh2) {
    const int col  = writeIndex_;
    const int half = height_ / 2;

    // CH1 -> northern rows [half, height_): row half = equator (low freq),
    // row height_-1 = north pole (high freq).
    for (int r = half; r < height_; ++r) {
        const float frac = static_cast<float>(r - half) /
                           static_cast<float>(half - 1);
        data_[static_cast<std::size_t>(r) * width_ + col] =
            norm01(logResample(magCh1, frac));
    }
    // CH2 -> southern rows [0, half): row half-1 = equator (low freq),
    // row 0 = south pole (high freq).
    for (int r = 0; r < half; ++r) {
        const float frac = static_cast<float>(half - 1 - r) /
                           static_cast<float>(half - 1);
        data_[static_cast<std::size_t>(r) * width_ + col] =
            norm01(logResample(magCh2, frac));
    }
    writeIndex_ = (writeIndex_ + 1) % width_;
}

} // namespace oscope
```

- [ ] **Step 5: Run the test to verify it passes**

Run from `/tmp/AV-Live/oscope-sphere`:

```bash
clang++ -std=c++17 -O0 -g -Isrc \
  tests/test_spectrogram.cpp src/SpectrogramBuffer.cpp \
  -o /tmp/osph-test-spectro && /tmp/osph-test-spectro
```

Expected: `4/4 checks passed`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/SpectrogramBuffer.h \
        oscope-sphere/src/SpectrogramBuffer.cpp \
        oscope-sphere/tests/test_spectrogram.cpp
git commit -m "$(cat <<'EOF'
feat: add rolling spectrogram column buffer

Pure-C++ store that log-resamples both channels' FFT magnitudes into
scrolling columns, CH1 north and CH2 south, high frequencies toward
the poles. No GL dependency, fully unit-tested.
EOF
)"
```

---

## Task 3: DemoSignal — synthetic fallback source

A pure-C++ unit producing a continuous two-channel signal when no scope is connected. CH1 sweeps in frequency, CH2 is a steady tone plus light noise.

**Files:**
- Create: `oscope-sphere/src/DemoSignal.h`
- Create: `oscope-sphere/src/DemoSignal.cpp`
- Create: `oscope-sphere/tests/test_demo.cpp`
- Create: `oscope-sphere/tests/run_tests.sh`

- [ ] **Step 1: Write the failing test `oscope-sphere/tests/test_demo.cpp`**

```cpp
#include "check.h"
#include "DemoSignal.h"
#include <cmath>
#include <vector>

using oscope::DemoSignal;

// Output has the requested length, stays in [-1,1], and the two
// channels differ.
static void test_shape_and_bounds() {
    DemoSignal demo(48000.0f);
    std::vector<float> a, b;
    demo.next(a, b, 256);
    CHECK(a.size() == 256);
    CHECK(b.size() == 256);
    bool inRange = true, differ = false;
    for (std::size_t i = 0; i < a.size(); ++i) {
        if (std::fabs(a[i]) > 1.0f || std::fabs(b[i]) > 1.0f) inRange = false;
        if (std::fabs(a[i] - b[i]) > 1e-4f) differ = true;
    }
    CHECK(inRange);
    CHECK(differ);
}

// Phase is continuous across calls: a second block differs from the first.
static void test_phase_advances() {
    DemoSignal demo(48000.0f);
    std::vector<float> a1, b1, a2, b2;
    demo.next(a1, b1, 64);
    demo.next(a2, b2, 64);
    bool same = true;
    for (std::size_t i = 0; i < 64; ++i)
        if (std::fabs(a1[i] - a2[i]) > 1e-4f) same = false;
    CHECK(!same);
}

int main() {
    test_shape_and_bounds();
    test_phase_advances();
    REPORT();
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `/tmp/AV-Live/oscope-sphere`:

```bash
clang++ -std=c++17 -O0 -g -Isrc tests/test_demo.cpp \
  -o /tmp/osph-test-demo 2>&1 | head -3
```

Expected: FAIL — `fatal error: 'DemoSignal.h' file not found`.

- [ ] **Step 3: Create `oscope-sphere/src/DemoSignal.h`**

```cpp
#pragma once
#include <cstdint>
#include <vector>

namespace oscope {

// Pure-C++ synthetic two-channel signal for when no scope is connected.
// CH1: slow frequency sweep. CH2: steady 440 Hz tone plus light noise.
// Stateful: phase advances across calls so the output stays continuous.
class DemoSignal {
public:
    explicit DemoSignal(float sampleRateHz);

    // Fills ch1 and ch2 with n freshly generated samples each.
    void next(std::vector<float>& ch1, std::vector<float>& ch2,
              std::size_t n);

private:
    float frand();   // cheap LCG noise in [-1, 1)

    float    sr_;
    double   phase1_ = 0.0;
    double   phase2_ = 0.0;
    double   sweep_  = 0.0;
    uint32_t rng_    = 0x9E3779B9u;
};

} // namespace oscope
```

- [ ] **Step 4: Create `oscope-sphere/src/DemoSignal.cpp`**

```cpp
#include "DemoSignal.h"
#include <algorithm>
#include <cmath>

namespace oscope {

namespace {
constexpr double kTwoPi = 6.283185307179586;
}

DemoSignal::DemoSignal(float sampleRateHz)
    : sr_(sampleRateHz > 1.0f ? sampleRateHz : 48000.0f) {}

float DemoSignal::frand() {
    rng_ = rng_ * 1664525u + 1013904223u;
    return (static_cast<float>(rng_ >> 8) / 8388608.0f) - 1.0f;  // [-1,1)
}

void DemoSignal::next(std::vector<float>& ch1, std::vector<float>& ch2,
                      std::size_t n) {
    ch1.resize(n);
    ch2.resize(n);
    for (std::size_t i = 0; i < n; ++i) {
        // CH1: sweep 80 Hz .. 2000 Hz, sweep period ~6 s.
        sweep_ += 1.0 / sr_;
        const double sweepHz =
            80.0 + 960.0 * (1.0 + std::sin(kTwoPi * sweep_ / 6.0));
        phase1_ += kTwoPi * sweepHz / sr_;
        ch1[i] = 0.85f * static_cast<float>(std::sin(phase1_));

        // CH2: steady 440 Hz tone + light noise.
        phase2_ += kTwoPi * 440.0 / sr_;
        const float v =
            0.7f * static_cast<float>(std::sin(phase2_)) + 0.15f * frand();
        ch2[i] = std::clamp(v, -1.0f, 1.0f);
    }
    if (phase1_ > kTwoPi * 1e6) phase1_ -= kTwoPi * 1e6;
    if (phase2_ > kTwoPi * 1e6) phase2_ -= kTwoPi * 1e6;
}

} // namespace oscope
```

- [ ] **Step 5: Create `oscope-sphere/tests/run_tests.sh`**

```bash
#!/usr/bin/env bash
# Compiles and runs every pure-C++ unit test. No openFrameworks needed.
set -euo pipefail
cd "$(dirname "$0")/.."
CXX="${CXX:-clang++}"
FLAGS=(-std=c++17 -O0 -g -Isrc)

echo "== analysis =="
"$CXX" "${FLAGS[@]}" tests/test_analysis.cpp src/FFT.cpp src/AudioAnalyzer.cpp \
  -o /tmp/osph-test-analysis
/tmp/osph-test-analysis

echo "== spectrogram =="
"$CXX" "${FLAGS[@]}" tests/test_spectrogram.cpp src/SpectrogramBuffer.cpp \
  -o /tmp/osph-test-spectro
/tmp/osph-test-spectro

echo "== demo =="
"$CXX" "${FLAGS[@]}" tests/test_demo.cpp src/DemoSignal.cpp \
  -o /tmp/osph-test-demo
/tmp/osph-test-demo

echo "ALL TESTS PASSED"
```

- [ ] **Step 6: Run the full test suite to verify it passes**

Run from `/tmp/AV-Live/oscope-sphere`:

```bash
chmod +x tests/run_tests.sh && ./tests/run_tests.sh
```

Expected: each block prints `N/N checks passed`, final line `ALL TESTS PASSED`, exit code 0.

- [ ] **Step 7: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/DemoSignal.h oscope-sphere/src/DemoSignal.cpp \
        oscope-sphere/tests/test_demo.cpp oscope-sphere/tests/run_tests.sh
git commit -m "$(cat <<'EOF'
feat: add synthetic demo signal source

Pure-C++ continuous two-channel generator used when no scope is
connected: CH1 frequency sweep, CH2 steady tone plus noise. Adds the
run_tests.sh runner covering all three pure-C++ units.
EOF
)"
```

---

## Task 4: openFrameworks project skeleton

Gets the project building and opening a window. No capture or sphere yet — just proves the openFrameworks build wiring works.

**Files:**
- Copy: `oscope-of/Makefile` → `oscope-sphere/Makefile`
- Copy: `oscope-of/config.make` → `oscope-sphere/config.make`
- Create: `oscope-sphere/src/main.cpp`
- Create: `oscope-sphere/src/ofApp.h`
- Create: `oscope-sphere/src/ofApp.cpp`

- [ ] **Step 1: Copy the build files**

Run from `/tmp/AV-Live`:

```bash
cp oscope-of/Makefile oscope-of/config.make oscope-sphere/
```

- [ ] **Step 2: Create `oscope-sphere/src/main.cpp`**

```cpp
// oscope-sphere — window bootstrap. GL 3.2 core profile, MSAA 8x.
#include "ofMain.h"
#include "ofApp.h"

int main() {
    ofGLFWWindowSettings settings;
    settings.setGLVersion(3, 2);
    settings.setSize(1920, 1080);
    settings.numSamples = 8;
    settings.windowMode = OF_WINDOW;
    settings.title = "oscope-sphere";

    auto window = ofCreateWindow(settings);
    ofRunApp(window, std::make_shared<ofApp>());
    ofRunMainLoop();
    return 0;
}
```

- [ ] **Step 3: Create `oscope-sphere/src/ofApp.h`**

```cpp
#pragma once
#include "ofMain.h"

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void update() override;
    void draw() override;
};
```

- [ ] **Step 4: Create `oscope-sphere/src/ofApp.cpp`**

```cpp
#include "ofApp.h"

void ofApp::setup() {
    ofSetFrameRate(60);
    ofBackground(6, 6, 10);
}

void ofApp::update() {}

void ofApp::draw() {
    ofSetColor(230);
    ofDrawBitmapString("oscope-sphere skeleton", 16, 24);
}
```

- [ ] **Step 5: Build and run (manual visual check)**

From an environment with openFrameworks available, run from `oscope-sphere/`:

```bash
make && make Run
```

Expected: compilation succeeds; a 1920x1080 dark window opens showing the text `oscope-sphere skeleton` in the top-left. Close the window to continue.

If the build cannot find openFrameworks, set `OF_ROOT` to the openFrameworks root or place the project under `<OF_ROOT>/apps/myApps/`.

- [ ] **Step 6: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/Makefile oscope-sphere/config.make \
        oscope-sphere/src/main.cpp oscope-sphere/src/ofApp.h \
        oscope-sphere/src/ofApp.cpp
git commit -m "$(cat <<'EOF'
build: add openFrameworks app skeleton

Copy oscope-of's Makefile and libusb-aware config.make, add a window
bootstrap and a placeholder ofApp so the GL build is verified before
any feature code lands.
EOF
)"
```

---

## Task 5: SphereViz skin + full app wiring (Layer A skin)

Adds the icosphere with the scrolling spectrogram as its skin, and rewrites `ofApp` to wire capture → analysis → viz with demo-mode fallback, an orbit camera, a HUD, and key handling.

**Files:**
- Create: `oscope-sphere/src/SphereViz.h`
- Create: `oscope-sphere/src/SphereViz.cpp`
- Create: `oscope-sphere/bin/data/shaders/sphere.vert`
- Create: `oscope-sphere/bin/data/shaders/sphere.frag`
- Modify: `oscope-sphere/src/ofApp.h` (full replacement)
- Modify: `oscope-sphere/src/ofApp.cpp` (full replacement)

- [ ] **Step 1: Create `oscope-sphere/bin/data/shaders/sphere.vert`**

```glsl
#version 150

uniform mat4 modelViewProjectionMatrix;
in vec4 position;

out vec2 vSphereUV;   // x = longitude [0,1], y = latitude [0,1]

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
    gl_Position = modelViewProjectionMatrix * position;
    vSphereUV = vec2(lon, lat);
}
```

- [ ] **Step 2: Create `oscope-sphere/bin/data/shaders/sphere.frag`**

```glsl
#version 150

uniform sampler2D spectroTex;   // width = time, height = freq, R32F [0,1]
uniform float scrollOffset;
uniform int   colormapId;

in vec2 vSphereUV;
out vec4 fragColor;

// Polynomial colormap fits (public domain, Matt Zucker).
vec3 magma(float t) {
    const vec3 c0 = vec3(-0.002136485053939,-0.000749655052795,-0.005386127855323);
    const vec3 c1 = vec3( 0.251660540737164, 0.677523243683767, 2.494026599312351);
    const vec3 c2 = vec3( 8.353717279216625,-3.577719514958484, 0.314467903013257);
    const vec3 c3 = vec3(-27.66873308576866, 14.26473078096533,-13.64921318813922);
    const vec3 c4 = vec3( 52.17613981234068,-27.94360607168351, 12.94416944238394);
    const vec3 c5 = vec3(-50.76852536473588, 29.04658282127291, 4.234152993845980);
    const vec3 c6 = vec3( 18.65570506591883,-11.48977351997711,-5.601961508734096);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}
vec3 viridis(float t) {
    const vec3 c0 = vec3( 0.277727327223418, 0.005407344544967, 0.334099805335306);
    const vec3 c1 = vec3( 0.105093043108577, 1.404613529898575, 1.384590162594685);
    const vec3 c2 = vec3(-0.330861828725556, 0.214847559468213, 0.095095163028237);
    const vec3 c3 = vec3(-4.634230498983486,-5.799100973351585,-19.33244095627987);
    const vec3 c4 = vec3( 6.228269936347081,14.17993336680509, 56.69055260068105);
    const vec3 c5 = vec3( 4.776384997670288,-13.74514537774601,-65.35303263337234);
    const vec3 c6 = vec3(-5.435455855934631, 4.645852612178535, 26.3124352495832);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

void main() {
    float u = fract(vSphereUV.x - scrollOffset);
    float mag = clamp(texture(spectroTex, vec2(u, vSphereUV.y)).r, 0.0, 1.0);
    vec3 col = (colormapId == 0) ? magma(mag) : viridis(mag);
    fragColor = vec4(col, 1.0);
}
```

- [ ] **Step 3: Create `oscope-sphere/src/SphereViz.h`**

```cpp
#pragma once
#include "ofMain.h"
#include "SpectrogramBuffer.h"
#include <memory>
#include <vector>

// GL visual unit: an icosphere whose skin is the scrolling spectrogram.
// The northern hemisphere shows CH1, the southern shows CH2.
class SphereViz {
public:
    void setup(int icoIterations, int spectroWidth, int spectroHeight);

    // Advances the spectrogram by one column and uploads it.
    void pushSpectrogramColumn(const std::vector<float>& magCh1,
                               const std::vector<float>& magCh2);

    void drawSkin();
    void setColormap(int id) { colormapId_ = id; }

private:
    std::unique_ptr<oscope::SpectrogramBuffer> spectro_;
    ofVboMesh   mesh_;
    ofShader    shader_;
    ofTexture   spectroTex_;
    ofFloatPixels spectroPix_;
    float baseRadius_  = 200.0f;
    float scrollOffset_ = 0.0f;
    int   colormapId_  = 0;
};
```

- [ ] **Step 4: Create `oscope-sphere/src/SphereViz.cpp`**

```cpp
#include "SphereViz.h"
#include <algorithm>

void SphereViz::setup(int icoIterations, int spectroWidth, int spectroHeight) {
    spectro_ = std::make_unique<oscope::SpectrogramBuffer>(spectroWidth,
                                                           spectroHeight);

    ofIcoSpherePrimitive ico(baseRadius_, icoIterations);
    ofMesh src = ico.getMesh();
    mesh_.clear();
    mesh_.addVertices(src.getVertices());
    mesh_.addNormals(src.getNormals());
    mesh_.addIndices(src.getIndices());

    ofDisableArbTex();
    spectroPix_.allocate(spectroWidth, spectroHeight, OF_PIXELS_GRAY);
    spectroPix_.set(0.0f);
    spectroTex_.allocate(spectroPix_);
    spectroTex_.setTextureWrap(GL_REPEAT, GL_CLAMP_TO_EDGE);
    spectroTex_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    shader_.load("shaders/sphere");
}

void SphereViz::pushSpectrogramColumn(const std::vector<float>& magCh1,
                                      const std::vector<float>& magCh2) {
    spectro_->pushColumn(magCh1, magCh2);
    const std::vector<float>& d = spectro_->data();
    std::copy(d.begin(), d.end(), spectroPix_.getData());
    spectroTex_.loadData(spectroPix_);
    scrollOffset_ = static_cast<float>(spectro_->writeIndex()) /
                    static_cast<float>(spectro_->width());
}

void SphereViz::drawSkin() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1i("colormapId", colormapId_);
    mesh_.draw();
    shader_.end();
}
```

- [ ] **Step 5: Replace `oscope-sphere/src/ofApp.h` with the full app header**

```cpp
#pragma once
#include "ofMain.h"
#include "HantekDevice.h"
#include "AudioAnalyzer.h"
#include "DemoSignal.h"
#include "SphereViz.h"
#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
    void setup() override;
    void update() override;
    void draw() override;
    void keyPressed(int key) override;

private:
    void drawHud();

    oscope::HantekDevice  hantek_;
    oscope::AudioAnalyzer analyzerCh1_;
    oscope::AudioAnalyzer analyzerCh2_;
    oscope::DemoSignal    demo_{48000.0f};

    SphereViz sphere_;
    ofEasyCam cam_;

    std::vector<float> buf1_;
    std::vector<float> buf2_;

    bool  demoMode_ = false;
    bool  frozen_   = false;
    bool  layerA_   = true;
    bool  layerB_   = true;
    bool  layerC_   = true;
    int   colormap_ = 0;
    float scopeSr_  = 16.0e6f;
    std::string statusText_;
};
```

- [ ] **Step 6: Replace `oscope-sphere/src/ofApp.cpp` with the full app body**

```cpp
#include "ofApp.h"

void ofApp::setup() {
    ofSetFrameRate(60);
    ofSetVerticalSync(true);
    ofBackground(6, 6, 10);
    ofEnableDepthTest();
    glEnable(GL_PROGRAM_POINT_SIZE);

    cam_.setDistance(750.0f);
    cam_.setNearClip(1.0f);
    cam_.setFarClip(5000.0f);

    sphere_.setup(5, 512, 256);

    hantek_.setSampleRate(16000000u);
    const oscope::HantekStatus st = hantek_.start();
    if (st == oscope::HantekStatus::Ok) {
        demoMode_ = false;
        statusText_ = "SCOPE OK";
    } else {
        demoMode_ = true;
        statusText_ = (st == oscope::HantekStatus::FirmwareNeeded)
            ? "DEMO - firmware needed (see docs/HANTEK_SETUP.md)"
            : "DEMO - scope not found";
    }
}

void ofApp::update() {
    if (frozen_) return;

    if (demoMode_) {
        demo_.next(buf1_, buf2_, 8192);
    } else {
        hantek_.ring().readLatest(buf1_, buf2_, 8192);
        if (hantek_.status() != oscope::HantekStatus::Ok) {
            demoMode_ = true;
            statusText_ = "DEMO - scope lost";
        }
    }

    const float sr = demoMode_ ? 48000.0f : scopeSr_;
    analyzerCh1_.update(buf1_, buf1_, sr);
    analyzerCh2_.update(buf2_, buf2_, sr);

    sphere_.setColormap(colormap_);
    sphere_.pushSpectrogramColumn(analyzerCh1_.magDown(),
                                  analyzerCh2_.magDown());
}

void ofApp::draw() {
    cam_.begin();
    ofPushMatrix();
    ofRotateYDeg(ofGetElapsedTimef() * 6.0f);
    if (layerA_) sphere_.drawSkin();
    ofPopMatrix();
    cam_.end();
    drawHud();
}

void ofApp::drawHud() {
    ofDisableDepthTest();
    ofSetColor(230);
    std::string hud = statusText_ + "\n";
    hud += std::string("[1] skin   ") + (layerA_ ? "on" : "off") + "\n";
    hud += std::string("[2] rings  ") + (layerB_ ? "on" : "off") + "\n";
    hud += std::string("[3] points ") + (layerC_ ? "on" : "off") + "\n";
    hud += std::string("[c] colormap   [space] ") +
           (frozen_ ? "frozen" : "live");
    ofDrawBitmapString(hud, 16, 24);
    ofEnableDepthTest();
}

void ofApp::keyPressed(int key) {
    switch (key) {
        case '1': layerA_ = !layerA_; break;
        case '2': layerB_ = !layerB_; break;
        case '3': layerC_ = !layerC_; break;
        case 'c':
        case 'C': colormap_ = (colormap_ + 1) % 2; break;
        case ' ': frozen_ = !frozen_; break;
    }
}
```

- [ ] **Step 7: Build and run (manual visual check)**

From `oscope-sphere/`:

```bash
make && make Run
```

Expected: a slowly rotating sphere whose surface shows a scrolling colored spectrogram (magma palette). With no scope connected the HUD reads `DEMO - scope not found` and the skin animates from the demo signal. Mouse drag orbits the camera. `c` switches to the viridis palette. `space` freezes the scroll. Close to continue.

- [ ] **Step 8: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/SphereViz.h oscope-sphere/src/SphereViz.cpp \
        oscope-sphere/src/ofApp.h oscope-sphere/src/ofApp.cpp \
        oscope-sphere/bin/data/shaders/sphere.vert \
        oscope-sphere/bin/data/shaders/sphere.frag
git commit -m "$(cat <<'EOF'
feat: render spectrogram sphere skin

Add SphereViz with an icosphere skinned by the scrolling spectrogram
texture, and wire ofApp end to end: capture or demo fallback, dual
per-channel analysis, orbit camera, HUD, and key handling.
EOF
)"
```

---

## Task 6: Waveform displacement (Layer A geometry)

Makes the sphere geometry breathe with the live waveform. Each vertex is displaced radially by the time-domain signal: northern vertices follow CH1, southern follow CH2.

**Files:**
- Modify: `oscope-sphere/bin/data/shaders/sphere.vert` (full replacement)
- Modify: `oscope-sphere/src/SphereViz.h` (full replacement)
- Modify: `oscope-sphere/src/SphereViz.cpp` (full replacement)
- Modify: `oscope-sphere/src/ofApp.cpp` (one added line in `update()`)

- [ ] **Step 1: Replace `oscope-sphere/bin/data/shaders/sphere.vert`**

```glsl
#version 150

uniform mat4 modelViewProjectionMatrix;
uniform sampler2D waveformTex;   // width = samples, height = 2 (row0 CH1, row1 CH2)
uniform float displaceAmount;
uniform float baseRadius;

in vec4 position;

out vec2 vSphereUV;   // x = longitude [0,1], y = latitude [0,1]

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;

    float row  = (dir.y >= 0.0) ? 0.25 : 0.75;          // CH1 north, CH2 south
    float wave = texture(waveformTex, vec2(lon, row)).r; // [-1,1]
    float r    = baseRadius * (1.0 + displaceAmount * wave);

    gl_Position = modelViewProjectionMatrix * vec4(dir * r, 1.0);
    vSphereUV = vec2(lon, lat);
}
```

- [ ] **Step 2: Replace `oscope-sphere/src/SphereViz.h`**

```cpp
#pragma once
#include "ofMain.h"
#include "SpectrogramBuffer.h"
#include <memory>
#include <vector>

// GL visual unit: an icosphere skinned by the scrolling spectrogram and
// displaced radially by the live waveform. Northern hemisphere = CH1,
// southern = CH2.
class SphereViz {
public:
    void setup(int icoIterations, int spectroWidth, int spectroHeight,
               int waveformLen);

    void pushSpectrogramColumn(const std::vector<float>& magCh1,
                               const std::vector<float>& magCh2);
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);

    void drawSkin();
    void setColormap(int id) { colormapId_ = id; }

private:
    std::unique_ptr<oscope::SpectrogramBuffer> spectro_;
    ofVboMesh     mesh_;
    ofShader      shader_;
    ofTexture     spectroTex_;
    ofTexture     waveTex_;
    ofFloatPixels spectroPix_;
    ofFloatPixels wavePix_;
    int   waveformLen_ = 0;
    float baseRadius_  = 200.0f;
    float scrollOffset_ = 0.0f;
    float displace_    = 0.18f;
    int   colormapId_  = 0;
};
```

- [ ] **Step 3: Replace `oscope-sphere/src/SphereViz.cpp`**

```cpp
#include "SphereViz.h"
#include <algorithm>

void SphereViz::setup(int icoIterations, int spectroWidth, int spectroHeight,
                      int waveformLen) {
    waveformLen_ = waveformLen;
    spectro_ = std::make_unique<oscope::SpectrogramBuffer>(spectroWidth,
                                                           spectroHeight);

    ofIcoSpherePrimitive ico(baseRadius_, icoIterations);
    ofMesh src = ico.getMesh();
    mesh_.clear();
    mesh_.addVertices(src.getVertices());
    mesh_.addNormals(src.getNormals());
    mesh_.addIndices(src.getIndices());

    ofDisableArbTex();
    spectroPix_.allocate(spectroWidth, spectroHeight, OF_PIXELS_GRAY);
    spectroPix_.set(0.0f);
    spectroTex_.allocate(spectroPix_);
    spectroTex_.setTextureWrap(GL_REPEAT, GL_CLAMP_TO_EDGE);
    spectroTex_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    wavePix_.allocate(waveformLen, 2, OF_PIXELS_GRAY);
    wavePix_.set(0.0f);
    waveTex_.allocate(wavePix_);
    waveTex_.setTextureWrap(GL_REPEAT, GL_CLAMP_TO_EDGE);
    waveTex_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    shader_.load("shaders/sphere");
}

void SphereViz::pushSpectrogramColumn(const std::vector<float>& magCh1,
                                      const std::vector<float>& magCh2) {
    spectro_->pushColumn(magCh1, magCh2);
    const std::vector<float>& d = spectro_->data();
    std::copy(d.begin(), d.end(), spectroPix_.getData());
    spectroTex_.loadData(spectroPix_);
    scrollOffset_ = static_cast<float>(spectro_->writeIndex()) /
                    static_cast<float>(spectro_->width());
}

void SphereViz::setWaveform(const std::vector<float>& ch1,
                            const std::vector<float>& ch2) {
    float* px = wavePix_.getData();
    const int L = waveformLen_;
    auto fillRow = [&](const std::vector<float>& src, int row) {
        const int n = static_cast<int>(src.size());
        for (int i = 0; i < L; ++i) {
            float v = 0.0f;
            if (n > 0) {
                int idx = n - L + i;          // newest L samples
                if (idx < 0) idx = 0;
                v = src[idx];
            }
            px[row * L + i] = v;
        }
    };
    fillRow(ch1, 0);
    fillRow(ch2, 1);
    waveTex_.loadData(wavePix_);
}

void SphereViz::drawSkin() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniformTexture("waveformTex", waveTex_, 1);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1f("displaceAmount", displace_);
    shader_.setUniform1f("baseRadius", baseRadius_);
    shader_.setUniform1i("colormapId", colormapId_);
    mesh_.draw();
    shader_.end();
}
```

- [ ] **Step 4: Update `oscope-sphere/src/ofApp.cpp` — `setup()` and `update()`**

In `setup()`, change the `sphere_.setup` call to pass the waveform length:

```cpp
    sphere_.setup(5, 512, 256, 1024);
```

In `update()`, add the `setWaveform` call immediately after `pushSpectrogramColumn`, so the block reads:

```cpp
    sphere_.setColormap(colormap_);
    sphere_.pushSpectrogramColumn(analyzerCh1_.magDown(),
                                  analyzerCh2_.magDown());
    sphere_.setWaveform(buf1_, buf2_);
```

- [ ] **Step 5: Build and run (manual visual check)**

From `oscope-sphere/`:

```bash
make && make Run
```

Expected: the spectrogram sphere now visibly deforms — its surface bulges and ripples with the live waveform, the northern half driven by CH1 and the southern half by CH2. In demo mode the northern half pulses with the sweep, the southern half with the steady 440 Hz tone. Close to continue.

- [ ] **Step 6: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/SphereViz.h oscope-sphere/src/SphereViz.cpp \
        oscope-sphere/src/ofApp.cpp \
        oscope-sphere/bin/data/shaders/sphere.vert
git commit -m "$(cat <<'EOF'
feat: displace sphere with live waveform

Upload the per-channel waveform as a texture and displace icosphere
vertices radially in the vertex shader: CH1 drives the northern
hemisphere, CH2 the southern.
EOF
)"
```

---

## Task 7: Stereo waveform orbit rings (Layer B)

Adds two 3D line-loop rings orbiting the sphere in perpendicular planes, each rippling with one channel's live waveform.

**Files:**
- Create: `oscope-sphere/src/OrbitRings.h`
- Create: `oscope-sphere/src/OrbitRings.cpp`
- Modify: `oscope-sphere/src/ofApp.h` (add include + member)
- Modify: `oscope-sphere/src/ofApp.cpp` (setup, update, draw)

- [ ] **Step 1: Create `oscope-sphere/src/OrbitRings.h`**

```cpp
#pragma once
#include "ofMain.h"
#include <vector>

// GL visual unit: two line-loop rings orbiting the sphere in
// perpendicular planes. Ring 1 follows CH1, ring 2 follows CH2; each
// point's orbit radius is modulated by the live waveform.
class OrbitRings {
public:
    void setup(int pointsPerRing);
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);
    void draw();

private:
    int       n_          = 0;
    float     baseRadius_ = 300.0f;
    float     amp_        = 70.0f;
    ofVboMesh ring1_;   // CH1, XZ plane
    ofVboMesh ring2_;   // CH2, XY plane
};
```

- [ ] **Step 2: Create `oscope-sphere/src/OrbitRings.cpp`**

```cpp
#include "OrbitRings.h"
#include <cmath>

void OrbitRings::setup(int pointsPerRing) {
    n_ = pointsPerRing;
    ring1_.clear();
    ring2_.clear();
    ring1_.setMode(OF_PRIMITIVE_LINE_LOOP);
    ring2_.setMode(OF_PRIMITIVE_LINE_LOOP);
    for (int i = 0; i < n_; ++i) {
        ring1_.addVertex(glm::vec3(0.0f));
        ring2_.addVertex(glm::vec3(0.0f));
    }
}

void OrbitRings::setWaveform(const std::vector<float>& ch1,
                             const std::vector<float>& ch2) {
    const float twoPi = 6.28318530718f;
    auto rebuild = [&](ofVboMesh& ring, const std::vector<float>& src,
                       bool xzPlane) {
        const int n = static_cast<int>(src.size());
        for (int i = 0; i < n_; ++i) {
            const float theta = twoPi * static_cast<float>(i) / n_;
            float s = 0.0f;
            if (n > 0) {
                int idx = static_cast<int>(
                    static_cast<long long>(i) * n / n_);
                if (idx >= n) idx = n - 1;
                s = src[idx];
            }
            const float r = baseRadius_ + amp_ * s;
            const glm::vec3 p = xzPlane
                ? glm::vec3(r * std::cos(theta), 0.0f, r * std::sin(theta))
                : glm::vec3(r * std::cos(theta), r * std::sin(theta), 0.0f);
            ring.setVertex(i, p);
        }
    };
    rebuild(ring1_, ch1, true);
    rebuild(ring2_, ch2, false);
}

void OrbitRings::draw() {
    ofPushStyle();
    ofSetLineWidth(2.0f);
    ofSetColor(80, 200, 255);
    ring1_.draw();
    ofSetColor(255, 140, 80);
    ring2_.draw();
    ofPopStyle();
}
```

- [ ] **Step 3: Update `oscope-sphere/src/ofApp.h`**

Add the include alongside the other project includes:

```cpp
#include "OrbitRings.h"
```

Add the member immediately after the `SphereViz sphere_;` line:

```cpp
    OrbitRings rings_;
```

- [ ] **Step 4: Update `oscope-sphere/src/ofApp.cpp`**

In `setup()`, add this line right after `sphere_.setup(5, 512, 256, 1024);`:

```cpp
    rings_.setup(512);
```

In `update()`, add this line right after `sphere_.setWaveform(buf1_, buf2_);`:

```cpp
    rings_.setWaveform(buf1_, buf2_);
```

In `draw()`, add the rings draw call so the layer block reads:

```cpp
    if (layerA_) sphere_.drawSkin();
    if (layerB_) rings_.draw();
```

- [ ] **Step 5: Build and run (manual visual check)**

From `oscope-sphere/`:

```bash
make && make Run
```

Expected: two rings now orbit the sphere — a blue ring (CH1) in one plane and an orange ring (CH2) in a perpendicular plane — each rippling with its channel's waveform. Pressing `2` toggles the rings off and on. Close to continue.

- [ ] **Step 6: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/OrbitRings.h oscope-sphere/src/OrbitRings.cpp \
        oscope-sphere/src/ofApp.h oscope-sphere/src/ofApp.cpp
git commit -m "$(cat <<'EOF'
feat: add stereo waveform orbit rings

Two perpendicular line-loop rings orbit the sphere, the blue ring
modulated by CH1 and the orange ring by CH2, toggled with key 2.
EOF
)"
```

---

## Task 8: Point-cloud sphere layer (Layer C)

Adds a particle rendering of the same sphere — every vertex drawn as a rounded point, displaced and colored exactly like the skin.

**Files:**
- Modify: `oscope-sphere/bin/data/shaders/sphere.vert` (full replacement)
- Modify: `oscope-sphere/bin/data/shaders/sphere.frag` (full replacement)
- Modify: `oscope-sphere/src/SphereViz.h` (add `drawPoints` declaration)
- Modify: `oscope-sphere/src/SphereViz.cpp` (refactor draw, add `drawPoints`)
- Modify: `oscope-sphere/src/ofApp.cpp` (add `drawPoints` call)

- [ ] **Step 1: Replace `oscope-sphere/bin/data/shaders/sphere.vert`**

```glsl
#version 150

uniform mat4 modelViewProjectionMatrix;
uniform sampler2D waveformTex;   // width = samples, height = 2 (row0 CH1, row1 CH2)
uniform float displaceAmount;
uniform float baseRadius;
uniform int   renderMode;        // 0 = skin, 1 = points

in vec4 position;

out vec2 vSphereUV;   // x = longitude [0,1], y = latitude [0,1]

const float PI = 3.14159265359;

void main() {
    vec3 dir = normalize(position.xyz);
    float lon = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float lat = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;

    float row  = (dir.y >= 0.0) ? 0.25 : 0.75;          // CH1 north, CH2 south
    float wave = texture(waveformTex, vec2(lon, row)).r; // [-1,1]
    float r    = baseRadius * (1.0 + displaceAmount * wave);

    gl_Position = modelViewProjectionMatrix * vec4(dir * r, 1.0);
    if (renderMode == 1) {
        gl_PointSize = 3.0;
    }
    vSphereUV = vec2(lon, lat);
}
```

- [ ] **Step 2: Replace `oscope-sphere/bin/data/shaders/sphere.frag`**

```glsl
#version 150

uniform sampler2D spectroTex;   // width = time, height = freq, R32F [0,1]
uniform float scrollOffset;
uniform int   colormapId;
uniform int   renderMode;       // 0 = skin, 1 = points

in vec2 vSphereUV;
out vec4 fragColor;

// Polynomial colormap fits (public domain, Matt Zucker).
vec3 magma(float t) {
    const vec3 c0 = vec3(-0.002136485053939,-0.000749655052795,-0.005386127855323);
    const vec3 c1 = vec3( 0.251660540737164, 0.677523243683767, 2.494026599312351);
    const vec3 c2 = vec3( 8.353717279216625,-3.577719514958484, 0.314467903013257);
    const vec3 c3 = vec3(-27.66873308576866, 14.26473078096533,-13.64921318813922);
    const vec3 c4 = vec3( 52.17613981234068,-27.94360607168351, 12.94416944238394);
    const vec3 c5 = vec3(-50.76852536473588, 29.04658282127291, 4.234152993845980);
    const vec3 c6 = vec3( 18.65570506591883,-11.48977351997711,-5.601961508734096);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}
vec3 viridis(float t) {
    const vec3 c0 = vec3( 0.277727327223418, 0.005407344544967, 0.334099805335306);
    const vec3 c1 = vec3( 0.105093043108577, 1.404613529898575, 1.384590162594685);
    const vec3 c2 = vec3(-0.330861828725556, 0.214847559468213, 0.095095163028237);
    const vec3 c3 = vec3(-4.634230498983486,-5.799100973351585,-19.33244095627987);
    const vec3 c4 = vec3( 6.228269936347081,14.17993336680509, 56.69055260068105);
    const vec3 c5 = vec3( 4.776384997670288,-13.74514537774601,-65.35303263337234);
    const vec3 c6 = vec3(-5.435455855934631, 4.645852612178535, 26.3124352495832);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

void main() {
    float u = fract(vSphereUV.x - scrollOffset);
    float mag = clamp(texture(spectroTex, vec2(u, vSphereUV.y)).r, 0.0, 1.0);
    vec3 col = (colormapId == 0) ? magma(mag) : viridis(mag);
    if (renderMode == 1) {
        vec2 d = gl_PointCoord - vec2(0.5);
        if (dot(d, d) > 0.25) discard;       // round the points
    }
    fragColor = vec4(col, 1.0);
}
```

- [ ] **Step 3: Update `oscope-sphere/src/SphereViz.h`**

Add the `drawPoints` declaration immediately after the `drawSkin` declaration:

```cpp
    void drawSkin();
    void drawPoints();
```

- [ ] **Step 4: Replace the `drawSkin` definition in `oscope-sphere/src/SphereViz.cpp`**

Replace the existing `drawSkin()` function at the end of the file with a shared uniform helper plus both draw functions:

```cpp
void SphereViz::drawSkin() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniformTexture("waveformTex", waveTex_, 1);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1f("displaceAmount", displace_);
    shader_.setUniform1f("baseRadius", baseRadius_);
    shader_.setUniform1i("colormapId", colormapId_);
    shader_.setUniform1i("renderMode", 0);
    mesh_.draw();
    shader_.end();
}

void SphereViz::drawPoints() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniformTexture("waveformTex", waveTex_, 1);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1f("displaceAmount", displace_);
    shader_.setUniform1f("baseRadius", baseRadius_);
    shader_.setUniform1i("colormapId", colormapId_);
    shader_.setUniform1i("renderMode", 1);
    mesh_.drawVertices();
    shader_.end();
}
```

- [ ] **Step 5: Update `oscope-sphere/src/ofApp.cpp` — `draw()`**

Add the point-cloud draw call so the layer block reads:

```cpp
    if (layerA_) sphere_.drawSkin();
    if (layerC_) sphere_.drawPoints();
    if (layerB_) rings_.draw();
```

- [ ] **Step 6: Build and run (manual visual check)**

From `oscope-sphere/`:

```bash
make && make Run
```

Expected: with all layers on, the sphere shows the solid skin, the orbit rings, and a shell of rounded particles (one per icosphere vertex), all colored by the spectrogram and displaced by the waveform. Press `1` to drop the skin and see the point cloud clearly; `3` toggles the points. Close to continue.

- [ ] **Step 7: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/src/SphereViz.h oscope-sphere/src/SphereViz.cpp \
        oscope-sphere/src/ofApp.cpp \
        oscope-sphere/bin/data/shaders/sphere.vert \
        oscope-sphere/bin/data/shaders/sphere.frag
git commit -m "$(cat <<'EOF'
feat: add point-cloud sphere layer

Render the icosphere vertices as rounded points sharing the skin's
displacement and colormap, switched by a renderMode uniform and
toggled with key 3.
EOF
)"
```

---

## Task 9: Project documentation

Adds the project's own `CLAUDE.md` and `README.md`, matching the style of `oscope-of/CLAUDE.md`.

**Files:**
- Create: `oscope-sphere/CLAUDE.md`
- Create: `oscope-sphere/README.md`

- [ ] **Step 1: Create `oscope-sphere/CLAUDE.md`**

```markdown
# oscope-sphere

Visualiseur openFrameworks C++ : capture Hantek 6022 (2 canaux) via
libusb -> FFT -> une sphere 3D stereo avec 3 couches composables.
Derive de `oscope-of` (couche capture reutilisee, demoparty jetee).

## Build

```bash
cd oscope-sphere
make            # debug
make Release    # release
make Run        # lance bin/oscope-sphere

./tests/run_tests.sh   # tests C++ purs (clang++, sans openFrameworks)
```

Cible macOS principale (Hantek via libusb). `config.make` detecte
libusb (pkg-config, puis brew, puis chemins par defaut).

## Architecture

| Composant | Fichier |
|-----------|---------|
| Capture USB Hantek 6022 (16 MS/s, 2 ch) | `HantekDevice.{h,cpp}` (copie) |
| Downsampling + FFT 2048 | `AudioAnalyzer.{h,cpp}`, `FFT.{h,cpp}` (copie) |
| Ring buffer SPSC CH1/CH2 | `ScopeData.h` (copie) |
| Spectrogramme roulant log-freq | `SpectrogramBuffer.{h,cpp}` |
| Signal de demo (pas de scope) | `DemoSignal.{h,cpp}` |
| Sphere : peau spectro + relief waveform + points | `SphereViz.{h,cpp}` |
| Anneaux waveform orbitaux | `OrbitRings.{h,cpp}` |
| Cycle de vie, camera, HUD | `ofApp.{h,cpp}`, `main.cpp` |
| Shaders sphere | `bin/data/shaders/sphere.{vert,frag}` |

## Convention canaux

La sphere est coupee a l'equateur : hemisphere Nord = CH1, Sud = CH2.
Cette convention tient sur les 3 couches.

## Couches (touches 1 / 2 / 3)

- A (`1`) : sphere — peau spectrogramme + deplacement waveform
- B (`2`) : deux anneaux waveform orbitaux (un par canal)
- C (`3`) : nuage de points
- `c` : cycle colormap (magma / viridis) ; `space` : fige le defilement

## Conventions

- GLSL 150 GL 3.2 core uniquement. Shaders dans `bin/data/shaders/`.
- Pas d'allocations dans `update()` / `draw()` — buffers preallouees.
- AudioAnalyzer mixe ses 2 arguments : `update(chX, chX)` isole chX.
  Deux analyzers, un par canal.
- 24/48 MS/s sont mono-canal sur le firmware OpenHantek6022 — la
  capture deux-canaux tourne donc a 16 MS/s.
- Scope absent -> mode demo automatique (signal synthetique).

## Anti-patterns

- Ne pas committer `bin/oscope-sphere*` (binaires).
- Ne pas faire d'I/O fichier ni de `new` dans la hot loop.
- Ne pas modifier les 4 fichiers copies de `oscope-of` — les
  resynchroniser depuis `oscope-of/src/` si besoin.
```

- [ ] **Step 2: Create `oscope-sphere/README.md`**

```markdown
# oscope-sphere

A minimal openFrameworks visualiser: it captures both channels of a
Hantek 6022 oscilloscope and renders them as a single 3D sphere.

The sphere is split at the equator — **northern hemisphere = CH1,
southern hemisphere = CH2** — across three composable layers:

- **Layer A** — the sphere itself: its skin is a scrolling spectrogram
  (latitude = log frequency, longitude = time) and its geometry is
  displaced radially by the live waveform.
- **Layer B** — two waveform rings orbiting the sphere in perpendicular
  planes, one per channel.
- **Layer C** — the sphere rendered as a point cloud.

It reuses the capture and analysis layer of the sibling `oscope-of`
project.

## Build and run

```bash
cd oscope-sphere
make && make Run
```

Requires openFrameworks (GL 3.2 core) and libusb-1.0. Without a scope
connected the app runs in demo mode on a synthetic signal.

## Controls

| Key | Action |
|-----|--------|
| `1` / `2` / `3` | toggle layers A / B / C |
| `c` | cycle colormap (magma / viridis) |
| `space` | freeze the spectrogram scroll |
| mouse drag | orbit the camera |

## Tests

```bash
./tests/run_tests.sh
```

Runs the pure-C++ unit tests (FFT, per-channel split, spectrogram
buffer, demo signal) — no openFrameworks needed.

## Hardware note

24/48 MS/s are single-channel-only on the OpenHantek6022 firmware;
because both channels are used, capture runs at 16 MS/s. Only one
process may own the scope at a time — close OpenHantek6022 before
running this app.

## License

GPL-3.0, as part of the AV-Live monorepo.
```

- [ ] **Step 3: Verify the docs**

Run from `/tmp/AV-Live`:

```bash
ls oscope-sphere/CLAUDE.md oscope-sphere/README.md && \
  head -1 oscope-sphere/CLAUDE.md oscope-sphere/README.md
```

Expected: both files exist and print their first heading line.

- [ ] **Step 4: Commit**

```bash
cd /tmp/AV-Live
git add oscope-sphere/CLAUDE.md oscope-sphere/README.md
git commit -m "$(cat <<'EOF'
docs: document oscope-sphere project

Add the project CLAUDE.md and README covering the build, the stereo
channel convention, the three layers, controls, and the 16 MS/s
dual-channel hardware constraint.
EOF
)"
```

---

## Done

After Task 9 the `oscope-sphere/` project is complete: a dual-channel Hantek 6022 visualiser rendering one stereo sphere with three composable layers. The pure-C++ units are unit-tested via `tests/run_tests.sh`; the GL layers were verified visually at each task.

**Follow-up (out of scope, not planned here):** moving the result out of `/tmp/AV-Live` into the real repo — either push the branch or copy the `oscope-sphere/` tree once the TCC lock on `~/Documents/Projets/AV-Live` is resolved.
