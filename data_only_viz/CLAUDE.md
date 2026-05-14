# data_only_viz

Visualiseur natif Metal (pyobjc) pour le mode data-only d'AV-Live : capture caméra → détection pose multi-personne → tracker → rendu Metal → OSC out vers `oscope-of`.

## Environnement

```bash
cd data_only_viz
uv sync                                    # base
uv sync --extra pose                       # MediaPipe + YOLO + Ultralytics
uv sync --extra nlf                        # Neural Localizer Fields (SMPL body mesh)
uv sync --extra detrpose                   # DETRPose transformer (clone manuel — voir detrpose.py)
uv run python -m data_only_viz.main        # lancement standard
```

Python **3.11+** requis. `pyproject.toml` est la source de vérité — ne jamais éditer `uv.lock` à la main.

## Backends pose disponibles

| Backend | Fichier | Statut |
|---------|---------|--------|
| MediaPipe Holistic | `holistic.py` | stable |
| MediaPipe multi (Pose+Face+Hand) | `multi.py` | stable ; `MEDIAPIPE_DELEGATE=gpu` (défaut) ou `cpu`. **GPU Metal exige SRGBA 4-ch** (3-ch SRGB crashe `gpu_buffer_storage_cv_pixel_buffer.cc`) — multi.py route auto vers `cv2.COLOR_BGR2RGBA` + `mp.ImageFormat.SRGBA` quand delegate=GPU. Bench M5 image-mode SRGBA : pose 2.9 vs 6.7 ms (GPU/CPU), face 1.0 vs 4.1, hand 3.2 vs 6.1 |
| Ultralytics YOLOv8-pose | `pose.py` | stable, modèle `yolov8n-pose.pt` à la racine repo |
| Apple Vision (Core ML) | `apple_vision_pose.py`, `coreml_pose.py` | macOS uniquement |
| DETRPose | `detrpose.py` | clone manuel + checkpoint, voir docstring |
| NLF (SMPL body mesh) | `nlf_worker.py` | TorchScript, **bloqué CPU/MPS** (NotImplementedError 2026-05-13), CUDA-only ; checkpoints via `scripts/setup_nlf.sh` |
| Multi-HMR | `multi_hmr_scaffold.md` | scaffold seulement |
| SMPLER-X / WHAM-TRAM | `*_scaffold.md` | scaffold seulement |

## Conventions

- État partagé multi-thread : `state.py` expose `State.lock()` — toujours mutationner sous lock.
- Filtrage temporel : `euro_filter.py` (One Euro Filter) sur les keypoints avant tracker.
- Association multi-personne : `tracker.py` IoU-based, `scipy.optimize.linear_sum_assignment`.
- Shaders Metal dans `shaders/` (`.metal`), recompilés au runtime ; topologie mesh (SMPL faces) en binaire dans `mesh_topology.py`.
- OSC out : `osc_listener.py` / `pose_bridge.py` — destination `oscope-of` sur `:57123`.

## action-head (classifier action debout/assise/danse)

Tête de classification d'action streaming au-dessus des j3d SMPL-X (ou body3d MediaPipe en fallback). Implémentée 2026-05-13.

| Fichier | Rôle |
|---|---|
| `action_head.py` | `ActionHeadModel` (GRU 1L + MLP, 37 811 params, <2 ms/step M5), `ActionHead.step(pid, j3d) → (label, probs, kin)`, `PerPersonBuffer`, `FeatureExtractor` (201-D : j3d + vel + accel + scalaires) |
| `action_head_pub.py` | Publisher thread démarré dans `multi.py` `__init__`. Polle `state.persons_smplx` (préféré) ou `state.persons_body3d` (fallback) à 30 Hz, dédup par timestamp, extrait j3d22 via `SMPLX_JOINT_ANCHOR_VERTS` ou `MEDIAPIPE_TO_22`, émet OSC `/pose/action` + `/pose/kin` + `/pose/enter/leave` |
| `training/{dataset,autolabel,augment,train_action_head,eval,review}.py` | Pipeline complet : jsonl IO + sliding windows + by-session split / règles auto-label + glue CLI / 4 augmentations / training MPS AdamW CE-weighted / confusion matrix + latence micro-bench / TUI textuel pour review manuel |
| `scripts/capture_actions.py` | Webcam → MP4 + timestamps |
| `scripts/extract_j3d_offline.py` | MP4 → jsonl j3d22 via `MultiHMRCoreMLBackend.infer()` directement (pas de refactor worker) |
| `scripts/train_on_studio.sh` | rsync grosmac → bastion electron-server → studio M3 Ultra + uv sync `--extra multihmr` + train MPS + ckpt back |

Pipeline complet de capture à live :
```bash
uv run python -m data_only_viz.scripts.capture_actions --session sess01 --duration 600
uv run python -m data_only_viz.scripts.extract_j3d_offline --session sess01 --video ~/.cache/av-live-action/raw/sess01.mp4
uv run python -m data_only_viz.training.autolabel --frames ~/.cache/av-live-action/raw/sess01.jsonl --out ~/.cache/av-live-action/dataset/auto.jsonl
uv run python -m data_only_viz.training.review --in ~/.cache/av-live-action/dataset/auto.jsonl --out ~/.cache/av-live-action/dataset/dataset.jsonl
./data_only_viz/scripts/train_on_studio.sh --epochs 50
uv run python -m data_only_viz.training.eval --ckpt ~/.cache/av-live-action/checkpoints/action_head.pt --dataset ~/.cache/av-live-action/dataset/dataset.jsonl
# Live : publisher déjà câblé dans multi.py, aucune action requise
```

Checkpoint par défaut : `~/.cache/av-live-action/checkpoints/action_head.pt`. Absent → random init (warmup retourne `debout`).

## Tests

```bash
uv run pytest tests/ -v
```

Tests TDD-first pour `nlf_worker.py` ; valider avant chaque commit qui touche un worker.

Suite action-head (8 fichiers, 39 tests) : `tests/test_action_head_*.py`, `tests/test_{dataset,autolabel,augment,training_smoke,pose_bridge_action}.py`. Tous doivent rester verts avant chaque commit qui touche `action_head*.py` ou `training/*.py`.

## Anti-patterns

- Ne pas charger un modèle ML sans guard `try/except ImportError` — les optional-extras peuvent manquer.
- Ne pas committer `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` (gitignore racine).
- Ne pas appeler `state.persons_nlf = ...` hors `with state.lock():`.
- Ne pas hardcoder le device (`cuda`/`mps`/`cpu`) : détecter via `torch.backends.mps.is_available()` puis fallback.
- Pas de `print` dans la boucle de rendu — utiliser un logger conditionnel.
