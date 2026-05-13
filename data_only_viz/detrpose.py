"""DETRPose multi-personne — worker alternatif a MediaPipe Multi.

DETRPose (2025, S. Janampa) : premier transformer end-to-end temps reel
pour la detection de pose multi-personne. Sortie COCO 17 keypoints,
multi-personne nativement (queries DETR), entraine 5 a 10x plus vite
que ses concurrents grace a un denoising base sur OKS.

  - Paper   : https://arxiv.org/abs/2506.13027
  - Repo    : https://github.com/SebastianJanampa/DETRPose
  - Weights : https://github.com/SebastianJanampa/DETRPose/releases/tag/model_weights
  - Demo HF : https://huggingface.co/spaces/SebasJanampa/DETRPose

============================================================================
INSTALLATION (manuelle — DETRPose n'est PAS pip-installable)
============================================================================

Le repo n'a pas de setup.py / pyproject.toml — il faut le cloner et
l'ajouter au PYTHONPATH. Procedure :

    # 1. Cloner dans le cache utilisateur
    mkdir -p ~/.cache/av-live-detrpose
    cd ~/.cache/av-live-detrpose
    git clone https://github.com/SebastianJanampa/DETRPose.git

    # 2. Dependances Python (sans numpy<1.24 — on garde le numpy du venv)
    cd ~/Documents/Projets/AV-Live/data_only_viz
    uv pip install torch torchvision transformers omegaconf cloudpickle \
                   pycocotools xtcocotools scipy calflops iopath

    # 3. Telecharger un checkpoint (N = nano, ~16 MB, le plus rapide)
    cd ~/.cache/av-live-detrpose
    curl -L -o detrpose_hgnetv2_n.pth \
      https://github.com/SebastianJanampa/DETRPose/releases/download/model_weights/detrpose_hgnetv2_n.pth

Sinon, le worker logge une erreur claire et main.py retombe sur MediaPipe.

============================================================================
DEVICE
============================================================================

DETRPose s'appuie sur PyTorch standard — compatible MPS (Apple Silicon),
CUDA, CPU. Pas de couche custom CUDA-only. On essaie MPS en premier, on
retombe sur CPU si erreur. Inference ~30-50 ms sur M5 avec le modele N.

============================================================================
FORMAT DE SORTIE
============================================================================

COCO 17 keypoints, ordre standard :
  0: nose, 1-2: eyes, 3-4: ears, 5-6: shoulders, 7-8: elbows,
  9-10: wrists, 11-12: hips, 13-14: knees, 15-16: ankles.

Le state AV-Live attend `persons_body` = list[list[PoseKp]] ou chaque
PoseKp a x, y normalises 0..1. DETRPose ne fournit pas la profondeur z
(modele 2D pur) ni la visibilite par keypoint — on met z=0 et c=score
global de la personne.
"""
from __future__ import annotations

import logging
import os
import sys
import threading
import time
from pathlib import Path

from .state import PoseKp, State

LOG = logging.getLogger("detrpose")

CACHE_DIR = Path.home() / ".cache" / "av-live-detrpose"
REPO_DIR = CACHE_DIR / "DETRPose"
# Modele N (nano) par defaut : 16 MB, le plus rapide.
DEFAULT_MODEL_SIZE = "n"
_VALID_SIZES = {"n", "s", "l"}
DEFAULT_CKPT = CACHE_DIR / f"detrpose_hgnetv2_{DEFAULT_MODEL_SIZE}.pth"
DEFAULT_CONFIG_REL = f"configs/detrpose/detrpose_hgnetv2_{DEFAULT_MODEL_SIZE}.py"


def _check_install() -> tuple[bool, str]:
    """Verifie que le repo et le checkpoint sont presents. Renvoie (ok, msg)."""
    if not REPO_DIR.exists():
        return False, (
            f"DETRPose repo absent ({REPO_DIR}). Voir docstring du module "
            "pour la procedure d'install."
        )
    if not (REPO_DIR / DEFAULT_CONFIG_REL).exists():
        return False, f"config manquante : {REPO_DIR / DEFAULT_CONFIG_REL}"
    if not DEFAULT_CKPT.exists():
        return False, f"checkpoint manquant : {DEFAULT_CKPT}"
    return True, "ok"


def is_available() -> bool:
    """Test rapide : repo + checkpoint presents ET PyTorch importable."""
    ok, _ = _check_install()
    if not ok:
        return False
    try:
        import torch  # noqa: F401
    except ImportError:
        return False
    return True


class DETRPoseWorker:
    """Worker multi-personne DETRPose (body only, 17 keypoints COCO).

    Suit le meme contrat que MultiWorker : ecrit dans state.persons_body
    et state.last_webcam_jpeg, thread daemon, stop() propre.
    """

    def __init__(
        self,
        state: State,
        camera_index: int = 0,
        target_fps: float = 18.0,
        num_persons: int = 4,
        score_thresh: float = 0.5,
        model_size: str = DEFAULT_MODEL_SIZE,
        device: str = "auto",
    ) -> None:
        self.state = state
        self.camera_index = camera_index
        self.period = 1.0 / max(1.0, target_fps)
        self.num_persons = num_persons
        self.score_thresh = score_thresh
        self._configure_model_size(model_size)
        self.device_pref = device
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="detrpose", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _configure_model_size(self, size: str) -> None:
        """Validate and set model_size; raise ValueError for unknown sizes."""
        if size not in _VALID_SIZES:
            raise ValueError(
                f"DETRPose model_size must be one of {sorted(_VALID_SIZES)}, got {size!r}"
            )
        self.model_size = size

    # ------------------------------------------------------------------
    # Chargement modele : on importe le repo DETRPose en ajoutant son
    # dossier au sys.path, puis on suit le pattern de tools/inference/torch_inf.py.
    # ------------------------------------------------------------------
    def _load_model(self):
        ok, msg = _check_install()
        if not ok:
            raise RuntimeError(msg)
        if str(REPO_DIR) not in sys.path:
            sys.path.insert(0, str(REPO_DIR))
        # DETRPose utilise des chemins relatifs (configs/, src/) — il
        # faut chdir dans le repo pour que les imports config marchent.
        # On preserve le cwd appelant pour ne pas perturber le reste de l'app.
        prev_cwd = os.getcwd()
        try:
            os.chdir(REPO_DIR)
            import torch
            from omegaconf import OmegaConf
            # L'API d'instantiation hydra-like utilisee par DETRPose.
            try:
                from src.misc.lazy_config import instantiate  # type: ignore
            except ImportError:
                from src.core import instantiate  # type: ignore

            cfg_path = f"configs/detrpose/detrpose_hgnetv2_{self.model_size}.py"
            cfg = OmegaConf.load(cfg_path) if cfg_path.endswith(
                ".yaml") else _load_py_config(cfg_path)

            ckpt_path = CACHE_DIR / f"detrpose_hgnetv2_{self.model_size}.pth"
            ckpt = torch.load(ckpt_path, map_location="cpu")
            state_dict = ckpt.get("model") or ckpt.get("ema", {}).get(
                "module") or ckpt

            model = instantiate(cfg.model)
            model.load_state_dict(state_dict, strict=False)
            try:
                model = model.deploy()
            except AttributeError:
                pass
            model.eval()

            postprocessor = instantiate(cfg.postprocessor)
            try:
                postprocessor = postprocessor.deploy()
            except AttributeError:
                pass

            device = self._pick_device(torch)
            model = model.to(device)
            LOG.info("DETRPose %s charge sur %s", self.model_size, device)
            return model, postprocessor, device, torch
        finally:
            os.chdir(prev_cwd)

    def _pick_device(self, torch):
        pref = self.device_pref
        if pref == "auto":
            if torch.backends.mps.is_available():
                return torch.device("mps")
            if torch.cuda.is_available():
                return torch.device("cuda:0")
            return torch.device("cpu")
        if pref == "mps" and not torch.backends.mps.is_available():
            LOG.warning("MPS demande mais indisponible — fallback CPU")
            return torch.device("cpu")
        return torch.device(pref)

    def _run(self) -> None:
        try:
            import cv2
            import numpy as np
            import torch
        except ModuleNotFoundError as e:
            LOG.error("deps manquantes : %s", e)
            return

        try:
            model, postprocessor, device, _ = self._load_model()
        except Exception as e:  # noqa: BLE001
            LOG.error("chargement DETRPose echoue : %s", e)
            return

        cap = cv2.VideoCapture(self.camera_index)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        if not cap.isOpened():
            LOG.error("camera index %d indisponible", self.camera_index)
            return
        LOG.info("camera ouverte (index %d)", self.camera_index)

        # Tenseur d'input fixe 640x640 (cf torch_inf.py)
        INPUT_SIZE = 640
        mean = torch.tensor([0.485, 0.456, 0.406], device=device).view(1, 3, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225], device=device).view(1, 3, 1, 1)

        while not self._stop.is_set():
            tA = time.monotonic()
            ok, frame_bgr = cap.read()
            if not ok or frame_bgr is None:
                time.sleep(self.period)
                continue
            h, w = frame_bgr.shape[:2]
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)

            # Preprocess : resize 640x640, [0,1], NCHW, normalisation ImageNet
            img = cv2.resize(frame_rgb, (INPUT_SIZE, INPUT_SIZE))
            tens = torch.from_numpy(img).to(device).float().permute(2, 0, 1)
            tens = tens.unsqueeze(0) / 255.0
            tens = (tens - mean) / std
            orig_sizes = torch.tensor([[w, h]], device=device)

            try:
                with torch.no_grad():
                    outputs = model(tens)
                    scores, labels, keypoints = postprocessor(outputs, orig_sizes)
            except Exception as e:  # noqa: BLE001
                LOG.warning("inference: %s", e)
                time.sleep(self.period)
                continue

            # scores: (1, N), keypoints: (1, N, 17, 2) en pixels image originale
            scores0 = scores[0].detach().cpu().numpy()
            kps0 = keypoints[0].detach().cpu().numpy()
            idx = scores0 > self.score_thresh
            sel_scores = scores0[idx]
            sel_kps = kps0[idx]
            # Trier par score decroissant et limiter a num_persons
            order = (-sel_scores).argsort()[: self.num_persons]
            bodies: list[list[PoseKp]] = []
            for i in order:
                conf = float(sel_scores[i])
                pts = sel_kps[i]  # (17, 2) en pixels
                kp_list = []
                for kx, ky in pts:
                    kp_list.append(PoseKp(
                        x=float(kx) / max(1, w),
                        y=float(ky) / max(1, h),
                        z=0.0,
                        c=conf,
                    ))
                bodies.append(kp_list)

            # Encode webcam JPEG pour overlay
            ok2, jpg = cv2.imencode(".jpg", frame_bgr,
                                    [int(cv2.IMWRITE_JPEG_QUALITY), 70])
            jpg_bytes = bytes(jpg) if ok2 else None

            with self.state.lock():
                self.state.persons_body = bodies
                # DETRPose ne fournit pas face/hands — on vide pour
                # eviter que le renderer dessine des anciennes valeurs.
                self.state.persons_face = []
                self.state.persons_hands = []
                self.state.face_present = False
                self.state.hands_present = False
                if bodies:
                    self.state.body_present = True
                    # Compat single-person : on remplit les 17 premiers
                    # slots du buffer body_kp (mediapipe en attend 33,
                    # le reste reste a zero — acceptable).
                    for k in range(33):
                        if k < 17 and k < len(bodies[0]):
                            self.state.body_kp[k] = bodies[0][k]
                        else:
                            self.state.body_kp[k] = PoseKp()
                    # On remplit aussi pose_kp[17] (legacy YOLO COCO).
                    for k in range(17):
                        self.state.pose_kp[k] = (
                            bodies[0][k] if k < len(bodies[0]) else PoseKp())
                else:
                    self.state.body_present = False
                self.state.pose_count = len(bodies)
                self.state.pose_last_t = time.monotonic()
                if jpg_bytes:
                    self.state.last_webcam_jpeg = jpg_bytes

            dt = time.monotonic() - tA
            if dt < self.period:
                time.sleep(self.period - dt)
        cap.release()
        LOG.info("detrpose worker stopped")


def _load_py_config(path: str):
    """Charge une config DETRPose ecrite en .py (style detectron2/lazy)."""
    from omegaconf import OmegaConf
    # Les configs DETRPose sont des fichiers Python qui exposent un dict
    # `model = LazyCall(...)`. On utilise le helper lazy_config si dispo.
    try:
        from src.misc.lazy_config import LazyConfig  # type: ignore
        return LazyConfig.load(path)
    except ImportError:
        pass
    # Fallback minimal : exec + recup des noms cles.
    ns: dict = {}
    with open(path) as f:
        code = compile(f.read(), path, "exec")
    exec(code, ns)
    cfg = OmegaConf.create({
        k: ns[k] for k in ("model", "postprocessor")
        if k in ns
    })
    return cfg
