# WHAM / TRAM — pose 3D monde monoculaire

Statut : **scaffold de recherche**, non integre temps-reel. Modeles trop
lourds pour 30 fps sur M5 (50-200 ms par frame), utilisables a
**5-10 fps en mode complement** ou en post-traitement (offline).

## Comparatif

| Modele | Année | Body 3D | Trajectoire monde | Mains | Visage | Latence M5 |
|---|---|---|---|---|---|---|
| **WHAM** | 2024 (CVPR) | SMPL 24 joints + 6890 verts | Oui (slip-aware) | Non | Non | ~80 ms |
| **TRAM** | 2024 (ECCV) | SMPL 24 joints + 6890 verts | Oui (caméra + monde séparés) | Non | Non | ~150 ms |
| **Sapiens-3D** | 2024 (Meta, ECCV) | Très précis dense (308 verts gauche) | Non (frame-relative) | Partiel | Non | ~400 ms |
| **Apple Vision** (actuel) | system | 17 joints 2D + z relatif | Non | 21 kp/main | 76 kp visage | ~5 ms ANE |

WHAM est le sweet spot 2025 : SMPL complet + trajectoire monde + 12 fps M5.

## Repos officiels

- **WHAM** : <https://github.com/yohanshin/WHAM> (paper [arXiv:2312.07531](https://arxiv.org/abs/2312.07531))
- **TRAM** : <https://github.com/yufu-wang/tram> (paper [arXiv:2403.17346](https://arxiv.org/abs/2403.17346))
- **Sapiens** : <https://github.com/facebookresearch/sapiens>

## Procédure d'installation (WHAM)

```bash
# Clone + dependences lourdes (~3 GB)
git clone https://github.com/yohanshin/WHAM ~/.cache/av-live-wham/WHAM
cd ~/.cache/av-live-wham/WHAM
# requires PyTorch >= 1.13, torchvision, smplx, pytorch3d (pre-compile macOS arm)
uv pip install --python /path/to/.venv/bin/python \
    "torch>=2.4" "torchvision>=0.19" smplx detectron2-densepose \
    yacs joblib einops chumpy
# SMPL model (requires academic registration at https://smpl.is.tue.mpg.de/)
# place SMPL_NEUTRAL.pkl in dataset/body_models/smpl/

# Download WHAM checkpoint (155 MB)
wget https://github.com/yohanshin/WHAM/releases/download/v0.1.0/wham_vit_w_3dpw.pth.tar \
    -O checkpoints/wham_vit_w_3dpw.pth.tar
```

Sapiens : encore plus lourd (transformer, 5+ GB) — meme procédure mais
sur HuggingFace `facebook/sapiens-pose-3b`.

## Architecture d'intégration AV-Live

Ce qui devrait être implémenté pour WHAM :

```
data_only_viz/wham_worker.py    # Thread basse cadence (5 fps)
    ├── Lit state.persons_body (Apple Vision 17 kp 2D, source bbox)
    ├── Crop bbox, lance WHAM sur la sequence (memoire 30 frames)
    ├── Output : pour chaque personne SMPL 24 joints 3D + cam pose
    └── Ecrit state.persons_body_3d (nouveau champ), trajectory_world
```

State extension :

```python
@dataclass
class WhamBody:
    pid: int
    joints_3d: list[tuple[float, float, float]]   # 24 joints en metres
    world_t: tuple[float, float, float]            # position monde
    world_r: tuple[float, float, float, float]     # quaternion orientation
    cam_t: tuple[float, float, float]              # position camera (slam)

persons_body_3d: list[WhamBody]
```

Rendu Metal : 24 joints * 4 personnes = 96 sommets. Pipeline 3D
existant suffit (vertex layout xyz+conf+pid déjà en place). Reste à :
1. Projetter joints_3d en NDC via une vraie matrice de projection
2. Afficher les bones SMPL en 3D (epaisseur perspective)
3. Optionellement : silhouette SMPL ~6890 verts en mesh

## Pour aller plus loin (gros plan, doigts détaillés)

Actuellement le projet a :
- `fine_analysis.py` : crops Apple Vision pour visage/mains a haute resolution (4x zoom)
- Hand landmarks Apple Vision : 21 joints (standard MANO sans verts)

Pour des **doigts vraiment détaillés** (au-delà des 21 joints) :
- **MediaPipe Hand Landmarker** (HandLandmarkerWithBlendshapes ?) — pas dispo
- **HaMeR** (Hand Mesh Recovery, ICCV 2023) : 778 verts MANO par main, ~30 ms M5
  - <https://github.com/geopavlakos/hamer>
- **InterHand2.6M** dataset finetuned models

## Priorité recommandée

1. **Court terme** : `fine_analysis.py` (déjà fait) — gain visible immédiat sur visage/mains via Apple Vision crops
2. **Moyen terme** : **HaMeR** pour mesh main 778 verts (vrais doigts)
3. **Long terme** : **WHAM** pour 3D monde (utile en performance scénique multi-cam)

Sapiens-3D : déconseillé sur M5 sans GPU dédié (trop lent en temps réel).
