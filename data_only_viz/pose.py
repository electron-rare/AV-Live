"""Webcam + YOLOv8-pose integre au visualizer Metal.

Pourquoi ici plutot que dans data_feeds/feeds/pose.py :
  - Un seul process = une seule webcam (macOS interdit la double ouverture)
  - GPU partage : inference MPS et rendu Metal sur le meme device
  - TCC : si data_only_viz est lance par le launcher bundle, le subprocess
    Python herite (au moins une fois) du contexte camera autorise.

Met a jour directement state.pose_kp[17] sous lock. Le shader Metal lit
ces valeurs a chaque frame via renderer._update_skeleton.
"""
from __future__ import annotations

import logging
import threading
import time

from .state import PoseKp, State

LOG = logging.getLogger("pose")


class PoseWorker:
    """Thread daemon de capture + inference."""

    def __init__(
        self,
        state: State,
        model_name: str = "yolov8n-pose.pt",
        device: str = "mps",
        camera_index: int = 0,
        target_fps: float = 20.0,
        conf_thresh: float = 0.35,
        max_persons: int = 4,
    ) -> None:
        self.state = state
        self.model_name = model_name
        self.device = device
        self.camera_index = camera_index
        self.period = 1.0 / max(1.0, target_fps)
        self.conf_thresh = conf_thresh
        self.max_persons = max_persons
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="pose", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        try:
            import cv2
            import numpy as np
            from ultralytics import YOLO
        except ModuleNotFoundError as e:
            LOG.error("dependances manquantes : %s — uv sync --extra pose", e)
            return

        LOG.info("loading %s on %s", self.model_name, self.device)
        try:
            model = YOLO(self.model_name)
        except Exception as e:  # noqa: BLE001
            LOG.error("YOLO load failed: %s", e)
            return

        cap = cv2.VideoCapture(self.camera_index)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        if not cap.isOpened():
            LOG.error("camera index %d indisponible (TCC ?)", self.camera_index)
            return
        LOG.info("camera ouverte (index %d)", self.camera_index)

        while not self._stop.is_set():
            t0 = time.monotonic()
            ok, frame = cap.read()
            if not ok or frame is None:
                time.sleep(self.period)
                continue
            h, w = frame.shape[:2]
            try:
                results = model.predict(
                    frame, device=self.device, conf=self.conf_thresh,
                    verbose=False, max_det=self.max_persons,
                )
            except Exception as e:  # noqa: BLE001
                LOG.warning("inference failed: %s", e)
                time.sleep(self.period)
                continue
            if not results:
                with self.state.lock():
                    self.state.pose_count = 0
                    self.state.pose_last_t = time.monotonic()
                time.sleep(self.period)
                continue

            res = results[0]
            kp_xy = getattr(res.keypoints, "xy", None)
            kp_conf = getattr(res.keypoints, "conf", None)
            n = 0 if kp_xy is None else int(len(kp_xy))
            if n == 0:
                with self.state.lock():
                    self.state.pose_count = 0
                    self.state.pose_last_t = time.monotonic()
                time.sleep(self.period)
                continue

            # On suit le sujet 0 pour le squelette overlay (cf renderer).
            pts = kp_xy[0].cpu().numpy()
            cfs = (kp_conf[0].cpu().numpy() if kp_conf is not None
                   else np.ones(len(pts), dtype=float))
            # Encode la frame en JPEG (qualite 70, ~30 ko) pour l'affichage
            # NSImageView. Cheaper que d'envoyer du raw a Metal et marche
            # peu importe le viz mode actif.
            ok2, jpg = cv2.imencode(".jpg", frame,
                                    [int(cv2.IMWRITE_JPEG_QUALITY), 70])
            jpg_bytes = bytes(jpg) if ok2 else None
            with self.state.lock():
                self.state.pose_count = n
                for k in range(min(17, len(pts))):
                    x, y = pts[k]
                    self.state.pose_kp[k] = PoseKp(
                        x=float(x) / max(1.0, w),
                        y=float(y) / max(1.0, h),
                        c=float(cfs[k]),
                    )
                self.state.pose_last_t = time.monotonic()
                if jpg_bytes:
                    self.state.last_webcam_jpeg = jpg_bytes

            # cadence cible
            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
        cap.release()
        LOG.info("pose worker stopped")
