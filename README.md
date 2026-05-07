# AV-Live

Audio-visual live performance monorepo for solo or small-ensemble live coding sets.

Three components, one launcher :

| Path | Role | Tech |
|------|------|------|
| `sound_algo/` | Sound engine — 1099 SynthDef palette, tracks, web bridge OSC↔WebSocket | SuperCollider 3.13+ |
| `oscope-of/` | Oscilloscope visualizer driven by audio + Hantek 6022BL USB capture | openFrameworks 0.12+ |
| `launcher/` | macOS menubar app : start/stop each component, unified logs | SwiftUI |

## Quick start (macOS)

```bash
# 1. Clone
git clone https://github.com/electron-rare/AV-Live.git
cd AV-Live

# 2. Install dependencies
brew install --cask supercollider
# openFrameworks : download 0.12+ from https://openframeworks.cc/download/

# 3. Build the launcher
cd launcher && xcodebuild -scheme AVLiveLauncher -configuration Release
open build/Release/AVLiveLauncher.app

# 4. Or run components manually
sclang sound_algo/00_load.scd     # boots scsynth + loads palette + serves :8080
cd oscope-of && make && bin/oscope-of   # opens the visualizer
```

## Architecture

```
                  ┌─────────────────────────────────────────┐
                  │  AVLiveLauncher.app  (macOS menubar)    │
                  │  start / stop / logs / status           │
                  └────────┬─────────────┬──────────────────┘
                           │             │
        ┌──────────────────▼─┐       ┌───▼──────────────────┐
        │  sclang + scsynth  │       │  oscope-of (oF .app) │
        │  sound_algo/       │       │  src/main.cpp        │
        │                    │       │                      │
        │  audio :57110 OSC  │ ────► │  OSC :57123 in       │
        │  web  :8080 HTTP   │       │  Hantek USB capture  │
        │  WebSocket :57121  │       │  GPU-accel render    │
        └────────────────────┘       └──────────────────────┘
```

## Components

### `sound_algo/`
Live coding SuperCollider system (forked from `electron-rare/supercollider-live` refonte-v2 branch). Auto-loads 1099 SynthDef across drums/bass/lead/pad/world/master + fx categories. Provides 5-namespace live API (`~kk`/`~mm`/`~ff`/`~cc`/`~p`). 23 pre-composed tracks. Web UI on `:8080`. OSC relay to `oscope-of` on `:57123`.

See [`sound_algo/CLAUDE.md`](sound_algo/CLAUDE.md) for live coding workflow.

### `oscope-of/`
openFrameworks application. Three visualizers : Lissajous (CRT phosphor), spectrogram (perceptual freq mapping), reactive (8-voice shader). Lock-free SPSC ringbuffer for USB→UI thread. FFT with Hann windowing. Optional Hantek 6022BL hardware input.

See [`oscope-of/README.md`](oscope-of/README.md) for build details.

### `launcher/` (macOS only)
SwiftUI menubar app bundle (`.app`). Manages process tree of `sclang`/`scsynth`/`oscope-of`. Unified log viewer. Clean shutdown on quit.

## License

GPL-3.0-or-later (see [`LICENSE`](LICENSE)).

## Author

L'Electron Rare — <https://github.com/electron-rare>
