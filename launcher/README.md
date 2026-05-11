# AVLiveLauncher

macOS menubar launcher for AV-Live. Starts and stops `sclang` (which
auto-loads `sound_algo/00_load.scd` and serves the web UI), the
`oscope-of` visualizer, and the `data_feeds` Python bridge (USGS,
SWPC, grid frequency, lightning, pose, etc. → OSC) with one click
each, and aggregates their logs in one window.

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
| `/opt/homebrew/bin/uv` (or `~/.local/bin/uv`) | Paths… → uv binary |
| `~/Documents/Projets/AV-Live/data_feeds` | Paths… → data_feeds directory |

## What it does

- Spawns `sclang <load_file>` with stdout/stderr captured into the log
  window. `sclang` itself boots `scsynth`, loads the 1099-SynthDef
  palette, and serves the web bridge on `:8080`.
- Spawns the `oscope-of` binary with cwd set to its parent directory
  (so oF can find `bin/data/`).
- Spawns `uv run python bridge.py -v` in `data_feeds/` for the real-world
  flux → OSC bridge. Off by default (Auto-start data_feeds toggle in
  Settings to enable). uv auto-syncs the venv on first run.
- Quitting the menubar app sends `SIGTERM` to all children.
