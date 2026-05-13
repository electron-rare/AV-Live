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

## Tests

```bash
uv run pytest tests/ -v
```

Tests TDD-first pour `nlf_worker.py` ; valider avant chaque commit qui touche un worker.

## Anti-patterns

- Ne pas charger un modèle ML sans guard `try/except ImportError` — les optional-extras peuvent manquer.
- Ne pas committer `*.pt`, `*.ckpt`, `*.safetensors`, `*.mlpackage` (gitignore racine).
- Ne pas appeler `state.persons_nlf = ...` hors `with state.lock():`.
- Ne pas hardcoder le device (`cuda`/`mps`/`cpu`) : détecter via `torch.backends.mps.is_available()` puis fallback.
- Pas de `print` dans la boucle de rendu — utiliser un logger conditionnel.
