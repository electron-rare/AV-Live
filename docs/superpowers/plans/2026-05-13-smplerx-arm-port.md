# SMPLer-X-S inference port pour ARM Mac (Python 3.14, MPS)

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` ou `superpowers:subagent-driven-development`.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** rendre SMPLer-X-S exploitable en inférence depuis le
worker AV-Live `data_only_viz` sur M5 macOS 15 Python 3.14, sans
installer `mmdet`/`mmpose`/`mmcv-full` (ARM macOS Python 3.14 ne les
build pas). Cible perf : claim auteurs **64 ms M5 MPS** → 15 fps natif.

**Non-goals:**
- Training / fine-tuning (uniquement inference).
- Multi-batch (B=1 fixe).
- Convertir vers CoreML (autre plan).
- Toucher au pipeline Multi-HMR existant (les deux coexistent, choisis
  via CLI `--worker`).

**Contraintes héritées:**
- License S-Lab 1.0 (non-commercial seulement) ; fork à
  `electron-rain/SMPLer-X` déjà créé et lié comme submodule
  `third_party/SMPLer-X`.
- Budget RAM M5 : < 4 GB pour le worker (laisse 4 GB pour OS + Swift
  app + camera).
- Pas de Studio offload (contrainte on-device).

## Architecture cible

```
camera (cv2 BGR)
    |
    v
YOLOv8n-pose (Ultralytics MPS) -> bbox personnes + score
    |
    v (pour chaque bbox)
crop + resize 384x512 (input_img_shape SMPLer-X-S)
    |
    v
SMPLer-X-S transformer (ViT-S + Position/Rotation/Box/Hand/Face nets)
    |
    v
SMPL-X params (β shape, θ pose, expression, jaw, eye)
    |
    v
smplx.SMPLX decoder -> 10475 vertices + 127 joints
    |
    v
dédup IoU/pelvis (reuse from multi_hmr_worker)
tracker IoU velocity (reuse)
SMPLXTCPSender :57130 (inchangé) -> AVLiveBody Swift
```

**Différence clé vs Multi-HMR** : SMPLer-X est *top-down* (détecteur
externe + crop par personne), Multi-HMR est *single-shot*. Trade-off :
plus de latence détecteur (~20-30 ms YOLO M5) mais SMPL-X transformer
plus rapide par crop. Net escompté : 30 ms YOLO + 64 ms SMPLer-X-S ≈
**~100 ms total = 10 fps** (vs 228 ms Multi-HMR = 4.4 fps).

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `mmcv-lite` ne fournit pas `Config.fromfile()` (parse .py config) | medium | medium | Step 1 vérifie ; fallback : parse YAML/JSON ou exec() le .py |
| Weights state_dict keys diffèrent de la build vendored | low | high | repo vendorise sa mmpose donc keys devraient matcher ; vérifier Step 4 |
| `chumpy` requis par SMPL-X 0.1.28 | medium | low | smplx 0.1.28 demande chumpy pour `.pkl` ; on charge `.npz` qui bypasse |
| `pyrender` ou OpenGL offscreen requis | low | medium | inference n'a pas besoin de rendu ; stubber si import au load |
| YOLO bbox moins précis que mmdet upstream | low | low | acceptable pour AV-Live (live perf, pas mocap) |
| `torchgeometry` deprecated/breaks Python 3.14 | medium | medium | already in extras pour Multi-HMR ; éviter sinon |
| SMPL-X 0.1.28 incompat numpy>=2 | high | medium | extras pin `numpy<2` (déjà fait pour multihmr) |
| Mauvaise inférence due à preprocessing différent (mean/std/crop algo) | medium | high | reproduire exactement `transforms.py` du repo ; Step 4 valide |
| Le claim 64 ms est mesuré sur quelle MPS PyTorch version ? | medium | medium | Step 5 bench réel ; si > 100 ms, recheck si claim hors-detecteur |

## T1 Execution result (2026-05-13) — UPDATE after user "fais le"

Première lecture : 86 imports `from mmcv*`, 20+ symboles. Tentative
de shim approfondie post-"fais le" :

| Shim niveau | Status | Trouvé manquant ensuite |
|---|---|---|
| `mmcv.Config` ← mmengine | ✅ shim OK | deprecated_api_warning |
| `mmcv.deprecated_api_warning` no-op | ✅ shim OK | mmcv.cnn.constant_init etc |
| `mmcv.cnn.{init_funcs, Linear, Conv2d, MODELS, build_model_from_cfg}` | ✅ shim OK | mmcv.cnn.bricks.registry |
| `mmcv.cnn.bricks.registry` (12 sub-reg) | ✅ shim OK | **mmcv.runner** |
| `mmcv.runner` (50+ classes : BaseModule, hooks, ...) | ❌ STOP | (cascade continue) |

`mmcv.runner` était un module entier ; mmcv 2.x l'a migré dans
`mmengine.runner` avec une API différente. Le shim demanderait de
recréer 50+ classes ou rediriger l'import via `sys.modules`. Ça
exposerait la couche suivante (probablement `mmcv.parallel`, puis
`mmcv.utils`, puis encore plus profond).

**Reality check** : on est en train de refaire la migration mmcv
1.x → 2.x complète à la main. C'est ~1-2 semaines de travail
engineering proprement budgétisé, pas "5-6 h".

**Abandon final T1**. Le shim partiel
`data_only_viz/_smplerx_shims.py` reste committé comme socle
si reprise future.

## Original T1 Gate Fail summary

 Comptage des `from mmcv*` imports uniques dans
`third_party/SMPLer-X/main/transformer_utils/mmpose/` = **86
distincts**, avec **20+ symboles** spécifiques à shim (Config, Timer,
deprecated_api_warning, is_seq_of, 17 symboles de mmcv.cnn :
constant_init, normal_init, kaiming_init, build_norm_layer, ConvModule,
DepthwiseSeparableConvModule, etc).

Le SMPLer-X vendored mmpose est écrit pour **mmcv-full 1.x** ;
mmcv-lite 2.x a migré presque toute l'API vers `mmengine` (constant_init
etc. sont dans `mmengine.model`). Shims partiels validés :
- `mmcv.Config = mmengine.config.Config` ✅ fonctionne
- `mmcv.deprecated_api_warning = no_op` ✅ fonctionne
- Mais 18+ autres symboles à shim avant `from mmpose.models import
  build_posenet` aboutisse, et c'est sans compter les patches que la
  vendored mmpose elle-même fait sur d'autres signatures internes.

**Abandon criterion** du plan : « si 3+ patches mmpose nécessaires →
abandon, escalade vers chirurgie backbone custom timm (multi-jour) ».
Déclenchée : 20+ patches > 3.

**Vraie estimation révisée** : 2-4 jours focused work pour porter
proprement (soit en shim massif au load, soit en éditant la vendored
mmpose dans le fork pour utiliser mmengine 2.x).

## Recommandation post-T1

1. **Garder Multi-HMR ViT-S actuel** : 3.4 fps natif + motion gate
   (~95% économie compute scène statique) + interp 30 fps + tracker
   velocity + dédup 2D+3D. État acceptable produit-ready pour usage
   non-commercial AV-Live.
2. **Si plus de speedup nécessaire** : reprendre le plan CoreML/ANE
   surgery (probe v2 a localisé un blocker mais c'est borné, ~2-3 j).
3. **Si SMPLer-X reste absolument l'objectif** : prévoir 3-4 jours
   dédiés et soit (a) refactor la vendored mmpose vers mmengine 2.x,
   soit (b) extraire et ré-implémenter le backbone ViT + 6 heads
   (PositionNet/RotationNet/BoxNet/HandRoI/HandRotation/FaceRegressor)
   en pur PyTorch.

Le fork `electron-rare/SMPLer-X` + submodule `third_party/SMPLer-X`
restent en place dans le repo. Reprise facile quand le temps sera
budgété.

## Tasks (planifié — non exécuté après gate fail T1)

### Task 1 — Verify dependency story (½ h)

Avant d'écrire 200+ lignes de worker code, valider les hypothèses sur
les dépendances.

- [ ] **Step 1.1: install extra smplerx**

  ```bash
  cd /Users/electron/Documents/Projets/AV-Live
  uv sync --project data_only_viz --extra smplerx
  ```

  Si échec sur mmcv-lite/torchvision/etc — escalade.

- [ ] **Step 1.2: check `mmcv.Config.fromfile` fonctionne sur la
  config python SMPLer-X-S**

  ```python
  import sys
  sys.path.insert(0, "third_party/SMPLer-X/main")
  from mmcv import Config
  cfg = Config.fromfile(
      "third_party/SMPLer-X/main/transformer_utils/configs/"
      "smpler_x/encoder/body_encoder_small.py")
  print(cfg.model.backbone)  # doit afficher type='ViT' etc
  ```

  Si mmcv-lite n'a pas `Config.fromfile` qui supporte les `_base_` :
  écrire un substitut maison (exec le .py + suit `_base_` manuellement).

- [ ] **Step 1.3: check vendored mmpose import**

  ```python
  sys.path.insert(0, "third_party/SMPLer-X/main/transformer_utils")
  from mmpose.models import build_posenet
  print(build_posenet)
  ```

  Le module vendored devrait s'auto-resoudre. Si erreur import sur
  un sous-module (e.g., `mmpose/datasets/...`) qui n'est pas nécessaire
  à l'inférence : stubber via `sys.modules`.

- [ ] **Step 1.4: Gate**

  Si Step 1.1-1.3 passent : **GATE PASS**, continuer Task 2. Sinon,
  documenter le blocker dans ce plan et décider entre :
  - patch mmcv-lite avec un wrapper
  - extraire le `build_posenet` minimal (juste construit le ViT) et
    bypasser mmpose complètement

### Task 2 — Load model + weights from checkpoint (1 h)

- [ ] **Step 2.1: run setup script**

  ```bash
  bash data_only_viz/scripts/setup_smpler_x.sh
  ```

  Doit télécharger `smpler_x_s32.pth.tar` (~150 MB) dans
  `~/.cache/av-live-smplerx/checkpoints/` et symlink SMPLX_NEUTRAL
  depuis Multi-HMR cache. Vérifier files exist.

- [ ] **Step 2.2: write `_smplerx_loader.py` (module isolé)**

  Module qui :
  1. inject sys.path : `third_party/SMPLer-X/main` et
     `third_party/SMPLer-X/main/transformer_utils`.
  2. stubber tout module manquant (pyrender, mmdet, etc) via
     `sys.modules[name] = types.ModuleType(name)`.
  3. patcher `mmcv.Config.fromfile` si Step 1.2 a échoué.
  4. patcher `cfg` global SMPLer-X (`config_smpler_x_s10.py`) pour
     pointer vers nos chemins (CACHE) plutôt que les chemins absolus.
  5. importer `from SMPLer_X import get_model`.
  6. `model = get_model('test')` puis charger
     `smpler_x_s32.pth.tar` dans le state_dict.
  7. Retourner le model.

- [ ] **Step 2.3: smoke test load**

  ```python
  from data_only_viz._smplerx_loader import load_smplerx_s
  m = load_smplerx_s(device="mps")
  print(type(m), sum(p.numel() for p in m.parameters())/1e6, "M params")
  ```

  Attendre : ~30M params, no exception.

- [ ] **Step 2.4: smoke test forward**

  Dummy input `(1, 3, 512, 384)` (input_img_shape de S-10).

  ```python
  import torch
  x = torch.rand(1, 3, 512, 384).to("mps")
  with torch.no_grad():
      out = m(x)
  print({k: v.shape for k, v in out.items()})
  ```

  Attendre : un dict avec keys typées (joints, params, etc) sans
  exception MPS. Documenter les keys exactes pour Task 3.

- [ ] **Step 2.5: Gate**

  Forward réussi = GATE PASS. Si échec : analyser stack trace et
  patcher au cas par cas (souvent une op qui demande
  `aten::empty_strided` ou autre MPS-incompatible — fallback
  CPU pour ce sub-op).

### Task 3 — Detector replacement: mmdet → YOLO (½ h)

- [ ] **Step 3.1: write `_smplerx_detector.py`**

  Wrapper Ultralytics YOLO-pose qui retourne des bboxes au même
  format que `process_mmdet_results` du repo upstream
  (`list[np.ndarray (N, 5)]` = (x1, y1, x2, y2, score) par classe).

  ```python
  from ultralytics import YOLO
  
  class YOLOPersonDetector:
      def __init__(self, device="mps"):
          self.model = YOLO("yolov8n.pt").to(device)
      
      def detect(self, frame_bgr, conf=0.3):
          res = self.model(frame_bgr, classes=[0], conf=conf,
                           verbose=False)
          boxes = res[0].boxes
          if boxes is None or len(boxes) == 0:
              return np.zeros((0, 5))
          return np.concatenate([
              boxes.xyxy.cpu().numpy(),
              boxes.conf.cpu().numpy().reshape(-1, 1),
          ], axis=1)
  ```

- [ ] **Step 3.2: smoke test 1 frame**

  ```python
  import cv2
  frame = cv2.imread("/tmp/test_person.jpg")
  det = YOLOPersonDetector()
  bboxes = det.detect(frame)
  print(bboxes.shape, bboxes)
  ```

### Task 4 — Inference pipeline + state population (2-3 h)

- [ ] **Step 4.1: write `smpler_x_worker.py`**

  Squelette miroir de `multi_hmr_worker.py` :
  - `class SMPLerXWorker` avec `start/stop`
  - `_run` : capture caméra (AVCapture) → YOLO → crop per person →
    SMPLer-X forward → decode SMPL-X params → `v3d` shape (10475, 3)
  - reuse `IoUTracker`, dédup IoU/pelvis (factoriser dans un module
    commun `_pose_dedup.py` à terme).
  - SMPLXPerson populé dans `state.persons_smplx`
  - heartbeat log fps + persons/frame

- [ ] **Step 4.2: vérification visuelle**

  Lancer worker debug, comparer bbox YOLO + mesh result au visuel
  caméra. Skip si pas de personne dans la frame.

- [ ] **Step 4.3: Validation numérique (offline)**

  Sur 1 frame statique enregistrée :
  - Run SMPLer-X-S → save `v3d` shape (10475, 3)
  - Run Multi-HMR ViT-S → save `v3d`
  - Plot superposés ou compute distance moyenne pelvis-aligned.
    Différence attendue : 1-5 cm (modèles distincts) mais corps
    plausible dans les deux cas.

### Task 5 — Bench M5 (½ h)

- [ ] **Step 5.1: bench headless dummy**

  20 iter forward sur dummy (1, 3, 512, 384) MPS warm.
  **Gate** : médian ≤ 100 ms (10 fps) sinon claim auteurs caduc.

- [ ] **Step 5.2: bench camera live**

  Run worker 30 s avec 1 puis 3 personnes. Mesurer :
  - fps end-to-end (heartbeat)
  - persons/frame moyenne avec 3 sujets
  - pids distincts (objectif ≤ 5 pour 3 personnes, comme Multi-HMR)
  - RAM peak via `psutil.Process().memory_info().rss`

  **Gate** : ≥ 8 fps soutenu sur 30 s ET RAM ≤ 4 GB.

### Task 6 — Intégration main.py + CLI (½ h)

- [ ] **Step 6.1: add CLI flags**

  ```bash
  uv run -m data_only_viz.main --smplerx
  uv run -m data_only_viz.main --smplerx --det-thresh 0.2
  ```

  `--smplerx` mutuellement exclusif avec `--multi-hmr`.

- [ ] **Step 6.2: main.py worker spawn**

  Si `--smplerx` : import `SMPLerXWorker`, vérifier
  `is_available()`, start. Mêmes patterns que multi-hmr.

- [ ] **Step 6.3: README update**

  Section "SMPLer-X" dans `data_only_viz/MULTIHMR_README.md` (ou
  séparer en `BACKENDS_README.md`).

### Task 7 — Commit + push (10 min)

- [ ] **Step 7.1: commit en plusieurs étapes**

  Suggéré :
  - commit 1 : loader + detector (Tasks 2-3)
  - commit 2 : worker + pipeline (Task 4)
  - commit 3 : bench + intégration (Tasks 5-6)

  Pour pouvoir rollback par étage.

## Success criteria

| Métrique | Cible | Stretch |
|---|---|---|
| Forward médian M5 MPS | ≤ 100 ms | ≤ 64 ms (claim auteurs) |
| End-to-end fps avec 3 personnes | ≥ 8 fps | ≥ 12 fps |
| Pids distincts en 30 s (3 sujets) | ≤ 5 | ≤ 4 |
| RAM peak worker | ≤ 4 GB | ≤ 2.5 GB |
| Mesh plausible vs Multi-HMR (frame statique) | distance < 10 cm | < 5 cm |

## Abandon criteria

- Task 1 : si mm-deps trop profondes (3+ patches mmpose nécessaires) →
  abandon, escalade vers chirurgie backbone custom timm (multi-jour).
- Task 2 : weights load avec >50% des keys missing/unexpected → abandon,
  re-examiner le fork.
- Task 5.1 : médian forward > 150 ms M5 → claim auteurs invalide ici,
  envisager d'autres pistes (motion gate stack avec ce qu'on a).

## Fallback paths

Si abandon en cours :
1. **Rester sur Multi-HMR ViT-S + optimisations actuelles** (motion gate,
   interp 30 fps, tracker velocity). État actuel = 3.4 fps + 95%
   compute économisé sur scène statique = visuel acceptable.
2. **Reprendre CoreML plan** (autre rabbit hole connu, plan déjà
   écrit).
3. **Stocker l'effort comme leçon** : "SMPLer-X port too deep for
   1 day under non-commercial constraint".

## Estimated total

| Task | Estimate |
|---|---|
| T1 — Dep verification | 30 min |
| T2 — Loader + smoke test | 1 h |
| T3 — Detector YOLO | 30 min |
| T4 — Worker pipeline | 2-3 h |
| T5 — Bench | 30 min |
| T6 — Integration | 30 min |
| T7 — Commits | 10 min |
| **Total wallclock** | **~5-6 h focused work** |

Si tout va bien : 1 session de travail. Si T2 ou T4 bloque : multi-jour.
