# AV-Live

Live coding audio-visual performance system : moteur SuperCollider, visualiseur openFrameworks piloté par un oscilloscope Hantek 6022BL, app menubar macOS qui orchestre le tout. **RC0.1+ (tag `v0.1.0-rc1`)** ajoute le pipeline Multi-HMR distribué M5 ↔ macm1 sur LAN gigabit + 10 scènes Metal pose-réactives + unified 3D armature wireframe (body+face+hands).

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
| Multi-HMR remote server pyobjc | `data_only_viz/scripts/multihmr_server.py` (tourne sur macm1) |
| Mesh dense rigger 27 fps perçu | `data_only_viz/mesh_rigger.py` |
| 3D wireframe armature (body+face+hands) | `launcher/AV-Live-Body/Sources/AVLiveBody/Skeleton3DRenderer.swift` |
| Pose → Metal scenes uniforms | `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift` + `Resources/scene.metal` |
| Filter chain (median + Kalman + lookahead + IK) | `data_only_viz/pose_filter.py` |
| DINO re-id pid matching | `data_only_viz/dino_reid.py` |

## RC0.1+ environment variables

| Env | Default | Effect |
|-----|---------|--------|
| `MULTIHMR_BACKEND` | `pytorch` | `pytorch`, `coreml`, `remote` |
| `MULTIHMR_REMOTE_HOST` | `127.0.0.1` | macm1 IP for remote inference |
| `MULTIHMR_REMOTE_JPEG` | `1` | JPEG q=80 on the wire |
| `MULTIHMR_REMOTE_ASYNC` | `1` | client double-buffer queue |
| `MULTIHMR_SERVER_BACKEND` | `pyobjc` | server: `pyobjc` or `coremltools` |
| `MULTIHMR_LOOP_FPS` | `30` | Python worker loop target_fps |
| `AVBODY_HOST` | `127.0.0.1` | route TCP mesh + OSC to remote AVLiveBody |
| `MEDIAPIPE_DELEGATE` | `gpu` | Metal SRGBA (faster); `cpu` fallback for stability |
| `POSE_FILTER` | `median+kalman+lookahead+ik` | filter chain stages |
| `MULTIHMR_REID` | `dino` | DINO cosine matching, `iou` fallback |

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
| `VIDEO_ROTATE` | `none` | rotate the source video frame before MediaPipe + display: `none`/`ccw`/`cw`/`180`. Applied at multi.py read; pose detection + skeleton overlay stay aligned. ARKit 3D joints (gravity-aligned world) are unaffected |
| `ICP_FUSION` | `0` | `1` to enable LiDAR↔SMPL-X ICP fusion (cf. `docs/ICP_FUSION.md`) |
| `ICP_LIDAR_HOST` | _(unset)_ | iPhone ARBodyTracker IP when `ICP_FUSION=1` |
| `ICP_LIDAR_PORT` | `5500` | iPhone ARMesh TCP port |
| `ICP_LIDAR_EXTRINSIC` | `~/.config/av-live/lidar_extrinsic.json` | extrinsic JSON path |
| `FINGER_PIANO` | `0` | `1` enables air-piano finger strike emission from data_only_viz |
| `FINGER_STRIKE_VEL` | `0.02` | downward relative-velocity threshold for a strike (normalized image units/frame) |
| `FINGER_STRIKE_REFRACTORY_MS` | `120` | min ms between strikes per finger |
| `FINGER_SOURCE` | `auto` | hand source for finger gestures: `auto` (iPhone Vision hands if fresh, else MediaPipe), `iphone`, `mediapipe` |
| `FINGER_DEBUG` | `0` | `1` logs each detected strike/pinch (hand, finger) — for threshold tuning |
| `PINCH_RATIO_ON` | `0.50` | thumb-to-finger distance / hand size below which a pinch engages (0.50 validated live 2026-07-02 for ring/pinky reach) |
| `PINCH_RATIO_OFF` | `0.65` | distance/size above which the pinch re-arms (hysteresis) |
| `PINCH_REFRACTORY_MS` | `250` | min ms between pinches per finger |
| `PINCH_MARGIN` | `0.05` | closest-wins margin between nearest and runner-up fingertip (0.05 validated live: 0.20 rejected middle/ring/pinky pinches) |
| `PINCH_EXT_RATIO` | `1.35` | tip-to-wrist distance / hand size above which a finger counts as extended (open-hand pinch gate) |
| `PINCH_EXT_MIN` | `1` | min extended non-pinching fingers required for a pinch to engage; `0` disables the open-hand gate (1 validated live: inner-finger pinches curl neighbours) |
| `PINCH_DEBOUNCE_FRAMES` | `3` | consecutive qualifying frames before a pinch engage fires (release stays immediate); `1` disables |
| `HAND_CONF_MIN` | `0.45` | min Vision hand confidence to draw (raised from 0.3; applies to both overlay and side panels) |
| `HAND_PERSIST_FRAMES` | `3` | consecutive frames a hand track must match before being drawn (1 = off, all hands drawn immediately) |
| `HAND_SWAP_LR` | `0` | Safety knob: invert the Vision chirality interpretation when routing hands (gestures + panels). Chirality validated correct live 2026-07-02; default `0`. Set `1` if a future iPhone app build delivers inverted chirality |
| `HAND_NEAR_MIN` | `0.10` | Minimum wrist-to-middle-MCP distance (normalised) for a hand to trigger pinch/strike. Hands smaller than this are gated out. Display panels are unaffected |
| `HAND_PERSIST_GRACE` | `2` | grace frames before dropping a hand track (0 = strict per-frame) |
| `HAND_NEAR_OFF` | `0.08` | hand size hysteresis off-threshold for gesture slot stabilizer |
| `HAND_HOLD_FRAMES` | `2` | gesture slot: frames to hold last hand on Vision miss |
| `HAND_FACE_MIN` | `0.5` | palm-spread ratio threshold — gesture slot arms only when hand_facing >= this (palm-facing ~0.7-1.0, side-on < 0.4; 0.8× hysteresis for off) |
| `ARKIT_BONE_MAX` | `0.5` | max ARKit body bone length in normalized units; longer bones are skipped (tracking-loss garbage filter) |
| `PINCH_ENABLE` | `0` | enable pinch gesture detection |
| `VIZ_HUD` | `0` | show debug HUD overlay |
| `CONCERT_MIRROR` | `1` | mirror video horizontally (!=0 enables) |

## Conventions globales

- Python : **uv** systématiquement (jamais pip/poetry/conda directs).
- Pas d'emojis dans code/docs/commits sauf demande explicite.
- Commits : sujet ≤ 50 char, body ≤ 72 char/ligne, pas d'attribution AI, pas de `--no-verify`, pas d'underscore dans le scope (hooks enforcent).
- `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` exclus par `.gitignore` racine.

## Agent Workflow

Explore localise → librarian lit (>500 lignes) → tu raisonnes → general-purpose implémente → validator vérifie. Lance les tâches indépendantes en parallèle.

## Guidance imbriquée

Chaque sous-projet majeur a son propre `CLAUDE.md`. Claude charge automatiquement le plus proche du fichier édité (« closest wins »). N'ajouter ici que ce qui s'applique à TOUS les sous-projets.
