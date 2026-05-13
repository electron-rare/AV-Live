# Multi-HMR + RealityKit — utilisation

## Setup une fois

```bash
# 1. Clone + checkpoint Multi-HMR (1.28 GB)
./data_only_viz/scripts/setup_multihmr.sh

# 2. SMPL-X NEUTRAL.npz — inscription manuelle MPII
#    https://smpl-x.is.tue.mpg.de/  → SMPL-X v1.1 (NPZ+PKL)
#    Extraire SMPLX_NEUTRAL.npz vers
#    ~/.cache/av-live-multihmr/models/smplx/SMPLX_NEUTRAL.npz

# 3. Python deps
cd data_only_viz && uv sync --extra multihmr

# 4. Extraire les faces SMPL-X pour Swift (250 896 octets)
.venv/bin/python scripts/dump_smplx_faces.py
```

## Lancement

### Via le launcher (auto)
1. Ouvrir AVLiveLauncher.app
2. Mode **data-only**, activer le switch *Multi-HMR (mesh SMPL-X dense)*
3. Demarrer : le launcher spawn sclang + viz Python + AV-Live-Body Swift

### Manuel (debug)
```bash
# Terminal 1 — RealityKit listener
cd launcher/AV-Live-Body
swift run -c release AVLiveBody

# Terminal 2 — worker Python
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -m data_only_viz.main \
    -v --pose --multi-hmr --fullscreen
```

## Architecture

```
webcam Mac (cv2 idx 0, 896x896)
    |
    v
Multi-HMR ViT-L (PyTorch MPS, ~317M params)
    |
    v
humans = [{v3d (10475,3), j3d, transl, shape, expression, ...}, ...]
    |
    v
OneEuroFilter (shape, expression) + IoU tracker
    |
    v
state.persons_smplx : list[SMPLXPerson]
    |
    v
SMPLXTCPSender : binaire ~126 KB / frame / personne sur :57130
    |
    v (TCP)
AVLiveBody Swift
  - OSCServer (Network.framework NWListener)
  - MeshRenderer (LowLevelMesh, vertex buffer in-place)
  - BodyView (ARView, perspective cam 2m back)
```

## Decisions cles vs. plan initial

- **NLF abandonne** : son detecteur YOLO TorchScript a CUDA hardcode
  (`aten::empty_strided` echoue sur CPU/MPS).
- **Multi-HMR `demo.py` bypasse** : depend de `multi_hmr_anny` (package
  prive `anny`) et `utils.render` (pyrender + OpenGL offscreen lourd).
  On stubbe ces modules dans `sys.modules` et on construit le `Model`
  directement depuis `model.py`.
- **`v3d` direct** : Multi-HMR renvoie deja les vertices SMPL-X
  decodes ; on n'utilise pas `SMPLXDecoder` dans le hot path (il
  reste utile pour les tests neutres).
- **macOS 15 requis** : `LowLevelMesh.parts.replaceAll` (API RealityKit
  release 2024-09) permet le vertex update in-place ; sur macOS 14 il
  faudrait rebuild la MeshResource a chaque frame (3-4x plus lent).

## FPS attendu

- Multi-HMR ViT-L MPS : ~150-200 ms / frame = 5-7 fps
- ViT-B (`multiHMR_672_B.pt`) : ~80 ms = 12 fps si on accepte moins
  de precision
- TCP sender throttle a 12 fps cible
- RealityKit render : 60 fps Cocoa, interpole entre frames Multi-HMR

## Assets caches

```
~/.cache/av-live-multihmr/
├── checkpoints/
│   └── multiHMR_896_L.pt              (1.28 GB)
├── models/
│   ├── smplx/
│   │   ├── SMPLX_NEUTRAL.npz          (108 MB)
│   │   ├── SMPLX_MALE.npz             (109 MB)
│   │   ├── SMPLX_FEMALE.npz           (109 MB)
│   │   ├── SMPLX_NEUTRAL.pkl          (520 MB)
│   │   └── smplx_uv_2023.npz          (UV mapping, 1 MB)
│   └── smpl_mean_params.npz           (1.3 KB)
└── multi-hmr/                          (repo clone)
    └── models -> ../models             (symlink relatif)
```

## Debug

| Symptome | Verification |
|----------|--------------|
| Pas de mesh visible | `ls ~/.cache/av-live-multihmr/checkpoints/multiHMR_896_L.pt` |
| `Multi-HMR load failed` | `~/.cache/av-live-multihmr/models/smplx/SMPLX_NEUTRAL.npz` present ? |
| `TCP refused on :57130` | Lancer l'app Swift AVANT le worker Python |
| FPS trop bas | Switcher vers ViT-B en editant `CKPT` dans `multi_hmr_worker.py` |
| MPS NotImplementedError | Variable env `PYTORCH_ENABLE_MPS_FALLBACK=1` |

## Pistes futures

- Texture webcam projetee sur le mesh via `smplx_uv_2023.npz` (62 724
  UV coords deja en cache).
- Switch dynamique L/B/S selon load CPU (autotuning).
- Compression vertices (delta-encoded float16) si la bande passante TCP
  devient un goulot.
