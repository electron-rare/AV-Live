# SMPLer-X + RealityKit — pivot pour mesh whole-body anime temps reel

## Pourquoi pivoter

État actuel :
- Apple Vision body pose : **OK** (13 joints ARKit, marche)
- Apple Vision face landmarks : **bloqué** (`PyObjCPointer` non castable ctypes en Python 3.14)
- Apple Vision hand pose : même blocage probable

Pour avoir un **mesh humain complet animé** (corps + visage + mains), la
direction recommandée 2025 est **SMPLer-X** (ECCV 2024) qui produit des
paramètres SMPL-X complets, décodables en mesh **10475 vertices** animé
en temps réel.

## SMPLer-X

Repo : <https://github.com/caizhongang/SMPLer-X>
Paper : [arXiv:2309.17448](https://arxiv.org/abs/2309.17448)

Output par personne (par frame) :
- 144 paramètres SMPL-X (β shape + θ pose + expression + jaw + eye)
- Décodable via `smplx` Python library en :
  - **10475 vertices** 3D
  - **127 joints** (corps + mains + visage)
  - **20908 triangles** (topologie standard SMPL-X)

Modèles :
- `SMPLer-X-S` : ViT-S, 64 ms M5
- `SMPLer-X-B` : ViT-B, 110 ms M5
- `SMPLer-X-L` : ViT-L, 220 ms M5

Cible temps réel : **S** ou **B**, 10-15 fps acceptables avec frame skip.

## RealityKit pour le rendu

RealityKit (Apple) est l'API moderne pour scènes 3D :
- Mesh skinning natif (animation de vertices par rig)
- Render Metal sous le capot, ANE pour Object Detection
- API Swift/Obj-C disponible via pyobjc-framework-RealityKit
- Affiche les meshes animés en temps réel, multi-personne

## Architecture proposée

```
data_only_viz/
├── apple_vision_pose.py     # actuel : body pose (~13 joints), gardé
├── smpler_x_worker.py       # NOUVEAU : SMPLer-X transformer → SMPL-X params
├── smplx_mesh.py            # NOUVEAU : décode params → vertices 3D
└── reality_kit_view.py      # NOUVEAU : affiche mesh dans RKView Swift bridge
```

State extension :

```python
@dataclass
class SMPLXPerson:
    pid: int
    vertices_3d: list[tuple[float, float, float]]  # 10475 verts (mètres)
    joints_3d: list[tuple[float, float, float]]     # 127 joints
    faces: list[tuple[int, int, int]]               # 20908 triangles (statique)
    cam_t: tuple[float, float, float]               # position cam → personne

persons_smplx: list[SMPLXPerson]
```

## Procédure d'installation

```bash
# 1. SMPLer-X
git clone https://github.com/caizhongang/SMPLer-X ~/.cache/av-live-smplerx
cd ~/.cache/av-live-smplerx
uv pip install --python /path/to/.venv/bin/python \
    torch torchvision smplx \
    mmcv-full mmdet mmpose mmtrack \
    "numpy<2"
# Note : mm* libraries peuvent etre compliquees sur ARM macOS

# 2. SMPL-X model (academic license required)
# Register at https://smpl-x.is.tue.mpg.de/
# Download SMPLX_NEUTRAL.npz, place in models/smplx/

# 3. SMPLer-X checkpoint
wget https://github.com/caizhongang/SMPLer-X/releases/download/v0.1.0/smpler_x_s32.pth.tar \
    -O checkpoints/smpler_x_s32.pth.tar

# 4. pyobjc-framework-RealityKit (peut etre absent du PyPI Python 3.14)
uv pip install pyobjc-framework-RealityKit  # ou via loadBundle
```

## Phases d'integration

1. **Phase 1** : SMPLer-X seul → mesh dans state, rendu Metal triangles
   plein (pas RealityKit) — 1-2 jours de travail
2. **Phase 2** : RealityKit Bridge → mesh skinné dans RKView superposé
   au MTKView — 3-4 jours, requires Swift bindings
3. **Phase 3** : streaming USDZ depuis Python → RealityKit consomme —
   1 jour, plus simple si Swift bindings difficiles

## Trade-offs vs Apple Vision actuel

| Critere | Apple Vision (actuel) | SMPLer-X + RealityKit |
|---|---|---|
| Latence M5 | 5 ms (ANE) | 65 ms (ViT-S MPS) |
| Body joints | 13 (ARKit) | 127 |
| Face mesh | 0 (bloqué) | OUI (10475 verts dont 4716 face) |
| Hands | 0 (bloqué) | OUI (15 joints × 2) |
| 3D monde | Non | OUI (position 3D + camera) |
| Multi-personne | OUI | OUI |
| Install complexity | 0 (system) | Elevee (SMPL-X + mmlib) |

## Recommandation

À court terme :
- **Garder Apple Vision body pose** (rapide, marche)
- **Ajouter SMPLer-X** en worker complémentaire, rendu mesh basse cadence
- **Skipper RealityKit** dans un premier temps : rendu Metal triangles
  remplis suffit pour démarrer

À moyen terme :
- Migration RealityKit si SMPLer-X marche bien et qu'on veut le mesh
  skinné avec éclairage 3D Apple natif

## Alternatives à considérer

- **PIXIE** (Yale 2021) : SMPL-X plus rapide mais moins précis
- **OSX** (CVPR 2023) : architecture transformer pour SMPL-X
- **Hand4Whole** (CVPR 2023) : SMPL-X focus mains/visage
