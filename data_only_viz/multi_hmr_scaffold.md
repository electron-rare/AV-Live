# Multi-HMR + RealityKit — pipeline temps réel multi-personne

> **IMPLÉMENTÉ 2026-05-13** — voir `MULTIHMR_README.md` pour l'utilisation.
> Le pipeline complet (Multi-HMR worker + SMPL-X decoder + TCP sender +
> Swift RealityKit app) est en place. Ce document garde l'analyse initiale.

**Pipeline cible** (post-Apple Vision, post-SMPLer-X) :

```
AVFoundation (AVAssetReader / AVCaptureSession)
    ↓ CVPixelBuffer (zéro copie, hardware decode)
Multi-HMR CoreML (Naver 2024) :
    forward pass unique → SMPL-X (β, θ, expr) × N personnes + position 3D
    ↓
OneEuroFilter sur β/θ/expr (lissage non-négociable)
    ↓
smplx.SMPLXLayer(β, θ, expr) → vertices 10475 × N
    ↓
RealityKit : USDZ mesh skinné, push vertices/frame, render natif
```

## Multi-HMR (CVPR 2024, Naver)

- Repo : <https://github.com/naver/multi-hmr>
- Paper : [arXiv:2402.14654](https://arxiv.org/abs/2402.14654)
- Output : SMPL-X complet (corps + mains + visage) + position 3D monde
- **Multi-personne natif** : pas besoin de détecteur séparé, le modèle
  fait detection + pose en un seul forward
- Backbone : DINOv2 ViT-B (~80M params)
- Latence cible : 50 ms GPU NVIDIA. Sur M5 ANE ~80-120 ms (15-12 fps)

Variantes :
- `multi-hmr-base` : ViT-B, 88 MB
- `multi-hmr-large` : ViT-L, 304 MB

## Procédure d'installation Multi-HMR

```bash
# 1. Clone
git clone https://github.com/naver/multi-hmr ~/.cache/av-live-multihmr
cd ~/.cache/av-live-multihmr

# 2. Dépendances Python
uv pip install --python /path/to/.venv/bin/python \
    torch torchvision \
    smplx einops fairscale \
    iopath opencv-python \
    "numpy<2"

# 3. SMPL-X model (academic license)
# Register at https://smpl-x.is.tue.mpg.de/
# Download SMPLX_NEUTRAL.npz → models/smplx/

# 4. Checkpoint Multi-HMR
wget https://download.europe.naverlabs.com/ComputerVision/multiHMR/multiHMR_896_L_synth_real_occ.pt \
    -O checkpoints/multiHMR_896_L_synth_real_occ.pt

# 5. CoreML conversion (one-shot)
python convert_to_coreml.py \
    --checkpoint checkpoints/multiHMR_896_L_synth_real_occ.pt \
    --output ~/.cache/av-live-coreml/multi_hmr.mlpackage
```

**Note critique** : la conversion CoreML est probablement bloquée par
le même bug `BlobWriter not loaded` sur macOS-arm64 Python 3.14 (cf
notre tentative YOLO11n-pose). Solutions :

1. **Faire la conversion sur une machine Linux ou macOS Python 3.12 isolé**
   → copier le `.mlpackage` ensuite dans `~/.cache/av-live-coreml/`
2. **Skip CoreML** : utiliser PyTorch MPS direct (un peu plus lent que
   ANE mais évite le pain de conversion)

## Worker à créer

`data_only_viz/multi_hmr_worker.py` (~250 lignes) :

```python
import threading, time, logging
from pathlib import Path
import torch
from .euro_filter import OneEuroFilter, SkeletonFilter
from .state import State

LOG = logging.getLogger("multi_hmr")

class MultiHMRWorker:
    def __init__(self, state: State, ckpt_path: Path, smpl_path: Path,
                 num_persons: int = 4, target_fps: float = 15.0,
                 device: str = "mps"):
        ...
        # OneEuroFilters par parameter SMPL-X (beta:10, theta:165, expr:10)
        self._smooth_beta = [OneEuroFilter(0.8, 0.05) for _ in range(10)]
        self._smooth_theta = [OneEuroFilter(1.2, 0.10) for _ in range(165)]
        self._smooth_expr = [OneEuroFilter(1.0, 0.08) for _ in range(10)]

    @staticmethod
    def is_available() -> bool:
        try:
            import smplx, torch
            return Path("~/.cache/av-live-multihmr/checkpoints/...").expanduser().exists()
        except ImportError:
            return False

    def start(self): ...
    def stop(self): ...

    def _run(self):
        # 1. Load Multi-HMR model
        from multi_hmr.models import get_model  # sys.path local
        model = get_model(self._ckpt_path).to(self._device).eval()

        # 2. Load SMPL-X body model
        from smplx import SMPLXLayer
        smplx_layer = SMPLXLayer(self._smpl_path, gender='neutral').to(self._device)

        # 3. Capture loop
        import cv2
        cap = cv2.VideoCapture(0)
        while not self._stop.is_set():
            ok, frame = cap.read()
            if not ok: continue

            # 4. Multi-HMR forward (1 pass = N personnes)
            with torch.no_grad():
                tensor = preprocess(frame).to(self._device)
                outputs = model(tensor)
                # outputs.smplx_params : [N, 185] (betas + thetas + expr)
                # outputs.translation  : [N, 3]   (position 3D monde)

            # 5. Lissage One Euro
            t = time.monotonic()
            smoothed = []
            for i, params in enumerate(outputs.smplx_params):
                smoothed.append(self._smooth_person(i, params, t))

            # 6. Décodage SMPL-X → vertices
            persons = []
            for i, params in enumerate(smoothed):
                betas, thetas, exprs = split_params(params)
                out = smplx_layer(betas=betas, body_pose=thetas[:66],
                                   left_hand_pose=thetas[66:111],
                                   right_hand_pose=thetas[111:156],
                                   jaw_pose=thetas[156:159],
                                   expression=exprs, ...)
                verts = out.vertices.cpu().numpy()  # (10475, 3)
                joints = out.joints.cpu().numpy()   # (127, 3)
                persons.append({
                    "vertices_3d": verts,
                    "joints_3d": joints,
                    "translation": outputs.translation[i].cpu().numpy(),
                    "pid": self._tracker_update(...)
                })

            # 7. Écrit dans State
            with self.state.lock():
                self.state.persons_smplx = persons
                self.state.persons_smplx_t = time.monotonic()
```

## State extension

```python
@dataclass
class SMPLXPerson:
    pid: int
    vertices_3d: list[tuple[float, float, float]]  # 10475 verts
    joints_3d: list[tuple[float, float, float]]     # 127 joints
    translation: tuple[float, float, float]          # 3D monde
    rotation: tuple[float, float, float, float]      # quaternion

persons_smplx: list[SMPLXPerson] = field(default_factory=list)
smplx_faces: list[tuple[int, int, int]] = field(default_factory=list)  # 20908 statique
```

## RealityKit bridge

**Option A : RKView via pyobjc** (complexe)

```python
from RealityKit import ARView, Entity, ModelComponent, MeshResource
# Charge USDZ template
template = Entity.loadModelAsync("smplx_template.usdz")
# Per frame: update vertex buffer
for person in state.persons_smplx:
    entity.components[ModelComponent].mesh = MeshResource.generate(
        from_descriptors=[
            MeshDescriptor(
                positions=person.vertices_3d,
                indices=state.smplx_faces.flatten(),
            )
        ]
    )
```

**Option B : application Swift native** (réaliste)

Création d'une app **AV-Live-Body** séparée en Swift :
1. SwiftUI window avec ARView
2. Reçoit les vertices via OSC depuis le worker Python Multi-HMR
3. Render RealityKit natif sans bridge pyobjc

Format OSC :
```
/smplx/person <pid> <tx> <ty> <tz>
/smplx/verts <pid> <10475 × 3 floats binaires>
```

UDP packet trop gros (~125KB) → utiliser TCP ou shared memory.

## Recommandation pragmatique

**Court terme (cette session)** :
- Garder Apple Vision body pose (marche, simple)
- Body mesh : 8 triangles (tronc + bras + jambes) — déjà en place
- Accepter que face/hands mesh est bloqué par pyobjc PyObjCPointer

**Moyen terme (1 semaine de travail)** :
- Installer Multi-HMR sur un Python 3.12 séparé (éviter coremltools issues)
- Worker dédié qui tourne 8-12 fps
- Rendu mesh dans Metal pipeline existant (triangles remplis)

**Long terme (2+ semaines)** :
- App Swift native avec RealityKit pour rendu mesh skinné
- Python worker envoie params SMPL-X via OSC TCP
- L'app Swift décode SMPL-X et rend

## Décision

Cette session : **rester sur Apple Vision body actuel** qui fonctionne.
Tout le reste (Multi-HMR / RealityKit / SMPL-X) demande un setup
substantiel hors scope d'une session live.
