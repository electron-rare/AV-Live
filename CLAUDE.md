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
| `MEDIAPIPE_DELEGATE` | `cpu` | `gpu` Metal SRGBA (faster, flake on M5) |
| `POSE_FILTER` | `median+kalman+lookahead+ik` | filter chain stages |
| `MULTIHMR_REID` | `dino` | DINO cosine matching, `iou` fallback |

## Conventions globales

- Python : **uv** systématiquement (jamais pip/poetry/conda directs).
- Pas d'emojis dans code/docs/commits sauf demande explicite.
- Commits : sujet ≤ 50 char, body ≤ 72 char/ligne, pas d'attribution AI, pas de `--no-verify`, pas d'underscore dans le scope (hooks enforcent).
- `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` exclus par `.gitignore` racine.

## Agent Workflow

Explore localise → librarian lit (>500 lignes) → tu raisonnes → general-purpose implémente → validator vérifie. Lance les tâches indépendantes en parallèle.

## Guidance imbriquée

Chaque sous-projet majeur a son propre `CLAUDE.md`. Claude charge automatiquement le plus proche du fichier édité (« closest wins »). N'ajouter ici que ce qui s'applique à TOUS les sous-projets.
