# AV-Live

Live coding audio-visual performance system : moteur SuperCollider, visualiseur openFrameworks piloté par un oscilloscope Hantek 6022BL, app menubar macOS qui orchestre le tout.

## Communication

Toujours répondre en français à l'utilisateur. Code, commentaires de code, commits et docs en anglais.

## Stack par sous-projet

| Sous-projet | Stack |
|-------------|-------|
| `sound_algo/` | SuperCollider (sclang + scsynth), 1099 SynthDefs, 345 tracks |
| `oscope-of/` | openFrameworks C++, libusb (Hantek bulk), GLSL 150 GL 3.2 core |
| `launcher/` | SwiftUI menubar app, Swift Package Manager |
| `data_only_viz/` | Python 3.11+ via `uv`, Metal natif (pyobjc), multi-backends pose |
| `web_realart/` | Node.js, Express, OSC bridge |

## Where to Look

| Tâche | Emplacement |
|-------|-------------|
| Ajouter / modifier un SynthDef, track, palette | `sound_algo/` (déjà documenté en nested) |
| Toucher au visualiseur, shaders, FFT, Hantek | `oscope-of/` |
| Modifier l'app menubar macOS | `launcher/` |
| Détection pose / mesh / body tracking | `data_only_viz/` |
| Bridge web / UI de live coding | `web_realart/` |
| Plans / specs en cours | `docs/superpowers/plans/` |

## Network topology

| Host | mDNS | IP (DHCP) | Role |
|------|------|-----------|------|
| GrosMac M5 | `grosmac.local` | LAN | Source + visualisation (AVLiveBody + data_only_viz + data_feeds) |
| macm1 M1 Max | `supra-m1.local` | `192.168.0.175` | Sink (Multi-HMR CoreML + Apple Vision ANE + SMPL-X TCP) |
| iPhone 16 Pro | (Personal Hotspot) | DHCP | ARKit/LiDAR pub via OSC `/body3d/kp` |

`AVBODY_HOST` / `MULTIHMR_REMOTE_HOST` accept mDNS hostnames — résiste aux changements DHCP (notamment iPhone hotspot 172.20.10.x).

## Environment variables

| Env | Default | Effect |
|-----|---------|--------|
| `POSE_FILTER` | `median+kalman+lookahead+ik` | filter chain stages — extra: `one_euro_joints` (joint-space CHI 2012 One Euro, inserted before kalman), `one_euro_bones` (bone-vector One Euro applied after SMPL-X fusion in multi.py), `arkit_fuse` (overrides 14 body slots with ARKit ARSkeleton3D from the iOS app, expects /body3d/kp on :57128) |
| `IPHONE_OSC_PORT` | `57128` | UDP port the iPhone ARBodyTracker app pushes /body3d/kp to (always-on listener in data_only_viz) |
| `ICP_FUSION` | `0` | `1` to enable LiDAR↔SMPL-X ICP fusion (cf. `docs/ICP_FUSION.md`) |
| `ICP_LIDAR_HOST` | _(unset)_ | iPhone ARBodyTracker IP when `ICP_FUSION=1` |
| `ICP_LIDAR_PORT` | `5500` | iPhone ARMesh TCP port |
| `ICP_LIDAR_EXTRINSIC` | `~/.config/av-live/lidar_extrinsic.json` | extrinsic JSON path |

## Conventions globales

- Python : **uv** systématiquement (jamais pip/poetry/conda directs).
- Pas d'emojis dans code/docs/commits sauf demande explicite.
- Commits : sujet ≤ 50 char, body ≤ 72 char/ligne, pas d'attribution AI, pas de `--no-verify`, pas d'underscore dans le scope (hooks enforcent).
- `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` exclus par `.gitignore` racine.

## Agent Workflow

Explore localise → librarian lit (>500 lignes) → tu raisonnes → general-purpose implémente → validator vérifie. Lance les tâches indépendantes en parallèle.

## Guidance imbriquée

Chaque sous-projet majeur a son propre `CLAUDE.md`. Claude charge automatiquement le plus proche du fichier édité (« closest wins »). N'ajouter ici que ce qui s'applique à TOUS les sous-projets.
