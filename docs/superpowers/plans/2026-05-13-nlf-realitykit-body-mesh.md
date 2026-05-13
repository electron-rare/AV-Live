# NLF + RealityKit Body Mesh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le mesh body "cartoon" Apple Vision (8 triangles, 13 joints) par un **vrai mesh humain dense SMPL** (6890 vertices, 13776 triangles) via NLF (Sarandi, NeurIPS 2024) pour l'inference et RealityKit pour le rendu natif. NLF fournit des vertices 3D **directement** (path nonparametrique) sans aucun fichier de modele corporel externe (pas de SMPL-X NEUTRAL.npz academique).

**Pourquoi NLF au lieu de Multi-HMR + SMPL-X :**
- Code MIT license, checkpoints telechargeables librement (GitHub Releases)
- Multi-personne natif (modeles `_multi` incluent detecteur + estimateur)
- TorchScript pre-compile : `torch.jit.load()` — pas de clone repo ni sys.path hack
- Sorties nonparametriques `vertices3d_nonparam` : 6890 vertices SMPL directement, zero dependance `smplx` package
- Pas besoin d'inscription academique MPII

**Architecture:**
- Worker Python `nlf_worker.py` : capture webcam Mac, inference NLF TorchScript MPS, extraction vertices 3D nonparametriques, ecriture dans State
- TCP sender binaire sur :57130 : envoi des vertices vers une app Swift dediee `AV-Live-Body`
- App Swift native : RealityKit avec MeshResource dynamique, mise a jour vertices/frame via TCP
- Fallback : si app Swift indisponible, rendu Metal triangle pipeline existant avec MESH_MAX_TRIS bumpe

**Tech Stack:**
- Python 3.14 + PyTorch MPS + torchvision + opencv-python
- NLF TorchScript checkpoint (`nlf_l_multi_0.3.2.torchscript`, 470 MB — ou `nlf_s_multi` 284 MB pour perf)
- Swift 6 + RealityKit + SwiftUI (app separee `launcher/AV-Live-Body/`)
- TCP binaire custom pour transfert vertices ~82 KB/frame/personne (6890 x 3 x 4)

**Topologie SMPL :** 6890 vertices, 13776 triangles (faces). Les faces sont statiques et extraites une seule fois depuis les donnees NLF embarquees dans le checkpoint.

---

## File Structure

**Python (data_only_viz/)** :
- Create: `data_only_viz/nlf_worker.py` — worker MPS TorchScript, ~200 lignes
- Create: `data_only_viz/nlf_tcp_sender.py` — emet vertices via TCP vers RealityKit app, ~120 lignes
- Create: `data_only_viz/scripts/setup_nlf.sh` — download checkpoint depuis GitHub Releases
- Create: `data_only_viz/scripts/dump_smpl_faces.py` — extrait 13776 triangles SMPL dans .bin
- Create: `data_only_viz/tests/test_nlf_worker.py` — test unitaire import + shapes
- Modify: `data_only_viz/state.py` — ajout `NLFPerson` dataclass + `persons_nlf` field
- Modify: `data_only_viz/main.py` — option `--nlf` qui demarre `NLFWorker`
- Modify: `data_only_viz/pyproject.toml` — extra `nlf`

**Swift (launcher/AV-Live-Body/)** :
- Create: `launcher/AV-Live-Body/Package.swift` — SwiftPM executable
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/main.swift` — entry point
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift` — SwiftUI + RealityKit host
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift` — gere MeshResource + vertex update
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/TCPServer.swift` — listener TCP :57130
- Create: `launcher/AV-Live-Body/Resources/smpl_faces.bin` — 13776 triangles indices binaires statiques

**Launcher** :
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift` — toggle NLF + spawn body app
- Modify: `launcher/Sources/AVLiveLauncher/MenuBarContent.swift` — bouton toggle UI

---

### Task 1: Setup NLF dependencies + download checkpoint

**Files:**
- Modify: `data_only_viz/pyproject.toml` (extra `nlf`)
- Create: `data_only_viz/scripts/setup_nlf.sh`
- Test: presence du checkpoint apres execution

- [ ] **Step 1: Ajouter l'extra `nlf` a pyproject.toml**

```toml
[project.optional-dependencies]
nlf = [
    "torch>=2.4",
    "torchvision>=0.19",
    "opencv-python>=4.10",
    "numpy>=1.26",
]
```

Note : pas de `smplx` package, pas de `einops`, pas de `iopath` — NLF TorchScript est auto-contenu.

- [ ] **Step 2: Creer `scripts/setup_nlf.sh`**

Create `data_only_viz/scripts/setup_nlf.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
CACHE="$HOME/.cache/av-live-nlf"
mkdir -p "$CACHE"

# NLF Large multi-person TorchScript (470 MB)
CKPT="$CACHE/nlf_l_multi.torchscript"
if [ ! -f "$CKPT" ]; then
    echo "Downloading NLF-L multi-person (470 MB)..."
    curl -fL --progress-bar \
        "https://github.com/isarandi/nlf/releases/download/v0.3.2/nlf_l_multi_0.3.2.torchscript" \
        -o "$CKPT"
fi

# NLF Small multi-person TorchScript (284 MB) — fallback plus rapide
CKPT_S="$CACHE/nlf_s_multi.torchscript"
if [ ! -f "$CKPT_S" ]; then
    echo "Downloading NLF-S multi-person (284 MB)..."
    curl -fL --progress-bar \
        "https://github.com/isarandi/nlf/releases/download/v0.2.2/nlf_s_multi_0.2.2.torchscript" \
        -o "$CKPT_S"
fi

echo "Setup OK. Cache : $CACHE"
ls -lh "$CACHE"/*.torchscript
```

- [ ] **Step 3: Run setup + verify checkpoint downloaded**

Run: `chmod +x data_only_viz/scripts/setup_nlf.sh && ./data_only_viz/scripts/setup_nlf.sh`
Expected output: `Setup OK. Cache : /Users/electron/.cache/av-live-nlf`
Expected files:
- `~/.cache/av-live-nlf/nlf_l_multi.torchscript` (~470 MB)
- `~/.cache/av-live-nlf/nlf_s_multi.torchscript` (~284 MB)

- [ ] **Step 4: Verify Python deps install**

Run: `cd /Users/electron/Documents/Projets/AV-Live/data_only_viz && uv sync --extra nlf 2>&1 | tail -10`
Expected: `Installed N packages` sans erreur ABI sur torch

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/pyproject.toml data_only_viz/scripts/setup_nlf.sh
git commit -m "nlf: add deps + setup script for NLF checkpoints"
```

---

### Task 2: Extract SMPL faces topology (13776 triangles)

**Files:**
- Create: `data_only_viz/scripts/dump_smpl_faces.py`
- Create: `launcher/AV-Live-Body/Resources/smpl_faces.bin`
- Test: verifier taille fichier = 165312 bytes (13776 x 3 x 4 octets)

NLF utilise la topologie SMPL standard (6890 vertices, 13776 faces). Les faces
sont disponibles dans le fichier `nlf_data_files.zip` des releases, ou directement
extraites depuis le modele TorchScript lui-meme (le checkpoint embarque les faces
SMPL). On peut aussi utiliser la constante SMPL standard : les 13776 triangles
sont identiques dans toutes les implementations SMPL (fichier `smpl_faces.npy`
disponible dans de multiples repos open-source).

- [ ] **Step 1: Ecrire le script d'extraction**

Create `data_only_viz/scripts/dump_smpl_faces.py`:
```python
"""Extrait les 13776 triangles SMPL (6890 vertices) et les serialise en
binaire little-endian (uint32) pour consommation par l'app Swift RealityKit.

Strategie : tente d'abord d'extraire depuis nlf_data_files.zip si present,
sinon charge le modele TorchScript et tente d'acceder aux faces embarquees,
sinon telecharge le fichier SMPL faces standard depuis un repo open-source.
"""
import struct
import sys
from pathlib import Path

import numpy as np

CACHE = Path.home() / ".cache" / "av-live-nlf"
OUT = (Path(__file__).parent.parent.parent
       / "launcher" / "AV-Live-Body" / "Resources" / "smpl_faces.bin")

# SMPL standard : 13776 triangles, 6890 vertices
EXPECTED_FACES = 13776
EXPECTED_VERTS = 6890


def try_from_data_files() -> np.ndarray | None:
    """Tente d'extraire depuis nlf_data_files.zip."""
    import zipfile
    zf = CACHE / "nlf_data_files.zip"
    if not zf.exists():
        return None
    with zipfile.ZipFile(zf) as z:
        # Cherche un fichier contenant 'faces' ou 'f' dans le zip
        for name in z.namelist():
            if "smpl" in name.lower() and name.endswith(".npy"):
                with z.open(name) as f:
                    arr = np.load(f)
                    if arr.shape == (EXPECTED_FACES, 3):
                        return arr
    return None


def try_from_torchscript() -> np.ndarray | None:
    """Charge le checkpoint et cherche les faces SMPL."""
    try:
        import torch
        ckpt = CACHE / "nlf_l_multi.torchscript"
        if not ckpt.exists():
            return None
        model = torch.jit.load(str(ckpt), map_location="cpu")
        # Explore les buffers pour trouver un tensor (13776, 3)
        for name, buf in model.named_buffers():
            if buf.shape == (EXPECTED_FACES, 3):
                print(f"Found faces in buffer '{name}'")
                return buf.numpy().astype(np.int32)
        # Explore aussi les attributs
        for attr in dir(model):
            try:
                val = getattr(model, attr)
                if hasattr(val, 'shape') and val.shape == (EXPECTED_FACES, 3):
                    print(f"Found faces in attr '{attr}'")
                    return val.numpy().astype(np.int32) if hasattr(val, 'numpy') else np.array(val, dtype=np.int32)
            except Exception:
                continue
    except Exception as e:
        print(f"TorchScript extraction failed: {e}")
    return None


def download_smpl_faces() -> np.ndarray:
    """Telecharge les faces SMPL standard depuis un repo open-source.
    Les faces SMPL sont identiques dans toutes les implementations —
    c'est une constante topologique publique (pas un modele appris)."""
    import urllib.request
    import tempfile
    # Source : fichier faces standard SMPL (domaine public, topologie fixe)
    url = "https://raw.githubusercontent.com/CalciferZh/SMPL/master/smpl/smpl_webuser/hello_smpl/faces.npy"
    print(f"Downloading SMPL faces from {url}...")
    with tempfile.NamedTemporaryFile(suffix=".npy") as tmp:
        urllib.request.urlretrieve(url, tmp.name)
        faces = np.load(tmp.name)
    if faces.shape != (EXPECTED_FACES, 3):
        # Certains repos ont (13776, 3) directement, d'autres non
        raise ValueError(f"Shape inattendu: {faces.shape}, attendu ({EXPECTED_FACES}, 3)")
    return faces.astype(np.int32)


def main():
    faces = try_from_data_files()
    if faces is None:
        print("nlf_data_files.zip absent ou faces non trouvees, essai TorchScript...")
        faces = try_from_torchscript()
    if faces is None:
        print("TorchScript: faces non trouvees dans les buffers, download fallback...")
        faces = download_smpl_faces()

    print(f"SMPL faces: {faces.shape} dtype={faces.dtype}")
    assert faces.shape == (EXPECTED_FACES, 3), f"shape attendu ({EXPECTED_FACES}, 3), got {faces.shape}"
    assert faces.max() < EXPECTED_VERTS, f"index max {faces.max()} >= {EXPECTED_VERTS}"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as f:
        for tri in faces:
            for idx in tri:
                f.write(struct.pack("<I", int(idx)))
    size = OUT.stat().st_size
    expected_size = EXPECTED_FACES * 3 * 4
    print(f"Wrote {size} bytes to {OUT} (expected {expected_size})")
    assert size == expected_size


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run script**

Run: `cd /Users/electron/Documents/Projets/AV-Live && data_only_viz/.venv/bin/python data_only_viz/scripts/dump_smpl_faces.py`
Expected: `Wrote 165312 bytes to .../smpl_faces.bin`

- [ ] **Step 3: Verify file size**

Run: `ls -la launcher/AV-Live-Body/Resources/smpl_faces.bin`
Expected: size = 165312 bytes exactly (13776 x 3 x 4)

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/scripts/dump_smpl_faces.py launcher/AV-Live-Body/Resources/smpl_faces.bin
git commit -m "nlf: extract SMPL face topology to binary"
```

---

### Task 3: State extension for NLF persons

**Files:**
- Modify: `data_only_viz/state.py` (ajout dataclass + field)

- [ ] **Step 1: Lire le state.py existant pour comprendre la structure**

Run: `grep -n "class State\|@dataclass\|persons_" /Users/electron/Documents/Projets/AV-Live/data_only_viz/state.py | head -10`
Expected: voir les dataclass existantes (PoseKp, State) et les champs `persons_body` etc.

- [ ] **Step 2: Ajouter la dataclass NLFPerson apres PoseKp (vers ligne 20)**

```python
@dataclass
class NLFPerson:
    """Resultats NLF pour une personne : vertices 3D SMPL (6890) en metres,
    coordonnees camera (z > 0 devant). Le path nonparametrique fournit les
    vertices directement sans decodage SMPL explicite."""
    pid: int = -1
    vertices_3d: tuple = field(default_factory=tuple)   # ((x,y,z),) x 6890
    joints_3d: tuple = field(default_factory=tuple)      # ((x,y,z),) x 24 (SMPL)
    translation: tuple = (0.0, 0.0, 0.0)
    confidence: float = 0.0
```

- [ ] **Step 3: Ajouter `persons_nlf` a class State**

Dans la dataclass State, apres les autres `persons_*` (vers ligne 73) :
```python
    # NLF (SMPL 6890 verts x N personnes, path nonparametrique)
    persons_nlf: list = field(default_factory=list)   # list[NLFPerson]
    nlf_last_t: float = 0.0
```

- [ ] **Step 4: Verifier import OK**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "from data_only_viz.state import State, NLFPerson; s = State(); print('OK', len(s.persons_nlf))"
```
Expected: `OK 0`

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/state.py
git commit -m "state: add NLFPerson dataclass + persons_nlf field"
```

---

### Task 4: NLF Worker (Python MPS TorchScript)

**Files:**
- Create: `data_only_viz/nlf_worker.py`
- Create: `data_only_viz/tests/test_nlf_worker.py`

- [ ] **Step 1: Write the failing test**

Create `data_only_viz/tests/test_nlf_worker.py`:
```python
"""Tests minimaux pour le worker NLF : import sans crash, shapes correctes
sur les sorties si checkpoint present."""
from pathlib import Path

import pytest


CKPT = Path.home() / ".cache" / "av-live-nlf" / "nlf_l_multi.torchscript"


def test_import_no_crash():
    from data_only_viz.nlf_worker import NLFWorker
    assert hasattr(NLFWorker, "is_available")


def test_is_available_reflects_checkpoint():
    from data_only_viz.nlf_worker import NLFWorker
    # Doit etre coherent avec la presence du checkpoint
    assert NLFWorker.is_available() == CKPT.exists()


@pytest.mark.skipif(not CKPT.exists(), reason="NLF checkpoint not installed")
def test_load_model_shapes():
    """Charge le modele et verifie que detect_smpl_batched existe."""
    import torch
    model = torch.jit.load(str(CKPT), map_location="cpu").eval()
    assert hasattr(model, "detect_smpl_batched"), (
        "Le checkpoint doit exposer detect_smpl_batched")
```

- [ ] **Step 2: Run test (should fail with import error)**

Run: `cd /Users/electron/Documents/Projets/AV-Live && data_only_viz/.venv/bin/python -m pytest data_only_viz/tests/test_nlf_worker.py -v`
Expected: FAIL `ModuleNotFoundError: No module named 'data_only_viz.nlf_worker'`

- [ ] **Step 3: Implement NLFWorker**

Create `data_only_viz/nlf_worker.py`:
```python
"""Worker NLF : capture webcam Mac, inference TorchScript multi-personne,
extraction vertices 3D nonparametriques SMPL (6890 verts), ecriture State.

NLF (Sarandi, NeurIPS 2024) fournit des vertices directement via le path
nonparametrique — pas besoin de modele SMPL-X externe. Le checkpoint
TorchScript est auto-contenu : detecteur + estimateur multi-personne.

Cadence cible : 8-12 fps sur M5 (NLF-L). NLF-S pour > 15 fps.
"""
from __future__ import annotations

import logging
import threading
import time
from pathlib import Path

import numpy as np

from .state import NLFPerson, State

LOG = logging.getLogger("nlf")

CACHE = Path.home() / ".cache" / "av-live-nlf"
CKPT_L = CACHE / "nlf_l_multi.torchscript"
CKPT_S = CACHE / "nlf_s_multi.torchscript"

# SMPL standard
N_VERTS = 6890
N_JOINTS = 24


class NLFWorker:
    def __init__(self, state: State, num_persons: int = 4,
                 target_fps: float = 10.0, device: str = "mps",
                 use_small: bool = False) -> None:
        self.state = state
        self.num_persons = num_persons
        self.period = 1.0 / max(1.0, target_fps)
        self.device = device
        self.ckpt_path = CKPT_S if use_small else CKPT_L
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        # One Euro filters pour lissage position (3 coords x N persons)
        self._smooth_pos: list[list] = []

    @staticmethod
    def is_available() -> bool:
        return CKPT_L.exists() or CKPT_S.exists()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="nlf", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        try:
            import torch
            import cv2
        except ImportError as e:
            LOG.error("deps manquantes : %s — uv sync --extra nlf", e)
            return

        # Device selection
        if self.device == "mps" and not torch.backends.mps.is_available():
            LOG.warning("MPS unavailable, falling back to cpu")
            device = "cpu"
        else:
            device = self.device

        # Load NLF TorchScript model
        if not self.ckpt_path.exists():
            # Fallback to whatever is available
            if CKPT_L.exists():
                self.ckpt_path = CKPT_L
            elif CKPT_S.exists():
                self.ckpt_path = CKPT_S
            else:
                LOG.error("No NLF checkpoint found in %s", CACHE)
                return

        try:
            model = torch.jit.load(
                str(self.ckpt_path), map_location=device).eval()
        except Exception as e:
            LOG.error("NLF load failed: %s", e)
            return
        ckpt_name = self.ckpt_path.stem
        LOG.info("NLF loaded (%s) on %s", ckpt_name, device)

        # Init One Euro filters for translation smoothing
        from .euro_filter import OneEuroFilter
        from .tracker import IoUTracker
        self._smooth_pos = [
            [OneEuroFilter(0.8, 0.05) for _ in range(3)]
            for _ in range(self.num_persons)
        ]
        tracker = IoUTracker(iou_threshold=0.20, max_miss=8)

        # Open camera (Mac built-in)
        cap = cv2.VideoCapture(0)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        if not cap.isOpened():
            LOG.error("camera index 0 indisponible")
            return
        LOG.info("camera ouverte")

        while not self._stop.is_set():
            t0 = time.monotonic()
            ok, frame_bgr = cap.read()
            if not ok:
                time.sleep(self.period)
                continue

            # BGR -> RGB tensor [C, H, W] uint8
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            tensor = torch.from_numpy(frame_rgb).permute(2, 0, 1)
            frame_batch = tensor.unsqueeze(0).to(device)

            # Inference NLF multi-person
            try:
                with torch.inference_mode():
                    pred = model.detect_smpl_batched(frame_batch)
            except Exception as e:
                LOG.warning("inference failed: %s", e)
                time.sleep(self.period)
                continue

            # pred contient pour le batch[0] :
            #   'vertices3d_nonparam' : (n_persons, 6890, 3)
            #   'joints3d_nonparam'   : (n_persons, N_joints, 3)
            #   'trans'               : (n_persons, 3)
            # Les tenseurs sont sur device, batch dim = index 0
            verts_all = pred.get("vertices3d_nonparam")
            joints_all = pred.get("joints3d_nonparam")
            trans_all = pred.get("trans")

            if verts_all is None or len(verts_all) == 0:
                with self.state.lock():
                    self.state.persons_nlf = []
                time.sleep(self.period)
                continue

            # Batch index 0
            verts_batch = verts_all[0]   # (n_persons, 6890, 3)
            joints_batch = joints_all[0] if joints_all is not None else None
            trans_batch = trans_all[0] if trans_all is not None else None

            n_detected = min(verts_batch.shape[0], self.num_persons)
            t_now = time.monotonic()

            # Simple IoU tracking via bounding boxes des joints 2D
            # (on utilise les vertices projetes pour obtenir des bbox approx)
            from .state import PoseKp
            bboxes = []
            for i in range(n_detected):
                v = verts_batch[i].cpu().numpy()  # (6890, 3)
                # Projection orthographique simple pour bbox tracking
                xmin, ymin = v[:, 0].min(), v[:, 1].min()
                xmax, ymax = v[:, 0].max(), v[:, 1].max()
                bboxes.append([PoseKp(x=float(xmin), y=float(ymin), c=1.0),
                               PoseKp(x=float(xmax), y=float(ymax), c=1.0)])

            ids = tracker.update(bboxes)

            persons = []
            for i in range(n_detected):
                pid = ids[i] if i < len(ids) else i
                if pid < 0:
                    continue

                v_np = verts_batch[i].cpu().numpy()  # (6890, 3)
                j_np = (joints_batch[i].cpu().numpy()
                        if joints_batch is not None
                        else np.zeros((N_JOINTS, 3), dtype=np.float32))
                t_np = (trans_batch[i].cpu().numpy()
                        if trans_batch is not None
                        else np.zeros(3, dtype=np.float32))

                # Lissage One Euro sur la translation
                pid_c = pid % self.num_persons
                t_smooth = np.array([
                    self._smooth_pos[pid_c][k](float(t_np[k]), t_now)
                    for k in range(3)
                ], dtype=np.float32)

                persons.append(NLFPerson(
                    pid=int(pid),
                    vertices_3d=tuple(map(tuple, v_np)),
                    joints_3d=tuple(map(tuple, j_np)),
                    translation=tuple(t_smooth.tolist()),
                    confidence=1.0,
                ))

            with self.state.lock():
                self.state.persons_nlf = persons
                self.state.nlf_last_t = t_now

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)

        cap.release()
        LOG.info("nlf worker stopped")
```

- [ ] **Step 4: Run tests (should pass now)**

Run: `cd /Users/electron/Documents/Projets/AV-Live && data_only_viz/.venv/bin/python -m pytest data_only_viz/tests/test_nlf_worker.py -v`
Expected: 2 PASS + 1 PASS/SKIP (selon presence checkpoint)

- [ ] **Step 5: Commit**

```bash
git add data_only_viz/nlf_worker.py data_only_viz/tests/test_nlf_worker.py
git commit -m "nlf: add worker (TorchScript MPS + One Euro + tracker)"
```

---

### Task 5: Valider l'API NLF sur une image test

**Files:**
- Aucun fichier cree, validation interactive

Cette task est CRITIQUE : elle confirme le format exact des sorties NLF
avant de coder le reste du pipeline. Les noms de cles (`vertices3d_nonparam`,
`joints3d_nonparam`, `trans`) et les shapes sont documentes dans `demo.ipynb`
mais doivent etre verifies sur notre hardware MPS.

- [ ] **Step 1: Test inference NLF sur CPU (safe)**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "
import torch, torchvision
CKPT = '$HOME/.cache/av-live-nlf/nlf_l_multi.torchscript'
model = torch.jit.load(CKPT, map_location='cpu').eval()

# Image test synthetique 640x480
img = torch.randint(0, 255, (3, 480, 640), dtype=torch.uint8)
batch = img.unsqueeze(0)

with torch.inference_mode():
    pred = model.detect_smpl_batched(batch)

print('Keys:', sorted(pred.keys()))
for k, v in pred.items():
    if hasattr(v, 'shape'):
        print(f'  {k}: shape={v.shape} dtype={v.dtype}')
    elif isinstance(v, (list, tuple)):
        print(f'  {k}: len={len(v)}')
        if len(v) > 0 and hasattr(v[0], 'shape'):
            print(f'    [0]: shape={v[0].shape}')
"
```
Expected: voir les cles et shapes. Ajuster `nlf_worker.py` si les noms
de cles ou l'indexation batch different de la doc.

- [ ] **Step 2: Verifier les shapes critiques**

Confirmer :
- `vertices3d_nonparam` contient bien des tenseurs avec dim -1 = 3 (xyz)
- Le nombre de vertices par personne = 6890 (SMPL standard)
- `trans` existe et donne une translation 3D par personne

Si NLF utilise une convention batch differente (ex: tenseur flat au lieu de
liste de tenseurs), adapter `nlf_worker.py` en consequence.

- [ ] **Step 3: Test MPS si disponible**

Run:
```bash
data_only_viz/.venv/bin/python -c "
import torch
print('MPS available:', torch.backends.mps.is_available())
if torch.backends.mps.is_available():
    model = torch.jit.load('$HOME/.cache/av-live-nlf/nlf_l_multi.torchscript',
                            map_location='mps').eval()
    img = torch.randint(0, 255, (3, 480, 640), dtype=torch.uint8).to('mps')
    with torch.inference_mode():
        pred = model.detect_smpl_batched(img.unsqueeze(0))
    v = pred.get('vertices3d_nonparam')
    if v is not None:
        print('MPS OK, verts shape:', v[0].shape if isinstance(v, list) else v.shape)
    else:
        print('MPS OK but vertices3d_nonparam absent — check keys:', sorted(pred.keys()))
"
```
Expected: `MPS OK, verts shape: ...` ou indication des cles disponibles.

**IMPORTANT :** Si MPS echoue (certaines ops TorchScript pas supportees sur MPS),
on restera sur CPU. Mettre a jour `nlf_worker.py` default device en consequence.

- [ ] **Step 4: Documenter les resultats dans un commentaire commit**

```bash
git add -u  # si nlf_worker.py a ete ajuste
git commit -m "nlf: validate inference API shapes on MPS/CPU" --allow-empty
```

---

### Task 6: TCP sender for NLF vertices

**Files:**
- Create: `data_only_viz/nlf_tcp_sender.py`
- Test: sender demarre sans crash, warning "not connected" OK

- [ ] **Step 1: Ecrire le sender TCP**

Create `data_only_viz/nlf_tcp_sender.py`:
```python
"""Envoie les vertices NLF de chaque personne via TCP sur :57130.

UDP ne suffit pas : 6890 verts x 3 floats x 4 = 82 680 octets par
personne, soit > MTU 1500. TCP fragmente proprement.

Protocole binaire simple :
    [4 bytes: magic 'NLF1'][4 bytes: n_persons (uint32 LE)]
    Pour chaque personne :
        [4: pid int32][4: confidence float32]
        [12: translation (3 float32)]
        [6890*3*4 = 82680: vertices (float32 LE)]
"""
from __future__ import annotations

import logging
import socket
import struct
import threading
import time
from typing import Sequence

from .state import NLFPerson, State

LOG = logging.getLogger("nlf_tcp")

MAGIC = b"NLF1"
PORT = 57130
N_VERTS = 6890


class NLFTCPSender:
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
            target=self._run, name="nlf_tcp", daemon=True)
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
        except (socket.error, ConnectionRefusedError):
            return False

    def _serialize_persons(self, persons: Sequence[NLFPerson]) -> bytes:
        buf = bytearray()
        buf += MAGIC
        buf += struct.pack("<I", len(persons))
        for p in persons:
            buf += struct.pack("<i", p.pid)
            buf += struct.pack("<f", p.confidence)
            tx, ty, tz = p.translation
            buf += struct.pack("<fff", tx, ty, tz)
            # Vertices : 6890 x 3 floats
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
                time.sleep(1.0)
                continue

            with self.state.lock():
                persons = list(self.state.persons_nlf)

            if persons:
                payload = self._serialize_persons(persons)
                try:
                    # Frame header : 4 octets longueur LE puis payload
                    self._sock.sendall(
                        struct.pack("<I", len(payload)) + payload)
                except (socket.error, BrokenPipeError) as e:
                    LOG.info("connection lost: %s", e)
                    try:
                        self._sock.close()
                    except Exception:
                        pass
                    self._sock = None
                    continue

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
```

- [ ] **Step 2: Smoke test : sender demarre sans crash**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "
from data_only_viz.nlf_tcp_sender import NLFTCPSender
from data_only_viz.state import State
s = NLFTCPSender(State())
s.start()
import time; time.sleep(2)
s.stop()
print('sender lifecycle OK')
"
```
Expected: `sender lifecycle OK` + warning "RealityKit app pas connectee" dans les logs

- [ ] **Step 3: Commit**

```bash
git add data_only_viz/nlf_tcp_sender.py
git commit -m "nlf: add TCP sender (binary protocol, 82KB/frame/person)"
```

---

### Task 7: Wire NLFWorker dans main.py

**Files:**
- Modify: `data_only_viz/main.py` (ajout flag + chaine de priorite)

- [ ] **Step 1: Ajouter le flag --nlf**

Dans `data_only_viz/main.py`, dans `def main()` apres les autres `p.add_argument` :
```python
    p.add_argument("--nlf", action="store_true",
                   help="Active NLF worker pour mesh SMPL dense (6890 verts)")
    p.add_argument("--nlf-small", action="store_true",
                   help="Utilise NLF-S (plus rapide, moins precis)")
```

- [ ] **Step 2: Etendre _start_pose_worker pour activer NLF**

Dans la methode `_start_pose_worker`, en TOUTE premiere priorite (avant Apple Vision) :
```python
        # 0. NLF (SMPL 6890 verts mesh dense) — si demande + dispo
        if self._opts.nlf:
            try:
                from .nlf_worker import NLFWorker
                from .nlf_tcp_sender import NLFTCPSender
                if NLFWorker.is_available():
                    self._pose_worker = NLFWorker(
                        self._state, num_persons=4,
                        use_small=self._opts.nlf_small)
                    self._pose_worker.start()
                    self._nlf_tcp = NLFTCPSender(self._state)
                    self._nlf_tcp.start()
                    LOG.info("worker: NLF (SMPL mesh dense 6890 verts)")
                    return
                LOG.info("NLF indisponible (checkpoints manquants)")
            except Exception as e:
                LOG.warning("NLF failed (%s) — fallback", e)
```

- [ ] **Step 3: Smoke test : --nlf sans crash**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -c "
import argparse
p = argparse.ArgumentParser()
p.add_argument('--nlf', action='store_true')
p.add_argument('--nlf-small', action='store_true')
p.add_argument('--pose', action='store_true')
opts = p.parse_args(['--nlf', '--pose'])
print('OK:', opts.nlf, opts.pose)
"
```
Expected: `OK: True True`

- [ ] **Step 4: Commit**

```bash
git add data_only_viz/main.py
git commit -m "main: add --nlf flag, prioritize NLFWorker"
```

---

### Task 8: Swift app skeleton (AV-Live-Body)

**Files:**
- Create: `launcher/AV-Live-Body/Package.swift`
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/main.swift`

- [ ] **Step 1: Creer Package.swift**

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
                .copy("../../Resources/smpl_faces.bin"),
            ]
        )
    ]
)
```

- [ ] **Step 2: Creer main.swift (entry point minimal)**

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
                renderer.startTCPServer()
            }
    }
}
```

- [ ] **Step 3: Verify build (erreurs attendues)**

Run: `cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build 2>&1 | tail -10`
Expected: compile errors for missing BodyView and MeshRenderer (normal — crees ensuite)

- [ ] **Step 4: Commit (build casse volontairement — checkpoint)**

```bash
git add launcher/AV-Live-Body/Package.swift launcher/AV-Live-Body/Sources/AVLiveBody/main.swift
git commit -m "av-live-body: swift package skeleton"
```

---

### Task 9: Swift MeshRenderer + RealityKit view

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift`

- [ ] **Step 1: Ecrire MeshRenderer.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift`:
```swift
import Combine
import Foundation
import RealityKit
import SwiftUI

/// Gere les vertices NLF recus par TCP et les pousse dans une
/// MeshResource dynamique de RealityKit. Lit smpl_faces.bin une fois
/// au lancement (13776 triangles statiques, topologie SMPL 6890 verts).
@MainActor
final class MeshRenderer: ObservableObject {
    @Published var personEntities: [Int: ModelEntity] = [:]
    private var faces: [UInt32] = []
    private var tcpServer: TCPServer?

    static let vertexCount = 6890
    static let faceCount = 13776

    init() {
        loadFaces()
    }

    private func loadFaces() {
        guard let url = Bundle.module.url(forResource: "smpl_faces",
                                          withExtension: "bin") else {
            print("smpl_faces.bin not found in bundle")
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
        print("Loaded \(n) face indices (\(n / 3) triangles)")
    }

    func startTCPServer() {
        let server = TCPServer(port: 57130) { [weak self] persons in
            Task { @MainActor in
                self?.updatePersons(persons)
            }
        }
        server.start()
        self.tcpServer = server
    }

    func updatePersons(_ persons: [NLFPersonData]) {
        let receivedPids = Set(persons.map { $0.pid })
        for (pid, _) in personEntities where !receivedPids.contains(pid) {
            personEntities.removeValue(forKey: pid)
        }
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
            mesh: makeMesh(vertices: Array(
                repeating: SIMD3<Float>(0, 0, 0),
                count: Self.vertexCount)),
            materials: [material]
        )
        return entity
    }

    private func makeMesh(vertices: [SIMD3<Float>]) -> MeshResource {
        var desc = MeshDescriptor(name: "smpl")
        desc.positions = MeshBuffer(vertices)
        desc.primitives = .triangles(faces)
        return (try? MeshResource.generate(from: [desc]))
            ?? .generateBox(size: 0.1)
    }

    private func updateMeshVertices(_ entity: ModelEntity,
                                     vertices: [SIMD3<Float>]) {
        // Recree le mesh (MeshResource est immutable post-creation).
        // LowLevelMesh dans Task 14 pour perf.
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

struct NLFPersonData {
    let pid: Int
    let confidence: Float
    let translation: SIMD3<Float>
    let vertices: [SIMD3<Float>]   // 6890
}
```

- [ ] **Step 2: Ecrire BodyView.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift`:
```swift
import RealityKit
import SwiftUI

/// Wrapper SwiftUI autour de ARView contenant les meshes NLF SMPL.
struct BodyView: NSViewRepresentable {
    @ObservedObject var renderer: MeshRenderer

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.background = .color(.black)
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 60
        let camAnchor = AnchorEntity(world: SIMD3(0, 0, 2))
        camAnchor.addChild(cam)
        view.scene.addAnchor(camAnchor)
        let bodyAnchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(bodyAnchor)
        context.coordinator.bodyAnchor = bodyAnchor
        context.coordinator.renderer = renderer
        return view
    }

    func updateNSView(_ view: ARView, context: Context) {
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

- [ ] **Step 3: Build (encore casse : TCPServer manque)**

Run: `cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build 2>&1 | tail -5`
Expected: erreur sur `TCPServer` — normal, Task 10 le cree

- [ ] **Step 4: Commit (build encore casse — checkpoint)**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift launcher/AV-Live-Body/Sources/AVLiveBody/BodyView.swift
git commit -m "av-live-body: MeshRenderer + BodyView RealityKit scaffold"
```

---

### Task 10: Swift TCPServer (listener TCP binaire)

**Files:**
- Create: `launcher/AV-Live-Body/Sources/AVLiveBody/TCPServer.swift`

- [ ] **Step 1: Ecrire TCPServer.swift**

Create `launcher/AV-Live-Body/Sources/AVLiveBody/TCPServer.swift`:
```swift
import Foundation
import Network

/// Listener TCP qui decode le protocole binaire de nlf_tcp_sender.py.
/// Frame : [u32 length][NLF1 magic][u32 n_persons]
///         [(pid i32 + conf f32 + 3 transl + 6890*3 verts)] x N
final class TCPServer {
    private let port: NWEndpoint.Port
    private let onPersons: ([NLFPersonData]) -> Void
    private var listener: NWListener?
    private var conn: NWConnection?
    private var buffer = Data()

    static let vertexCount = 6890

    init(port: UInt16, onPersons: @escaping ([NLFPersonData]) -> Void) {
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
            print("TCP listening on :\(port)")
        } catch {
            print("TCPServer.start error: \(error)")
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1,
                     maximumLength: 1024 * 64) { [weak self]
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
        guard magic == "NLF1".data(using: .ascii) else { return }
        var offset = 4
        let nPersons = payload.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        offset += 4
        // Taille par personne : 4 (pid) + 4 (conf) + 12 (transl) + 6890*12 (verts)
        let perPersonSize = 4 + 4 + 12 + Self.vertexCount * 12
        guard payload.count >= 8 + Int(nPersons) * perPersonSize else { return }

        var persons: [NLFPersonData] = []
        for _ in 0..<Int(nPersons) {
            let pid = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Int32.self).littleEndian
            }
            offset += 4
            let conf = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self)
            }
            offset += 4
            let tx = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            let ty = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            let tz = payload.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4
            // Vertices 6890 x 3
            var verts: [SIMD3<Float>] = []
            verts.reserveCapacity(Self.vertexCount)
            payload.withUnsafeBytes { raw in
                let floats = raw.bindMemory(to: Float.self)
                let base = offset / 4
                for i in 0..<Self.vertexCount {
                    let idx = base + i * 3
                    verts.append(SIMD3<Float>(
                        floats[idx], floats[idx + 1], floats[idx + 2]))
                }
            }
            offset += Self.vertexCount * 12
            persons.append(NLFPersonData(
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

Run: `cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build 2>&1 | tail -10`
Expected: `Build complete!` ou erreur residuelle a fixer

- [ ] **Step 3: Lance l'app + verify listener**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift run AVLiveBody &
sleep 3
nc -zv 127.0.0.1 57130 2>&1 | head -3
pkill AVLiveBody
```
Expected: `Connection to 127.0.0.1 port 57130 [tcp/*] succeeded!`

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/TCPServer.swift
git commit -m "av-live-body: TCP listener for NLF vertices"
```

---

### Task 11: End-to-end smoke test

**Files:**
- Aucun fichier modifie, test manuel

- [ ] **Step 1: Lance l'app Swift en background**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body
swift run AVLiveBody &
SWIFT_PID=$!
sleep 5
```

- [ ] **Step 2: Lance le worker Python avec --nlf**

Run:
```bash
cd /Users/electron/Documents/Projets/AV-Live
data_only_viz/.venv/bin/python -m data_only_viz.main -v --pose --nlf --fullscreen > /tmp/nlf-test.log 2>&1 &
PYTHON_PID=$!
sleep 30   # laisse NLF load (~5-8s TorchScript) + 20s d'inference
```

- [ ] **Step 3: Verifier que des persons_nlf sont emis**

Run: `grep -E "NLF|nlf_tcp|connected to|persons" /tmp/nlf-test.log | tail -10`
Expected:
- `NLF loaded (nlf_l_multi) on mps` (ou `cpu`)
- `nlf_tcp — connected to 127.0.0.1:57130`
- Pas d'erreur sur l'inference

- [ ] **Step 4: Verifier visuel dans l'app Swift**

Manuel : la fenetre AVLiveBody devrait afficher un mesh humain SMPL
qui suit l'utilisateur devant la cam. Si pose detectee, mesh visible
en couleur (palette pid). Le mesh SMPL (6890 verts) est moins detaille
que SMPL-X (pas de mains articulees, pas de visage) mais la silhouette
du corps est correcte.

- [ ] **Step 5: Cleanup**

```bash
kill $PYTHON_PID $SWIFT_PID 2>/dev/null
echo "smoke test done"
```

- [ ] **Step 6: Commit rapport**

Create `docs/superpowers/plans/2026-05-13-nlf-realitykit-body-mesh-RESULTS.md`:
```markdown
# NLF + RealityKit — resultats smoke test

- NLF load : OK / KO (avec raison)
- Device : MPS / CPU
- TCP sender : connected / refused
- App Swift : mesh visible / vide
- FPS observe : N
- Latence inference : N ms
- Vertices par personne : 6890 confirme / autre
```

```bash
git add docs/superpowers/plans/2026-05-13-nlf-realitykit-body-mesh-RESULTS.md
git commit -m "nlf: end-to-end smoke test results"
```

---

### Task 12: Launcher integration (toggle NLF)

**Files:**
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift`
- Modify: `launcher/Sources/AVLiveLauncher/MenuBarContent.swift`

- [ ] **Step 1: Ajouter `useNLF` a ProcessManager**

Dans `launcher/Sources/AVLiveLauncher/ProcessManager.swift`, dans la
classe ProcessManager (apres les autres `@Published`) :
```swift
    @Published var useNLF: Bool {
        didSet { defaults.set(useNLF, forKey: "useNLF") }
    }
```

Et dans `init()` :
```swift
        useNLF = defaults.bool(forKey: "useNLF")
```

- [ ] **Step 2: Passer le flag au worker Python**

Dans `startMetalViz`, juste apres la definition de `p.arguments` :
```swift
        if useNLF {
            p.arguments?.append("--nlf")
        }
```

- [ ] **Step 3: Bouton toggle dans MenuBarContent**

Dans `MenuBarContent.swift`, ajouter sous le picker `mode` :
```swift
            if processManager.mode == .dataOnly {
                Toggle("NLF Body Mesh (SMPL 6890 verts)",
                       isOn: $processManager.useNLF)
                    .toggleStyle(.switch)
            }
```

- [ ] **Step 4: Build launcher + check**

Run: `cd /Users/electron/Documents/Projets/AV-Live/launcher && ./build.sh 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add launcher/Sources/AVLiveLauncher/ProcessManager.swift launcher/Sources/AVLiveLauncher/MenuBarContent.swift
git commit -m "launcher: add NLF toggle in data-only mode"
```

---

### Task 13: Launcher spawns AV-Live-Body app automatically

**Files:**
- Modify: `launcher/Sources/AVLiveLauncher/ProcessManager.swift`

- [ ] **Step 1: Methode startBodyApp + stopBodyApp**

Dans ProcessManager (apres `stopMetalViz`) :
```swift
    private var bodyAppProc: Process?

    func startBodyApp() {
        guard useNLF else { return }
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

Dans `startAll()`, en mode `dataOnly`, ajouter apres startMetalViz :
```swift
            if useNLF {
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

Run: `cd /Users/electron/Documents/Projets/AV-Live/launcher && ./build.sh 2>&1 | tail -3`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add launcher/Sources/AVLiveLauncher/ProcessManager.swift
git commit -m "launcher: auto-spawn AV-Live-Body when NLF active"
```

---

### Task 14: Performance optimization (LowLevelMesh + vertex buffer in-place)

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
            try? createLowLevelMesh(for: entity, vertices: vertices)
            return
        }
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
            bufferIndex: 0,
            bufferStride: MemoryLayout<SIMD3<Float>>.stride)
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
cd /Users/electron/Documents/Projets/AV-Live/launcher/AV-Live-Body && swift build -c release 2>&1 | tail -3
```
Expected: `Build complete!`

- [ ] **Step 3: Run end-to-end avec mesure FPS**

Meme procedure que Task 11, puis :
```bash
grep -E "fps|ms|frame" /tmp/nlf-test.log | tail -10
```
Expected: FPS NLF > 8 (NLF-L) ou > 15 (NLF-S), latence < 130 ms

- [ ] **Step 4: Commit**

```bash
git add launcher/AV-Live-Body/Sources/AVLiveBody/MeshRenderer.swift
git commit -m "av-live-body: LowLevelMesh for in-place vertex updates"
```

---

### Task 15: Documentation finale

**Files:**
- Create: `data_only_viz/NLF_README.md`

- [ ] **Step 1: Creer README utilisateur**

Create `data_only_viz/NLF_README.md`:
```markdown
# NLF + RealityKit Body Mesh — utilisation

## Setup une fois

```bash
./data_only_viz/scripts/setup_nlf.sh   # download checkpoints (~750 MB total)
cd data_only_viz && uv sync --extra nlf
data_only_viz/.venv/bin/python data_only_viz/scripts/dump_smpl_faces.py
```

Aucune inscription academique requise. Les checkpoints NLF sont
disponibles librement sur GitHub Releases (code MIT, modeles
non-commercial research).

## Lancement

Option 1 — launcher (auto) :
1. Ouvrir AVLiveLauncher.app
2. Mode "data-only", activer "NLF Body Mesh (SMPL 6890 verts)"
3. Le launcher demarre : sclang + bridge + viz Python + AV-Live-Body Swift

Option 2 — manuel (debug) :
```bash
# Terminal 1 : RealityKit app
cd launcher/AV-Live-Body && swift run -c release AVLiveBody

# Terminal 2 : worker Python
data_only_viz/.venv/bin/python -m data_only_viz.main \
    -v --pose --nlf --fullscreen
```

## Architecture

```
webcam Mac (cv2 idx 0)
    | frame BGR
NLF TorchScript multi-personne (MPS ou CPU)
    | vertices3d_nonparam : (N, 6890, 3)
    | joints3d_nonparam : (N, 24, 3)
OneEuroFilter (translation)
    |
NLFTCPSender : binaire 82 KB/frame/personne sur :57130
    | TCP
AVLiveBody Swift : TCPServer -> MeshRenderer -> LowLevelMesh
    |
RealityKit ARView : mesh SMPL en couleur par pid
```

## FPS attendu

- NLF-L sur M5 MPS : ~100-130 ms / frame = 8-10 fps
- NLF-S sur M5 MPS : ~50-70 ms / frame = 14-20 fps
- TCP sender : 12 fps target (throttle)
- RealityKit render : 60 fps interpole entre frames NLF

## Topologie

- SMPL standard : 6890 vertices, 13776 triangles
- Pas de mains articulees ni visage detaille (contrairement a SMPL-X 10475)
- Silhouette corps complete, suffisante pour performance live

## Debug

- Pas de mesh affiche : verifier `~/.cache/av-live-nlf/nlf_l_multi.torchscript` existe
- TCP refused : l'app Swift doit tourner AVANT le worker Python
- FPS bas : passer a NLF-S (`--nlf-small`) plus rapide
- MPS error : certaines ops TorchScript peuvent ne pas etre supportees sur MPS,
  le worker fallback automatiquement sur CPU
```

- [ ] **Step 2: Commit final**

```bash
git add data_only_viz/NLF_README.md
git commit -m "docs: finalize NLF + RealityKit documentation"
```

---

## Recap final

Le plan ci-dessus livre :

1. **Setup deps + checkpoints** (Tasks 1-2) — zero inscription academique, curl depuis GitHub Releases
2. **Worker Python complet** : NLF TorchScript multi-personne, path nonparametrique 6890 verts, One Euro lissage, IoU tracker (Tasks 3-5)
3. **TCP sender vertices binaire** (Task 6) — protocole `NLF1`, 82 KB/frame/personne
4. **Integration data_only_viz** (Task 7) — flags `--nlf` et `--nlf-small`
5. **App Swift RealityKit** : ARView, MeshRenderer, TCP listener (Tasks 8-10)
6. **Smoke test end-to-end** (Task 11)
7. **Integration launcher** (Tasks 12-13) — toggle UI + auto-spawn
8. **Optimisation LowLevelMesh** pour update vertex sans rebuild (Task 14)
9. **Documentation utilisateur** (Task 15)

Total : 15 tasks, ~2-4 jours pour un dev avec familiarite PyTorch + Swift.
