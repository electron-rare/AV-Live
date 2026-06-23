# AGENTS.md

Guidance for AI coding agents (Claude Code, Aider, Cursor, etc.) working in this repo.

## Project

`AV-Live` — live-coding audio-visual performance system: SuperCollider sound engine, openFrameworks visualiser driven by a Hantek 6022BL oscilloscope, and a SwiftUI menubar launcher orchestrating everything. Public, GPL-3. Repo `electron-rare/AV-Live`, branch `main`. Multi-host: GrosMac (source), macm1 (sink / Multi-HMR + Apple Vision ANE), iPhone 16 Pro (ARKit/LiDAR pub).

## Tech stack (per sub-project)

| Sub-project | Stack |
|-------------|-------|
| `sound_algo/` | SuperCollider (sclang + scsynth), 1099 SynthDefs, 345 tracks |
| `oscope-of/` | openFrameworks C++, libusb (Hantek bulk), GLSL 150 / GL 3.2 core |
| `launcher/` | SwiftUI menubar app, Swift Package Manager |
| `data_only_viz/` | Python 3.11+ via `uv`, native Metal (pyobjc), multi-backend pose |
| `data_feeds/` | Python data ingestion |
| `web_realart/` | Node.js, Express, OSC bridge |
| `avlivebody-mac/` | SwiftUI body-tracking client (ARKit/SMPL-X mesh, ad-hoc signed for local dev) |
| `iphone-arbody/` | iOS app, ARBodyTracker, publishes `/body3d/kp` via OSC |

## Commands

```bash
# Python sub-projects (uv only)
cd data_only_viz && uv sync && uv run python -m data_only_viz
cd data_feeds   && uv sync

# openFrameworks
cd oscope-of && make -j

# Web bridge
cd web_realart && npm install && npm start

# Swift
open launcher/Package.swift                # or xcodebuild from CLI
open avlivebody-mac/avlivebody.xcodeproj
```

## Conventions

- Commits: subject ≤ 50 chars, body ≤ 72, no underscore in scope, no AI attribution, never `--no-verify` (hooks enforce).
- Branches: `feat/<name>`, `fix/<name>`, `docs/<name>`, `refactor/<name>`, `chore/<name>`.
- Language: French to the user, English in code/comments/commits.
- No emojis in code/docs/commits unless explicitly requested.
- Python: **always `uv`** (never pip/poetry/conda directly).
- `.gitignore` already excludes `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` at root — don't commit weights.
- License: GPL-3 (whole repo) — keep new files under a compatible license header when adding third-party code.

## File layout

- `sound_algo/` — SC sound engine (own `CLAUDE.md`)
- `oscope-of/` — visualiser
- `launcher/` — macOS menubar
- `data_only_viz/` — pose / mesh / body tracking pipeline (Metal)
- `data_feeds/` — data ingestion
- `web_realart/` — web UI + OSC bridge
- `avlivebody-mac/`, `iphone-arbody/` — body-tracking clients
- `shared/` — cross-sub-project assets
- `third_party/` — vendored deps (CHECK before adding to root deps)
- `tools/` — helper scripts
- `docs/superpowers/plans/` — in-flight plans/specs
- `AV-Live-corrupted-20260514/` — quarantined corrupted snapshot, do not touch

## Domain-specific gotchas

- **mDNS hostnames are required** (`grosmac.local`, `supra-m1.local`) for `AVBODY_HOST` / `MULTIHMR_REMOTE_HOST`. They resist DHCP changes (iPhone hotspot reassigns 172.20.10.x routinely).
- **`POSE_FILTER` chain ordering is load-bearing**: default is `median+kalman+lookahead+ik`. Extras must be inserted at the right stage — `one_euro_joints` BEFORE kalman, `one_euro_bones` AFTER SMPL-X fusion in `multi.py`. `arkit_fuse` overrides 14 body slots with ARKit ARSkeleton3D from iOS app via `/body3d/kp` on `:57128` (always-on listener).
- **`ICP_FUSION=1`** requires `ICP_LIDAR_HOST` (iPhone IP), `ICP_LIDAR_PORT` (default 5500, iPhone ARMesh TCP), and an extrinsic JSON at `~/.config/av-live/lidar_extrinsic.json`. See `docs/ICP_FUSION.md`.
- **iPhone OSC port `57128`** is hardcoded as the publish target for `/body3d/kp` — don't reassign.
- **`avlivebody-mac` requires ad-hoc signing for local dev** (fixed in `85589f2`). Don't strip the signing identity.
- **`onVideoFrame` retain cycle in avlivebody** was fixed in `3b5f29e` — when adding new frame callbacks, mind the strong-self capture.
- **AVLive-Body legacy** has been archived (`9e1482e`); the canonical client is `avlivebody-mac`. Don't reintroduce paths to the old project.
- **macm1 = sink** (Multi-HMR CoreML + Apple Vision ANE + SMPL-X TCP); GrosMac = source. Mind the direction when wiring new OSC topics.
- **Each major sub-project has its own `CLAUDE.md`** — closest wins. Put cross-cutting rules here, sub-project specifics in the nested file.

## When in doubt

- Read root `CLAUDE.md` and the nested `CLAUDE.md` of the sub-project you're editing.
- Recent commits: `git log --oneline -20`.
- Plans: `docs/superpowers/plans/`.
- Cluster context: `~/CLAUDE.md` (GrosMac / macm1 / iPhone topology).
- For sound: read `sound_algo/CLAUDE.md` before touching SynthDefs.
