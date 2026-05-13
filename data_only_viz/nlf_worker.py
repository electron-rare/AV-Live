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

        if self.device == "mps" and not torch.backends.mps.is_available():
            LOG.warning("MPS unavailable, falling back to cpu")
            device = "cpu"
        else:
            device = self.device

        if not self.ckpt_path.exists():
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

        from .euro_filter import OneEuroFilter
        from .tracker import IoUTracker
        from .state import PoseKp
        self._smooth_pos = [
            [OneEuroFilter(0.8, 0.05) for _ in range(3)]
            for _ in range(self.num_persons)
        ]
        tracker = IoUTracker(iou_threshold=0.20, max_miss=8)

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

            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            tensor = torch.from_numpy(frame_rgb).permute(2, 0, 1)
            frame_batch = tensor.unsqueeze(0).to(device)

            try:
                with torch.inference_mode():
                    pred = model.detect_smpl_batched(frame_batch)
            except Exception as e:
                LOG.warning("inference failed: %s", e)
                time.sleep(self.period)
                continue

            verts_all = pred.get("vertices3d_nonparam")
            joints_all = pred.get("joints3d_nonparam")
            trans_all = pred.get("trans")

            if verts_all is None or len(verts_all) == 0:
                with self.state.lock():
                    self.state.persons_nlf = []
                time.sleep(self.period)
                continue

            verts_batch = verts_all[0]
            joints_batch = joints_all[0] if joints_all is not None else None
            trans_batch = trans_all[0] if trans_all is not None else None

            n_detected = min(verts_batch.shape[0], self.num_persons)
            t_now = time.monotonic()

            bboxes = []
            for i in range(n_detected):
                v = verts_batch[i].cpu().numpy()
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

                v_np = verts_batch[i].cpu().numpy()
                j_np = (joints_batch[i].cpu().numpy()
                        if joints_batch is not None
                        else np.zeros((N_JOINTS, 3), dtype=np.float32))
                t_np = (trans_batch[i].cpu().numpy()
                        if trans_batch is not None
                        else np.zeros(3, dtype=np.float32))

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
