# AVLiveLauncher

macOS menubar launcher for AV-Live. Starts and stops `sclang` (which
auto-loads `sound_algo/00_load.scd` and serves the web UI) and the
`oscope-of` visualizer with one click each, and aggregates their logs in
one window.

## Build

Requires Swift 5.7+ and Xcode Command Line Tools.

```sh
cd launcher
./build.sh
open build/AVLiveLauncher.app
```

The first run shows a `waveform.path.ecg` icon in the menubar. Click it
to open the popover.

## Configuration

Three paths are stored in `UserDefaults` (`~/Library/Preferences/cc.saillant.AVLiveLauncher.plist`) :

| Default | Override |
|---------|----------|
| `/Applications/SuperCollider.app/Contents/MacOS/sclang` | Paths… → sclang binary |
| `~/Documents/Projets/AV-Live/sound_algo/00_load.scd` | Paths… → load file |
| `~/Documents/Projets/AV-Live/oscope-of/bin/oscope-of` | Paths… → oscope binary |

## What it does

- Spawns `sclang <load_file>` with stdout/stderr captured into the log
  window. `sclang` itself boots `scsynth`, loads the 1099-SynthDef
  palette, and serves the web bridge on `:8080`.
- Spawns the `oscope-of` binary with cwd set to its parent directory
  (so oF can find `bin/data/`).
- Quitting the menubar app sends `SIGTERM` to both children.
