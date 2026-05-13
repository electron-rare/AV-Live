# Multi-HMR + RealityKit Body Mesh Implementation Plan

> **IMPLEMENTE 2026-05-13** — Tasks 1-15 livrees. Voir
> `data_only_viz/MULTIHMR_README.md` pour l'utilisation.
>
> Note historique : ce plan a d'abord ete obsolete au profit du plan NLF
> (voir `2026-05-13-nlf-realitykit-body-mesh.md`), puis re-active apres
> decouverte que le checkpoint TorchScript NLF a le device CUDA hardcode
> dans son detecteur YOLO interne (incompatible Mac CPU/MPS).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le mesh body "cartoon" Apple Vision (8 triangles, 13 joints) par un **vrai mesh humain dense SMPL-X** (10475 vertices, 20908 triangles, skinné) via Multi-HMR (Naver CVPR 2024) pour l'inférence et RealityKit pour le rendu natif.

**Architecture:**
- Worker Python `multi_hmr_worker.py` : capture webcam Mac, inférence Multi-HMR PyTorch MPS, décodage SMPL-X → vertices 3D, écriture dans State
- Bridge OSC `/smplx/*` : envoi des vertices vers une app Swift dédiée `AV-Live-Body` qui héberge RealityKit
- App Swift native : ARView avec MeshResource dynamique, mise à jour vertices/frame via OSC TCP (UDP trop petit pour 10475 × 3 floats)
- Fallback : si app Swift indisponible, rendu Metal triangle pipeline existant avec MESH_MAX_TRIS bumpé à 32768

**Tech Stack:**
- Python 3.14 + PyTorch MPS + smplx + opencv-python
- Multi-HMR (PyTorch checkpoint, pas de CoreML car bloqué BlobWriter sur macOS-arm64)
- SMPL-X NEUTRAL model (académique, registration MPII)
- Swift 6 + RealityKit + SwiftUI (app séparée `launcher/AV-Live-Body/`)
- OSC TCP via python-osc + SwiftOSC pour transfert vertices ~125 KB/frame

---

## File Structure

**Python (data_only_viz/)** :
- Create: `data_only_viz/multi_hmr_worker.py` — worker MPS, ~250 lignes
- Create: `data_only_viz/smplx_decoder.py` — wrapper smplx.SMPLXLayer pour décoder params → vertices, ~80 lignes
- Create: `data_only_viz/smplx_osc_sender.py` — émet vertices via OSC TCP vers RealityKit app, ~120 lignes
- Modify: `data_only_viz/state.py` — ajout `persons_smplx: list[SMPLXPerson]`
- Modify: `data_only_viz/main.py` — option `--multi-hmr` qui démarre `MultiHMRWorker`
- Modify: `data_only_viz/renderer.py` — fallback rendu mesh SMPL-X dans Metal si app Swift absente

**Swift (launcher/AV-Live-Body/)** :
- Create: `launcher/AV-Live-Body/Package.swift` — SwiftPM exécutable
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/main.swift` — entry point
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift` — SwiftUI + ARView host
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift` — gère MeshResource + vertex update
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift` — listener TCP :57130
- Create: `launcher/AV-Live-Body/Resources/smplx_template.usdz` — mesh template skinné (généré par script)
- Create: `launcher/AV-Live-Body/Resources/smplx_faces.bin` — 20908 triangles indices binaires statiques

**Scripts/docs** :
- Create: `data_only_viz/scripts/setup_multihmr.sh` — clone Multi-HMR + download checkpoints
- Create: `data_only_viz/scripts/dump_smplx_faces.py` — extrait 20908 triangles SMPL-X dans .bin
- Modify: `data_only_viz/pyproject.toml` — extra `multihmr`

---

### Task 1: Setup Multi-HMR + SMPL-X dependencies

**Files:**
- Modify: `data_only_viz/pyproject.toml` (extra `multihmr`)
- Create: `data_only_viz/scripts/setup_multihmr.sh`
- Test: lancement manuel + presence des checkpoints

- [ ] **Step 1: Ajouter l'extra `multihmr` à pyproject.toml**

```toml
[project.optional-dependencies]
multihmr = [
    "torch>=2.4",
    "torchvision>=0.19",
    "smplx>=0.1.28",
    "einops>=0.8",
    "iopath>=0.1.10",
    "huggingface-hub>=0.24",
    "opencv-python>=4.10",
    "numpy>=1.26,<2",      # smplx requires numpy<2
    "scipy>=1.13",
    "torchgeometry>=0.1.2",
]
```

- [ ] **Step 2: Créer `scripts/setup_multihmr.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
CACHE="$HOME/.cache/av-live-multihmr"
mkdir -p "$CACHE/checkpoints" "$CACHE/models/smplx"

# 1. Clone Multi-HMR (utilise pip + sys.path injection — pas de pyproject.toml)
if [ ! -d "$CACHE/multi-hmr" ]; then
    git clone --depth=1 https://github.com/naver/multi-hmr.git "$CACHE/multi-hmr"
fi

# 2. Download Multi-HMR checkpoint base (88 MB)
CKPT="$CACHE/checkpoints/multiHMR_896_B_synth_real_occ.pt"
if [ ! -f "$CKPT" ]; then
    curl -fL --progress-bar \
        "https://download.europe.naverlabs.com/ComputerVision/multiHMR/multiHMR_896_B_synth_real_occ.pt" \
        -o "$CKPT"
fi

# 3. SMPL-X NEUTRAL : ne peut pas être téléchargé automatiquement (academic
#    license MPII). Affiche le message si manquant.
SMPLX="$CACHE/models/smplx/SMPLX_NEUTRAL.npz"
if [ ! -f "$SMPLX" ]; then
    echo "MANUEL : Inscription requise à https://smpl-x.is.tue.mpg.de/"
    echo "Telecharge SMPLX_NEUTRAL.npz et place le dans $SMPLX"
fi

echo "Setup OK. Cache : $CACHE"
```

- [ ] **Step 3: Run setup + verify checkpoint downloaded**

Run: `chmod +x data_only_viz/scripts/setup_multihmr.sh && ./data_only_viz/scripts/setup_multihmr.sh`
Expected output: `Setup OK. Cache : /Users/electron/.cache/av-live-multihmr`
Expected files:
- `~/.cache/av-live-multihmr/multi-hmr/` (repo cloné)
- `~/.cache/av-live-multihmr/checkpoints/multiHMR_896_B_synth_real_occ.pt` (88 MB)

- [ ] **Step 4: Verify Python deps install**

Run: `cd data_only_viz && uv sync --extra multihmr 2>&1 | tail -10`
Expected: `Installed N packages` sans erreur d'index ABI sur torch / smplx

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/pyproject.toml data_only_viz/scripts/setup_multihmr.sh
git commit -m "multihmr: add deps + setup script"
```

---

### Task 2: Extract SMPL-X faces topology (20908 triangles)

**Files:**
- Create: `data_only_viz/scripts/dump_smplx_faces.py`
- Create: `launcher/AV-Live-Body/Resources/smplx_faces.bin`
- Test: vérifier taille fichier ~ 251 KB (20908 × 3 × 4 octets)

- [ ] **Step 1: Écrire le script d'extraction**

Create `data_only_viz/scripts/dump_smplx_faces.py`:
```python
"""Extrait la liste des 20908 triangles du modele SMPL-X NEUTRAL et
les serialise en binaire little-endian (int32) pour consommation par
l'app Swift RealityKit."""
import sys
import struct
from pathlib import Path

import numpy as np

CACHE = Path.home() / ".cache" / "av-live-multihmr"
SMPLX = CACHE / "models" / "smplx" / "SMPLX_NEUTRAL.npz"
OUT = Path(__file__).parent.parent.parent / "launcher" / "AV-Live-Body" / "Resources" / "smplx_faces.bin"

def main():
    if not SMPLX.exists():
        print(f"SMPL-X manquant: {SMPLX}")
        print("Voir setup_multihmr.sh pour la procedure")
        sys.exit(1)
    npz = np.load(SMPLX)
    faces = npz["f"]  # shape (20908, 3)
    print(f"SMPL-X faces: {faces.shape} dtype={faces.dtype}")
    assert faces.shape == (20908, 3), f"shape attendu (20908, 3), got {faces.shape}"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Serialise little-endian int32
    with open(OUT, "wb") as f:
        for tri in faces:
            for idx in tri:
                f.write(struct.pack("<i", int(idx)))
    size = OUT.stat().st_size
    print(f"Wrote {size} bytes to {OUT} (expected {20908*3*4} = 250896)")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run script**

Run: `data_only_viz/.venv/bin/python data_only_viz/scripts/dump_smplx_faces.py`
Expected: `Wrote 250896 bytes to .../smplx_faces.bin`

- [ ] **Step 3: Verify file size**

Run: `ls -la launcher/AV-Live-Body/Resources/smplx_faces.bin`
Expected: size = 250896 bytes exactly

- [ ] **Step 4: Commit (note: faces.bin est petit, on commit)**

```bash
git add data_only_viz/scripts/dump_smplx_faces.py launcher/AV-Live-Body/Resources/smplx_faces.bin
git commit -m "smplx: extract face topology to binary"
```

---

### Task 3: State extension for SMPL-X persons

**Files:**
- Modify: `data_only_viz/state.py` (ajout dataclass + field)

- [ ] **Step 1: Lire le state.py existant pour comprendre la structure**

Run: `grep -n "class State\|@dataclass" data_only_viz/state.py | head -5`
Expected: voir les dataclass existantes (PoseKp, State) pour suivre le pattern

- [ ] **Step 2: Ajouter la dataclass SMPLXPerson en haut de state.py**

Ajouter après `class PoseKp:` (vers ligne 19) :
```python
@dataclass
class SMPLXPerson:
    """Resultats Multi-HMR pour une personne : params SMPL-X + vertices
    decodes en metres. Les vertices sont en repere camera (z > 0 devant)."""
    pid: int = -1
    vertices_3d: tuple = field(default_factory=tuple)   # ((x,y,z),) × 10475
    joints_3d: tuple = field(default_factory=tuple)      # ((x,y,z),) × 127
    translation: tuple = (0.0, 0.0, 0.0)                  # position 3D monde
    confidence: float = 0.0
    # Params SMPL-X bruts pour debug / re-decodage
    betas: tuple = field(default_factory=tuple)           # shape (10,)
    expression: tuple = field(default_factory=tuple)      # (10,)
```

- [ ] **Step 3: Ajouter `persons_smplx` à class State**

Dans la dataclass State, après les autres `persons_*`, ajouter :
```python
    # Multi-HMR (SMPL-X 10475 verts × N personnes)
    persons_smplx: list = field(default_factory=list)   # list[SMPLXPerson]
    smplx_last_t: float = 0.0
```

- [ ] **Step 4: Vérifier import OK**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "from data_only_viz.state import State, SMPLXPerson; s = State(); print('OK', len(s.persons_smplx))"
```
Expected: `OK 0`

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/state.py
git commit -m "state: add SMPLXPerson dataclass + persons_smplx field"
```

---

### Task 4: SMPL-X decoder module

**Files:**
- Create: `data_only_viz/smplx_decoder.py`
- Test: `data_only_viz/tests/test_smplx_decoder.py`

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_smplx_decoder.py`:
```python
"""Test minimal : le decoder doit produire (10475, 3) vertices depuis
les params canoniques (T-pose, shape neutre)."""
import os
from pathlib import Path

import pytest
import numpy as np

SMPLX = Path.home() / ".cache" / "av-live-multihmr" / "models" / "smplx" / "SMPLX_NEUTRAL.npz"


@pytest.mark.skipif(not SMPLX.exists(), reason="SMPL-X model not installed")
def test_decode_neutral_tpose():
    from data_only_viz.smplx_decoder import SMPLXDecoder
    dec = SMPLXDecoder(str(SMPLX), device="cpu")
    verts, joints = dec.decode_neutral()
    assert verts.shape == (10475, 3)
    assert joints.shape == (127, 3)
    # En T-pose neutre, le pelvis (joint 0) doit etre proche de l'origine
    assert np.linalg.norm(joints[0]) < 0.05
```

- [ ] **Step 2: Run test (should fail with import error)**

Run: `data_only_viz/.venv/bin/python -m pytest data_only_viz/tests/test_smplx_decoder.py -v`
Expected: FAIL `ModuleNotFoundError: No module named 'data_only_viz.smplx_decoder'`

- [ ] **Step 3: Implement minimal SMPLXDecoder**

Create `data_only_viz/smplx_decoder.py`:
```python
"""Wrapper minimal autour de smplx.SMPLXLayer pour decoder les params
de Multi-HMR (betas + thetas + expression) en vertices 3D."""
from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
import torch

LOG = logging.getLogger("smplx_decoder")


class SMPLXDecoder:
    """Charge SMPL-X NEUTRAL et expose decode(params) -> (verts, joints)."""

    def __init__(self, model_path: str, device: str = "mps") -> None:
        import smplx
        self.device = device
        # SMPLXLayer attend un dossier ou un fichier .npz/.pkl
        model_path_p = Path(model_path)
        if model_path_p.is_file():
            model_folder = str(model_path_p.parent.parent)  # remonte au dossier "models"
            ext = "npz" if model_path_p.suffix == ".npz" else "pkl"
        else:
            model_folder = str(model_path_p)
            ext = "npz"
        self.layer = smplx.SMPLXLayer(
            model_path=model_folder,
            gender="neutral",
            num_betas=10,
            num_expression_coeffs=10,
            ext=ext,
        ).to(device).eval()
        LOG.info("SMPL-X loaded from %s (device=%s)", model_folder, device)

    @torch.no_grad()
    def decode(
        self,
        betas: torch.Tensor,         # (B, 10)
        body_pose: torch.Tensor,     # (B, 21, 3, 3) ou (B, 63)
        global_orient: torch.Tensor, # (B, 1, 3, 3) ou (B, 3)
        left_hand_pose: torch.Tensor,  # (B, 15, 3, 3)
        right_hand_pose: torch.Tensor, # (B, 15, 3, 3)
        jaw_pose: torch.Tensor,        # (B, 1, 3, 3)
        expression: torch.Tensor,      # (B, 10)
        transl: torch.Tensor,          # (B, 3)
    ) -> tuple[np.ndarray, np.ndarray]:
        """Decode → vertices (B, 10475, 3) et joints (B, 127, 3) numpy."""
        out = self.layer(
            betas=betas, body_pose=body_pose, global_orient=global_orient,
            left_hand_pose=left_hand_pose, right_hand_pose=right_hand_pose,
            jaw_pose=jaw_pose, expression=expression, transl=transl,
            return_verts=True,
        )
        return out.vertices.cpu().numpy(), out.joints.cpu().numpy()

    @torch.no_grad()
    def decode_neutral(self) -> tuple[np.ndarray, np.ndarray]:
        """T-pose neutre (zero params). Utilise pour tests + USDZ template."""
        Z = torch.zeros
        B = 1
        out = self.layer(
            betas=Z((B, 10), device=self.device),
            body_pose=Z((B, 21, 3, 3), device=self.device),
            global_orient=Z((B, 1, 3, 3), device=self.device),
            left_hand_pose=Z((B, 15, 3, 3), device=self.device),
            right_hand_pose=Z((B, 15, 3, 3), device=self.device),
            jaw_pose=Z((B, 1, 3, 3), device=self.device),
            expression=Z((B, 10), device=self.device),
            transl=Z((B, 3), device=self.device),
        )
        return (out.vertices[0].cpu().numpy(),
                out.joints[0].cpu().numpy())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `data_only_viz/.venv/bin/python -m pytest data_only_viz/tests/test_smplx_decoder.py -v`
Expected: PASS (si SMPL-X téléchargé) ou SKIP (si pas téléchargé)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/smplx_decoder.py data_only_viz/tests/test_smplx_decoder.py
git commit -m "smplx: add decoder wrapper + neutral T-pose test"
```

---

### Task 5: Multi-HMR worker (Python MPS)

**Files:**
- Create: `data_only_viz/multi_hmr_worker.py`
- Test: smoke test au démarrage

- [ ] **Step 1: Écrire le worker complet**

Create `data_only_viz/multi_hmr_worker.py`:
```python
"""Worker Multi-HMR : capture webcam Mac, inference forward unique
SMPL-X (multi-personne natif), decodage vertices, ecriture dans State.

Cadence cible : 8-12 fps sur M5 (ViT-B). Le lissage One Euro sur
betas/thetas est non-negociable (sinon jitter important).
"""
from __future__ import annotations

import logging
import sys
import threading
import time
from pathlib import Path

import numpy as np

from .euro_filter import OneEuroFilter
from .state import PoseKp, SMPLXPerson, State
from .tracker import IoUTracker

LOG = logging.getLogger("multi_hmr")

CACHE = Path.home() / ".cache" / "av-live-multihmr"
CKPT = CACHE / "checkpoints" / "multiHMR_896_B_synth_real_occ.pt"
SMPLX_PATH = CACHE / "models" / "smplx" / "SMPLX_NEUTRAL.npz"
MULTIHMR_REPO = CACHE / "multi-hmr"


class MultiHMRWorker:
    def __init__(self, state: State, num_persons: int = 4,
                 target_fps: float = 10.0, device: str = "mps") -> None:
        self.state = state
        self.num_persons = num_persons
        self.period = 1.0 / max(1.0, target_fps)
        self.device = device
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        # OneEuroFilter pour params SMPL-X : 10 betas + 165 thetas (21 body
        # + 15 LH + 15 RH + 1 jaw + 1 root) * 9 (rotmat) + 10 expression
        # En pratique on lisse seulement les valeurs flat float — pas
        # axis-angle (rotmat est continu, plus stable).
        self._smooth_betas = [
            [OneEuroFilter(0.8, 0.05) for _ in range(10)]
            for _ in range(num_persons)
        ]
        self._smooth_expr = [
            [OneEuroFilter(1.0, 0.08) for _ in range(10)]
            for _ in range(num_persons)
        ]
        # Tracker IoU sur les bboxes Multi-HMR pour ID stable
        self._tracker = IoUTracker(iou_threshold=0.20, max_miss=8)

    @staticmethod
    def is_available() -> bool:
        return CKPT.exists() and SMPLX_PATH.exists() and MULTIHMR_REPO.exists()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="multi_hmr", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    # ------------------------------------------------------------------
    def _run(self) -> None:
        # Sys.path injection pour importer multi-hmr cloné
        if str(MULTIHMR_REPO) not in sys.path:
            sys.path.insert(0, str(MULTIHMR_REPO))
        try:
            import torch
            import cv2
            from model.utils import load_model  # API exposée par multi-hmr
            from .smplx_decoder import SMPLXDecoder
        except ImportError as e:
            LOG.error("deps manquantes : %s — uv sync --extra multihmr "
                      "et bash scripts/setup_multihmr.sh", e)
            return

        device = self.device if torch.backends.mps.is_available() else "cpu"
        if device != self.device:
            LOG.warning("MPS unavailable, falling back to %s", device)

        # Load Multi-HMR
        try:
            model = load_model(str(CKPT), device=device)
            model.eval()
        except Exception as e:
            LOG.error("Multi-HMR load failed: %s", e)
            return
        LOG.info("Multi-HMR loaded (ViT-B) on %s", device)

        # Load SMPL-X decoder
        decoder = SMPLXDecoder(str(SMPLX_PATH), device=device)

        # Open camera (Mac built-in)
        cap = cv2.VideoCapture(0)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 896)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 896)
        if not cap.isOpened():
            LOG.error("camera index 0 indisponible")
            return
        LOG.info("camera ouverte 896x896")

        while not self._stop.is_set():
            t0 = time.monotonic()
            ok, frame_bgr = cap.read()
            if not ok:
                time.sleep(self.period); continue

            # BGR -> RGB tensor
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            tensor = torch.from_numpy(frame_rgb).permute(2, 0, 1).float() / 255.0
            tensor = tensor.unsqueeze(0).to(device)

            # Inference Multi-HMR
            try:
                with torch.no_grad():
                    humans = model(tensor)  # list of detected persons
            except Exception as e:
                LOG.warning("inference failed: %s", e)
                time.sleep(self.period); continue

            if not humans:
                with self.state.lock():
                    self.state.persons_smplx = []
                time.sleep(self.period); continue

            # Track + smooth + decode
            persons = []
            bboxes_for_track = []
            for h in humans[: self.num_persons]:
                # h: dict avec keys 'betas', 'body_pose', 'global_orient',
                # 'left_hand_pose', 'right_hand_pose', 'jaw_pose', 'expression',
                # 'transl', 'bbox' selon API Multi-HMR
                bbox = h.get("bbox", [0, 0, 1, 1])
                bboxes_for_track.append([PoseKp(x=bbox[0], y=bbox[1], c=1.0),
                                          PoseKp(x=bbox[2], y=bbox[3], c=1.0)])

            ids = self._tracker.update(bboxes_for_track)
            t_now = time.monotonic()

            for i, h in enumerate(humans[: self.num_persons]):
                pid = ids[i] if i < len(ids) else i
                if pid < 0:
                    continue
                # Lissage One Euro sur betas et expression (rotmats laissés bruts)
                betas_raw = h["betas"].cpu().numpy()  # (10,)
                expr_raw = h["expression"].cpu().numpy()
                pid_clamped = pid % self.num_persons
                betas_smooth = np.array([
                    self._smooth_betas[pid_clamped][k](float(betas_raw[k]), t_now)
                    for k in range(10)
                ], dtype=np.float32)
                expr_smooth = np.array([
                    self._smooth_expr[pid_clamped][k](float(expr_raw[k]), t_now)
                    for k in range(10)
                ], dtype=np.float32)

                # Decode SMPL-X → vertices 10475 × 3
                verts, joints = decoder.decode(
                    betas=torch.from_numpy(betas_smooth).unsqueeze(0).to(device),
                    body_pose=h["body_pose"].unsqueeze(0).to(device),
                    global_orient=h["global_orient"].unsqueeze(0).to(device),
                    left_hand_pose=h["left_hand_pose"].unsqueeze(0).to(device),
                    right_hand_pose=h["right_hand_pose"].unsqueeze(0).to(device),
                    jaw_pose=h["jaw_pose"].unsqueeze(0).to(device),
                    expression=torch.from_numpy(expr_smooth).unsqueeze(0).to(device),
                    transl=h["transl"].unsqueeze(0).to(device),
                )
                # verts shape (1, 10475, 3)
                persons.append(SMPLXPerson(
                    pid=int(pid),
                    vertices_3d=tuple(map(tuple, verts[0])),
                    joints_3d=tuple(map(tuple, joints[0])),
                    translation=tuple(h["transl"].cpu().numpy().tolist()),
                    confidence=float(h.get("score", 1.0)),
                    betas=tuple(betas_smooth.tolist()),
                    expression=tuple(expr_smooth.tolist()),
                ))

            with self.state.lock():
                self.state.persons_smplx = persons
                self.state.smplx_last_t = t_now

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)

        cap.release()
        LOG.info("multi_hmr worker stopped")
```

- [ ] **Step 2: Smoke test : import sans crash**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "
from data_only_viz.multi_hmr_worker import MultiHMRWorker
print('is_available:', MultiHMRWorker.is_available())
"
```
Expected: `is_available: False` si checkpoints pas téléchargés (normal), pas d'exception d'import.

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/multi_hmr_worker.py
git commit -m "multihmr: add worker (PyTorch MPS + One Euro + tracker)"
```

---

### Task 6: OSC TCP sender for vertices

**Files:**
- Create: `data_only_viz/smplx_osc_sender.py`
- Test: connection refused localement = OK (port pas encore ouvert)

- [ ] **Step 1: Écrire le sender TCP**

Create `data_only_viz/smplx_osc_sender.py`:
```python
"""Envoie les vertices SMPL-X de chaque personne via TCP sur :57130.

UDP ne suffit pas : 10475 verts × 3 floats × 4 = 125 700 octets par
personne, soit > MTU 1500. TCP fragmente proprement.

Protocole binaire simple :
    [4 bytes: magic 'SMPX'][4 bytes: n_persons (int32 LE)]
    Pour chaque personne :
        [4: pid int32][4: confidence float32]
        [12: translation (3 float32)]
        [10*4: betas (10 float32)]
        [10*4: expression (10 float32)]
        [10475*3*4 = 125700: vertices (float32 LE)]
"""
from __future__ import annotations

import logging
import socket
import struct
import threading
import time
from typing import Sequence

from .state import SMPLXPerson, State

LOG = logging.getLogger("smplx_osc")

MAGIC = b"SMPX"
PORT = 57130


class SMPLXTCPSender:
    def __init__(self, state: State, host: str = "127.0.0.1",
                 port: int = PORT, target_fps: float = 12.0) -> None:
        self.state = state
        self.host = host
        self.port = port
        self.period = 1.0 / max(1.0, target_fps)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._sock: socket.socket | None = None

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="smplx_tcp", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        try:
            if self._sock:
                self._sock.close()
        except Exception:
            pass

    def _ensure_connected(self) -> bool:
        if self._sock is not None:
            return True
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.5)
            s.connect((self.host, self.port))
            s.settimeout(None)
            self._sock = s
            LOG.info("connected to %s:%d", self.host, self.port)
            return True
        except (socket.error, ConnectionRefusedError) as e:
            return False

    def _serialize_persons(self, persons: Sequence[SMPLXPerson]) -> bytes:
        buf = bytearray()
        buf += MAGIC
        buf += struct.pack("<i", len(persons))
        for p in persons:
            buf += struct.pack("<i", p.pid)
            buf += struct.pack("<f", p.confidence)
            tx, ty, tz = p.translation
            buf += struct.pack("<fff", tx, ty, tz)
            for b in p.betas[:10]:
                buf += struct.pack("<f", b)
            for _ in range(10 - len(p.betas)):
                buf += struct.pack("<f", 0.0)
            for e in p.expression[:10]:
                buf += struct.pack("<f", e)
            for _ in range(10 - len(p.expression)):
                buf += struct.pack("<f", 0.0)
            # Vertices : 10475 × 3 floats
            for vx, vy, vz in p.vertices_3d:
                buf += struct.pack("<fff", vx, vy, vz)
        return bytes(buf)

    def _run(self) -> None:
        last_warn = 0.0
        while not self._stop.is_set():
            t0 = time.monotonic()
            if not self._ensure_connected():
                if t0 - last_warn > 5.0:
                    LOG.warning("RealityKit app pas connectee (%s:%d)",
                                self.host, self.port)
                    last_warn = t0
                time.sleep(1.0); continue

            with self.state.lock():
                persons = list(self.state.persons_smplx)

            if persons:
                payload = self._serialize_persons(persons)
                try:
                    # Frame header : 4 octets longueur LE puis payload
                    self._sock.sendall(struct.pack("<I", len(payload)) + payload)
                except (socket.error, BrokenPipeError) as e:
                    LOG.info("connection lost: %s", e)
                    try: self._sock.close()
                    except Exception: pass
                    self._sock = None
                    continue

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
```

- [ ] **Step 2: Smoke test : sender démarre sans crash**

Run:
```bash
data_only_viz/.venv/bin/python -c "
from data_only_viz.smplx_osc_sender import SMPLXTCPSender
from data_only_viz.state import State
s = SMPLXTCPSender(State())
s.start()
import time; time.sleep(2)
s.stop()
print('sender lifecycle OK')
"
```
Expected: `sender lifecycle OK` + warning "RealityKit app pas connectee" dans les logs (normal, app pas encore créée)

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/smplx_osc_sender.py
git commit -m "smplx: add TCP sender (binary protocol, 125KB/frame/person)"
```

---

### Task 7: Wire MultiHMRWorker dans main.py

**Files:**
- Modify: `data_only_viz/main.py` (ajout flag + chaîne de priorité)

- [ ] **Step 1: Ajouter le flag --multi-hmr**

Dans `data_only_viz/main.py`, dans `def main()` après les autres `p.add_argument` :
```python
    p.add_argument("--multi-hmr", action="store_true",
                   help="Active Multi-HMR worker pour mesh SMPL-X dense")
```

- [ ] **Step 2: Étendre _start_pose_worker pour activer Multi-HMR**

Dans la méthode `_start_pose_worker`, en TOUTE première priorité (avant Apple Vision) :
```python
        import os as _os
        # 0. Multi-HMR (SMPL-X 10475 verts mesh dense) — si demande + dispo
        if self._opts.multi_hmr:
            try:
                from .multi_hmr_worker import MultiHMRWorker
                from .smplx_osc_sender import SMPLXTCPSender
                if MultiHMRWorker.is_available():
                    self._pose_worker = MultiHMRWorker(self._state, num_persons=4)
                    self._pose_worker.start()
                    self._smplx_tcp = SMPLXTCPSender(self._state)
                    self._smplx_tcp.start()
                    LOG.info("worker: Multi-HMR + SMPL-X (mesh dense)")
                    return
                LOG.info("Multi-HMR indisponible (checkpoints manquants)")
            except Exception as e:
                LOG.warning("Multi-HMR failed (%s) — fallback", e)
```

- [ ] **Step 3: Smoke test : --multi-hmr sans crash**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "
import sys
sys.argv = ['x', '--multi-hmr', '--pose']
from data_only_viz.main import main
# Just verify argparse doesn't fail
import argparse
p = argparse.ArgumentParser()
p.add_argument('--multi-hmr', action='store_true')
p.add_argument('--pose', action='store_true')
opts = p.parse_args(['--multi-hmr', '--pose'])
print('OK:', opts.multi_hmr, opts.pose)
"
```
Expected: `OK: True True`

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/main.py
git commit -m "main: add --multi-hmr flag, prioritize MultiHMRWorker"
```

---

### Task 8: Swift app skeleton (AV-Live-Body)

**Files:**
- Create: `launcher/AV-Live-Body/Package.swift`
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/main.swift`

- [ ] **Step 1: Créer Package.swift**

Create `launcher/AV-Live-Body/Package.swift`:
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AVLiveBody",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AVLiveBody",
            path: "Sources/AVLiveBody",
            resources: [
                .copy("../../Resources/smplx_faces.bin"),
            ]
        )
    ]
)
```

- [ ] **Step 2: Créer main.swift (entry point minimal)**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/main.swift`:
```swift
import Cocoa
import SwiftUI

@main
struct AVLiveBodyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @StateObject private var renderer = MeshRenderer()
    var body: some View {
        BodyView(renderer: renderer)
            .onAppear {
                renderer.startOSCServer()
            }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd launcher/AV-Live-Body && swift build 2>&1 | tail -10`
Expected: compile errors for missing BodyView and MeshRenderer (normal — créés ensuite)

- [ ] **Step 4: Commit (build cassé volontairement — checkpoint)**

```bash
git add launcher/AV-Live-Body/Package.swift launcher/AV-Live-Body/Sources/AVLiveBody/main.swift
git commit -m "av-live-body: swift package skeleton"
```

---

### Task 9: Swift MeshRenderer + RealityKit ARView

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift`

- [ ] **Step 1: Écrire MeshRenderer.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`:
```swift
import Combine
import Foundation
import RealityKit
import SwiftUI

/// Gere les vertices SMPL-X recus par OSC et les pousse dans une
/// MeshResource dynamique de RealityKit. Lit smplx_faces.bin une fois
/// au lancement (20908 triangles statiques).
@MainActor
final class MeshRenderer: ObservableObject {
    @Published var personEntities: [Int: ModelEntity] = [:]   // pid -> entity
    private var faces: [UInt32] = []
    private var oscServer: OSCServer?

    init() {
        loadFaces()
    }

    private func loadFaces() {
        guard let url = Bundle.module.url(forResource: "smplx_faces",
                                          withExtension: "bin") else {
            print("smplx_faces.bin not found in bundle")
            return
        }
        guard let data = try? Data(contentsOf: url) else { return }
        let n = data.count / 4
        var arr = [UInt32](repeating: 0, count: n)
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt32.self)
            for i in 0..<n { arr[i] = src[i] }
        }
        self.faces = arr
        print("Loaded \(n) face indices (\(n/3) triangles)")
    }

    func startOSCServer() {
        let server = OSCServer(port: 57130) { [weak self] persons in
            Task { @MainActor in
                self?.updatePersons(persons)
            }
        }
        server.start()
        self.oscServer = server
    }

    /// Met a jour les meshes pour les personnes recues. Cree de
    /// nouveaux ModelEntity si pid inconnu, supprime ceux absents.
    func updatePersons(_ persons: [SMPLXPersonData]) {
        let receivedPids = Set(persons.map { $0.pid })
        // Supprime les anciens
        for (pid, _) in personEntities where !receivedPids.contains(pid) {
            personEntities.removeValue(forKey: pid)
        }
        // Met a jour ou cree
        for p in persons {
            let entity = personEntities[p.pid] ?? makeEntity(pid: p.pid)
            updateMeshVertices(entity, vertices: p.vertices)
            entity.transform.translation = SIMD3(p.translation)
            personEntities[p.pid] = entity
        }
    }

    private func makeEntity(pid: Int) -> ModelEntity {
        let material = SimpleMaterial(color: colorForPid(pid),
                                      isMetallic: false)
        let entity = ModelEntity()
        entity.model = ModelComponent(
            mesh: makeMesh(vertices: Array(repeating: SIMD3<Float>(0,0,0),
                                            count: 10475)),
            materials: [material]
        )
        return entity
    }

    private func makeMesh(vertices: [SIMD3<Float>]) -> MeshResource {
        var desc = MeshDescriptor(name: "smplx")
        desc.positions = MeshBuffer(vertices)
        desc.primitives = .triangles(faces)
        return (try? MeshResource.generate(from: [desc])) ?? .generateBox(size: 0.1)
    }

    private func updateMeshVertices(_ entity: ModelEntity,
                                     vertices: [SIMD3<Float>]) {
        // Recree le mesh (MeshResource est immutable post-creation).
        // Pour vrai performance, faut LowLevelMesh (iOS17+) — TODO Task 10.
        entity.model?.mesh = makeMesh(vertices: vertices)
    }

    private func colorForPid(_ pid: Int) -> NSColor {
        let palette: [NSColor] = [
            .systemTeal, .systemPink, .systemYellow,
            .systemOrange, .systemPurple, .systemGreen,
        ]
        return palette[((pid % palette.count) + palette.count) % palette.count]
    }
}

struct SMPLXPersonData {
    let pid: Int
    let confidence: Float
    let translation: SIMD3<Float>
    let vertices: [SIMD3<Float>]   // 10475
}
```

- [ ] **Step 2: Écrire BodyView.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift`:
```swift
import RealityKit
import SwiftUI

/// Wrapper SwiftUI autour de ARView contenant les meshes SMPL-X.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.background = .color(.black)
        // Camera fixe : recule pour voir 1m devant
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 60
        let camAnchor = AnchorEntity(world: SIMD3(0, 0, 2))
        camAnchor.addChild(cam)
        view.scene.addAnchor(camAnchor)
        // Ancre globale qui va recevoir les meshes
        let bodyAnchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(bodyAnchor)
        context.coordinator.bodyAnchor = bodyAnchor
        context.coordinator.renderer = renderer
        return view
    }

    func updateNSView(_ view: ARView, context: Context) {
        // Sync entites depuis le renderer
        guard let anchor = context.coordinator.bodyAnchor else { return }
        anchor.children.removeAll()
        for entity in renderer.personEntities.values {
            anchor.addChild(entity)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var bodyAnchor: AnchorEntity?
        var renderer: MeshRenderer?
    }
}
```

- [ ] **Step 3: Build (encore cassé : OSCServer manque)**

Run: `cd launcher/AV-Live-Body && swift build 2>&1 | tail -5`
Expected: erreur sur `OSCServer` — normal, Task 10 le crée

- [ ] **Step 4: Commit (build encore cassé — checkpoint)**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift
git commit -m "av-live-body: MeshRenderer + BodyView RealityKit scaffold"
```

---

### Task 10: Swift OSCServer (TCP listener)

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift`

- [ ] **Step 1: Écrire OSCServer.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift`:
```swift
import Foundation
import Network

/// Listener TCP qui decode le protocole binaire de smplx_osc_sender.py.
/// Frame : [u32 length][SMPX magic][i32 n_persons]
///         [(pid i32 + conf f32 + 3 transl + 10 betas + 10 expr + 10475*3 verts)] × N
final class OSCServer {
    private let port: NWEndpoint.Port
    private let onPersons: ([SMPLXPersonData]) -> Void
    private var listener: NWListener?
    private var conn: NWConnection?
    private var buffer = Data()

    init(port: UInt16, onPersons: @escaping ([SMPLXPersonData]) -> Void) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.onPersons = onPersons
    }

    func start() {
        let params = NWParameters.tcp
        params.acceptLocalOnly = true
        do {
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] conn in
                self?.conn = conn
                conn.start(queue: .global(qos: .userInitiated))
                self?.receive(on: conn)
            }
            l.start(queue: .global())
            self.listener = l
            print("OSC TCP listening on :\(port)")
        } catch {
            print("OSCServer.start error: \(error)")
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 64) { [weak self]
            data, _, isComplete, error in
            guard let self = self else { return }
            if let d = data { self.buffer.append(d) }
            self.parseFrames()
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            self.receive(on: conn)
        }
    }

    private func parseFrames() {
        while true {
            guard buffer.count >= 4 else { return }
            let len = buffer.withUnsafeBytes {
                $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian
            }
            guard buffer.count >= 4 + Int(len) else { return }
            let payload = buffer.subdata(in: 4..<(4 + Int(len)))
            buffer.removeSubrange(0..<(4 + Int(len)))
            decode(payload: payload)
        }
    }

    private func decode(payload: Data) {
        guard payload.count > 8 else { return }
        let magic = payload.subdata(in: 0..<4)
        guard magic == "SMPX".data(using: .ascii) else { return }
        var offset = 4
        let nPersons = payload.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: Int32.self).littleEndian
        }
        offset += 4
        var persons: [SMPLXPersonData] = []
        for _ in 0..<Int(nPersons) {
            // pid (i32) + conf (f32) + transl (3 f32)
            let pid = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Int32.self).littleEndian
            }
            offset += 4
            let conf = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            let tx = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            let ty = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            let tz = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            // Skip betas (10*4) et expression (10*4) — pas utilisés pour le rendu
            offset += 80
            // Vertices 10475 × 3
            var verts: [SIMD3<Float>] = []
            verts.reserveCapacity(10475)
            for _ in 0..<10475 {
                let x = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
                offset += 4
                let y = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
                offset += 4
                let z = payload.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
                offset += 4
                verts.append(SIMD3<Float>(x, y, z))
            }
            persons.append(SMPLXPersonData(
                pid: Int(pid), confidence: conf,
                translation: SIMD3(tx, ty, tz),
                vertices: verts
            ))
        }
        onPersons(persons)
    }
}
```

- [ ] **Step 2: Build Swift package**

Run: `cd launcher/AV-Live-Body && swift build 2>&1 | tail -10`
Expected: `Build complete!` ou erreur résiduelle à fixer

- [ ] **Step 3: Lance l'app + verify listener**

Run:
```bash
cd launcher/AV-Live-Body && swift run AVLiveBody &
sleep 3
nc -zv 127.0.0.1 57130 2>&1 | head -3
pkill AVLiveBody
```
Expected: `Connection to 127.0.0.1 port 57130 [tcp/*] succeeded!`

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/OSCServer.swift
git commit -m "av-live-body: TCP OSC listener for SMPL-X vertices"
```

---

### Task 11: End-to-end smoke test

**Files:**
- Aucun fichier modifié, test manuel

- [ ] **Step 1: Lance l'app Swift en background**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body
swift run AVLiveBody &
SWIFT_PID=$!
sleep 5
```

- [ ] **Step 2: Lance le worker Python avec --multi-hmr**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -m data_only_viz.main -v --pose --multi-hmr --fullscreen > /tmp/multi-hmr.log 2>&1 &
PYTHON_PID=$!
sleep 30   # laisse Multi-HMR + SMPL-X load (~10s) + 20s d'inference
```

- [ ] **Step 3: Vérifier que des persons_smplx sont émis**

Run: `grep -E "Multi-HMR|smplx_tcp|connected to|persons" /tmp/multi-hmr.log | tail -10`
Expected:
- `Multi-HMR loaded (ViT-B)`
- `smplx_tcp — connected to 127.0.0.1:57130`
- Pas d'erreur sur le decoder

- [ ] **Step 4: Vérifier visuel dans l'app Swift**

Manuel : la fenêtre AVLiveBody devrait afficher un mesh humain SMPL-X
qui suit l'utilisateur devant la cam. Si pose détectée, mesh visible
en couleur (palette pid).

- [ ] **Step 5: Cleanup**

```bash
kill $PYTHON_PID $SWIFT_PID 2>/dev/null
echo "smoke test done"
```

- [ ] **Step 6: Commit (rapport doc)**

Create `docs/superpowers/plans/2026-05-13-multihmr-realitykit-body-mesh-RESULTS.md`:
```markdown
# Multi-HMR + RealityKit — résultats smoke test

- Multi-HMR load : OK / KO (avec raison)
- SMPL-X decoder : OK / KO
- TCP sender : connected / refused
- App Swift : mesh visible / vide
- FPS observé : N
- Latence inference : N ms
```

```bash
git add docs/superpowers/plans/2026-05-13-multihmr-realitykit-body-mesh-RESULTS.md
git commit -m "multihmr: end-to-end smoke test results"
```

---

### Task 12: Launcher integration (toggle Multi-HMR)

**Files:**
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift`
- Modify: `launcher/Sources/AVLiveLauncher/MenuBarContent.swift`

- [ ] **Step 1: Ajouter `useMultiHMR` à ProcessManager**

Dans `launcher/Sources/AVLiveLauncher/ProcessManager.swift`, dans la
classe ProcessManager (après les autres `@Published`) :
```swift
    @Published var useMultiHMR: Bool {
        didSet { defaults.set(useMultiHMR, forKey: "useMultiHMR") }
    }
```

Et dans `init()` :
```swift
        useMultiHMR = defaults.bool(forKey: "useMultiHMR")
```

- [ ] **Step 2: Passer le flag au worker Python**

Dans `startMetalViz`, juste après la définition de `p.arguments` :
```swift
        if useMultiHMR {
            p.arguments?.append("--multi-hmr")
        }
```

- [ ] **Step 3: Bouton toggle dans MenuBarContent**

Dans `MenuBarContent.swift`, ajouter sous le picker `mode` :
```swift
            if processManager.mode == .dataOnly {
                Toggle("Multi-HMR (mesh SMPL-X dense)",
                       isOn: $processManager.useMultiHMR)
                    .toggleStyle(.switch)
            }
```

- [ ] **Step 4: Build launcher + check**

Run: `cd launcher && ./build.sh 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add launcher/Sources/AVLiveLauncher/ProcessManager.swift launcher/Sources/AVLiveLauncher/MenuBarContent.swift
git commit -m "launcher: add Multi-HMR toggle in data-only mode"
```

---

### Task 13: Launcher spawns AV-Live-Body app automatically

**Files:**
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift`

- [ ] **Step 1: Méthode startBodyApp + stopBodyApp**

Dans ProcessManager (après `stopMetalViz`) :
```swift
    private var bodyAppProc: Process?

    func startBodyApp() {
        guard useMultiHMR else { return }
        guard bodyAppProc == nil else { return }
        let pkgDir = URL(fileURLWithPath: "\(homeDir)/Documents/Projets/AV-Live/launcher/AV-Live-Body")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["swift", "run", "-c", "release", "AVLiveBody"]
        p.currentDirectoryURL = pkgDir
        attach(process: p, label: "body")
        do {
            try p.run()
            bodyAppProc = p
            append(source: "launcher", text: "started AV-Live-Body")
            p.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async { self?.bodyAppProc = nil }
            }
        } catch {
            append(source: "launcher", text: "startBodyApp failed: \(error)")
        }
    }

    func stopBodyApp() {
        bodyAppProc?.terminate()
    }
```

- [ ] **Step 2: Wire dans startAll()**

Dans `startAll()`, en mode `dataOnly`, ajouter après startMetalViz :
```swift
            if useMultiHMR {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.startBodyApp()
                }
            }
```

- [ ] **Step 3: stopAll inclut bodyApp**

Dans `stopAll()` :
```swift
        bodyAppProc?.terminate()
```

- [ ] **Step 4: Build launcher**

Run: `cd launcher && ./build.sh 2>&1 | tail -3`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add launcher/Sources/AVLiveLauncher/ProcessManager.swift
git commit -m "launcher: auto-spawn AV-Live-Body when --multi-hmr active"
```

---

### Task 14: Performance optimization (LowLevelMesh + 12 fps target)

**Files:**
- Modify: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`

- [ ] **Step 1: Migrer vers LowLevelMesh (macOS 14+, vertex update sans rebuild)**

Remplace `updateMeshVertices` dans MeshRenderer :
```swift
    /// LowLevelMesh permet d'updater les vertex buffer SANS recreer le
    /// MeshResource. Disponible macOS 14+ / iOS 17+.
    private func updateMeshVertices(_ entity: ModelEntity,
                                     vertices: [SIMD3<Float>]) {
        guard let llMesh = entity.components[LowLevelMeshComponent.self]?.mesh else {
            // Premier coup : cree
            try? createLowLevelMesh(for: entity, vertices: vertices)
            return
        }
        // Update vertex buffer in-place
        llMesh.withUnsafeMutableBytes(bufferIndex: 0) { rawPtr in
            let dst = rawPtr.bindMemory(to: SIMD3<Float>.self)
            for (i, v) in vertices.enumerated() where i < dst.count {
                dst[i] = v
            }
        }
    }

    private func createLowLevelMesh(for entity: ModelEntity,
                                     vertices: [SIMD3<Float>]) throws {
        let vertexAttr = LowLevelMesh.Attribute(
            semantic: .position, format: .float3, offset: 0)
        let vertexLayout = LowLevelMesh.Layout(
            bufferIndex: 0, bufferStride: MemoryLayout<SIMD3<Float>>.stride)
        let desc = LowLevelMesh.Descriptor(
            vertexCapacity: vertices.count,
            vertexAttributes: [vertexAttr],
            vertexLayouts: [vertexLayout],
            indexCapacity: faces.count,
            indexType: .uint32
        )
        let mesh = try LowLevelMesh(descriptor: desc)
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { ptr in
            let dst = ptr.bindMemory(to: SIMD3<Float>.self)
            for (i, v) in vertices.enumerated() where i < dst.count {
                dst[i] = v
            }
        }
        mesh.withUnsafeMutableIndices { ptr in
            let dst = ptr.bindMemory(to: UInt32.self)
            for (i, f) in faces.enumerated() where i < dst.count {
                dst[i] = f
            }
        }
        mesh.parts.replaceAll([
            .init(indexCount: faces.count, topology: .triangle,
                  materialIndex: 0,
                  bounds: BoundingBox(min: [-1, -1, -1], max: [1, 1, 1]))
        ])
        entity.components.set(LowLevelMeshComponent(mesh: mesh))
    }
```

- [ ] **Step 2: Build + smoke test perf**

Run:
```bash
cd launcher/AV-Live-Body && swift build -c release 2>&1 | tail -3
```
Expected: `Build complete!`

- [ ] **Step 3: Run end-to-end avec mesure FPS**

Run: même que Task 11 step 1-2, puis dans /tmp/multi-hmr.log chercher des indicateurs de FPS :
```bash
grep -E "fps|ms|frame" /tmp/multi-hmr.log | tail -10
```
Expected: FPS Multi-HMR > 8, latence inference < 130 ms

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift
git commit -m "av-live-body: LowLevelMesh for in-place vertex updates"
```

---

### Task 15: Documentation finale

**Files:**
- Modify: `data_only_viz/wham_tram_scaffold.md` (statut updated)
- Modify: `data_only_viz/multi_hmr_scaffold.md` (statut: IMPLEMENTED)
- Create: `data_only_viz/MULTIHMR_README.md`

- [ ] **Step 1: Marquer scaffolds comme implémentés**

Dans `multi_hmr_scaffold.md`, ajouter en haut :
```markdown
> **IMPLÉMENTÉ 2026-05-13** — voir `MULTIHMR_README.md` pour l'utilisation.
> Le pipeline complet (Multi-HMR worker + SMPL-X decoder + TCP sender +
> Swift RealityKit app) est en place. Ce document garde l'analyse
> initiale.
```

- [ ] **Step 2: Créer README utilisateur**

Create `data_only_viz/MULTIHMR_README.md`:
```markdown
# Multi-HMR + RealityKit — utilisation

## Setup une fois

```bash
./data_only_viz/scripts/setup_multihmr.sh   # clone + download checkpoints
# Manuel : inscription MPII pour SMPL-X NEUTRAL, placer dans
# ~/.cache/av-live-multihmr/models/smplx/SMPLX_NEUTRAL.npz
cd data_only_viz && uv sync --extra multihmr
data_only_viz/.venv/bin/python data_only_viz/scripts/dump_smplx_faces.py
```

## Lancement

Option 1 — launcher (auto) :
1. Ouvrir AVLiveLauncher.app
2. Mode "data-only", activer "Multi-HMR (mesh SMPL-X dense)"
3. Le launcher démarre : sclang + bridge + viz Python + AV-Live-Body Swift

Option 2 — manuel (debug) :
```bash
# Terminal 1 : RealityKit app
cd launcher/AV-Live-Body && swift run -c release AVLiveBody

# Terminal 2 : worker Python
cd data_only_viz/.venv/bin/python -m data_only_viz.main \
    -v --pose --multi-hmr --fullscreen
```

## Architecture

```
webcam Mac (cv2 idx 0)
    ↓ frame BGR
Multi-HMR ViT-B (PyTorch MPS) : ~110 ms / frame
    ↓ params SMPL-X × N persons
OneEuroFilter (betas, expression)
    ↓
SMPLXDecoder : params → 10475 vertices × N
    ↓ state.persons_smplx
SMPLXTCPSender : binaire 125 KB/frame/personne sur :57130
    ↓ TCP
AVLiveBody Swift : OSCServer → MeshRenderer → LowLevelMesh
    ↓
RealityKit ARView : mesh skinné en couleur par pid
```

## FPS attendu

- Multi-HMR ViT-B sur M5 MPS : ~110 ms / frame = 9 fps
- TCP sender : 12 fps target (throttle)
- RealityKit render : 60 fps interpolé entre frames Multi-HMR

## Debug

- Pas de mesh affiché : vérifier `~/.cache/av-live-multihmr/checkpoints/multiHMR_*.pt` existe
- Pas de SMPL-X : vérifier `~/.cache/av-live-multihmr/models/smplx/SMPLX_NEUTRAL.npz`
- TCP refused : l'app Swift doit tourner AVANT le worker Python
- FPS bas : passer à ViT-S (`multiHMR_896_S_*.pt`) qui est plus rapide
```

- [ ] **Step 3: Commit final**

```bash
git add data_only_viz/multi_hmr_scaffold.md data_only_viz/MULTIHMR_README.md
git commit -m "docs: finalize Multi-HMR + RealityKit documentation"
```

---

## Récap final

Le plan ci-dessus livre :

1. **Setup deps + checkpoints** (Tasks 1-2)
2. **Worker Python complet** : Multi-HMR PyTorch MPS, SMPL-X decoder, One Euro lissage, IoU tracker (Tasks 3-5)
3. **TCP sender vertices binaire** (Task 6)
4. **Intégration data_only_viz** (Task 7)
5. **App Swift RealityKit** : ARView, MeshRenderer, OSC TCP listener (Tasks 8-10)
6. **Smoke test end-to-end** (Task 11)
7. **Intégration launcher** (Tasks 12-13)
8. **Optimisation LowLevelMesh** pour update vertex sans rebuild (Task 14)
9. **Documentation utilisateur** (Task 15)

Total : 15 tasks, ~3-5 jours pour un dev avec familiarité PyTorch + Swift.
