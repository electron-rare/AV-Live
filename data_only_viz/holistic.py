"""MediaPipe Holistic : capture webcam + landmarks corps/visage/mains.

Remplace pose.py (YOLO 17 kp) par mediapipe.tasks.HolisticLandmarker :
  - 33 points POSE_LANDMARKS    (body skeleton)
  - 478 points FACE_LANDMARKS   (mesh visage + iris)
  - 21 × 2 HAND_LANDMARKS       (mains droite + gauche)
Total ~553 landmarks, ~230 segments de connexion.

Le modele .task est telecharge dans ~/.cache/mediapipe au premier run.
"""
from __future__ import annotations

import logging
import os
import threading
import time
import urllib.request
from pathlib import Path

from .state import PoseKp, State

LOG = logging.getLogger("holistic")

MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "holistic_landmarker/holistic_landmarker/float16/latest/"
    "holistic_landmarker.task"
)
CACHE_DIR = Path.home() / ".cache" / "av-live-mediapipe"
MODEL_PATH = CACHE_DIR / "holistic_landmarker.task"


def _ensure_model() -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if MODEL_PATH.exists() and MODEL_PATH.stat().st_size > 1_000_000:
        return MODEL_PATH
    LOG.info("downloading holistic model (%s) -> %s", MODEL_URL, MODEL_PATH)
    urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    LOG.info("download OK (%d bytes)", MODEL_PATH.stat().st_size)
    return MODEL_PATH


class HolisticWorker:
    """Thread de capture webcam + inference MediaPipe Holistic."""

    def __init__(
        self,
        state: State,
        camera_index: int = 0,
        target_fps: float = 20.0,
        min_pose_conf: float = 0.5,
        min_face_conf: float = 0.5,
        min_hand_conf: float = 0.4,
    ) -> None:
        self.state = state
        self.camera_index = camera_index
        self.period = 1.0 / max(1.0, target_fps)
        self.min_pose_conf = min_pose_conf
        self.min_face_conf = min_face_conf
        self.min_hand_conf = min_hand_conf
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="holistic", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        try:
            import cv2
            import numpy as np
            import mediapipe as mp
            from mediapipe.tasks.python import BaseOptions
            from mediapipe.tasks.python.vision import (
                HolisticLandmarker, HolisticLandmarkerOptions, RunningMode,
            )
        except ModuleNotFoundError as e:
            LOG.error("dependances manquantes : %s — uv sync --extra pose", e)
            return

        try:
            model_path = _ensure_model()
        except Exception as e:  # noqa: BLE001
            LOG.error("download model failed: %s", e)
            return

        opts = HolisticLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(model_path)),
            running_mode=RunningMode.VIDEO,
            min_pose_detection_confidence=self.min_pose_conf,
            min_pose_landmarks_confidence=self.min_pose_conf,
            min_pose_suppression_threshold=0.5,
            min_face_detection_confidence=self.min_face_conf,
            min_face_landmarks_confidence=self.min_face_conf,
            min_face_suppression_threshold=0.3,
            min_hand_landmarks_confidence=self.min_hand_conf,
        )
        landmarker = HolisticLandmarker.create_from_options(opts)
        LOG.info("HolisticLandmarker pret")

        cap = cv2.VideoCapture(self.camera_index)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        if not cap.isOpened():
            LOG.error("camera index %d indisponible (TCC ?)", self.camera_index)
            return
        LOG.info("camera ouverte (index %d)", self.camera_index)

        t0_ms = int(time.monotonic() * 1000)
        while not self._stop.is_set():
            tA = time.monotonic()
            ok, frame_bgr = cap.read()
            if not ok or frame_bgr is None:
                time.sleep(self.period)
                continue
            h, w = frame_bgr.shape[:2]
            # MediaPipe attend RGB
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
            ts_ms = int(time.monotonic() * 1000) - t0_ms
            try:
                result = landmarker.detect_for_video(mp_img, ts_ms)
            except Exception as e:  # noqa: BLE001
                LOG.warning("inference: %s", e)
                time.sleep(self.period)
                continue

            # Encode JPEG pour le NSImageView fond
            ok2, jpg = cv2.imencode(".jpg", frame_bgr,
                                    [int(cv2.IMWRITE_JPEG_QUALITY), 70])
            jpg_bytes = bytes(jpg) if ok2 else None

            with self.state.lock():
                # CORPS (33) — liste plate de NormalizedLandmark
                body = result.pose_landmarks or []
                self.state.body_present = len(body) > 0
                for k, lm in enumerate(body[:33]):
                    v = lm.visibility if lm.visibility is not None else 1.0
                    self.state.body_kp[k] = PoseKp(
                        x=float(lm.x), y=float(lm.y), c=float(v))

                # VISAGE (478)
                face = result.face_landmarks or []
                self.state.face_present = len(face) > 0
                for k, lm in enumerate(face[:478]):
                    self.state.face_kp[k] = PoseKp(
                        x=float(lm.x), y=float(lm.y), c=1.0)

                # MAINS (21 + 21)
                lh = result.left_hand_landmarks or []
                rh = result.right_hand_landmarks or []
                for k, lm in enumerate(lh[:21]):
                    self.state.left_hand_kp[k] = PoseKp(
                        x=float(lm.x), y=float(lm.y), c=1.0)
                for k, lm in enumerate(rh[:21]):
                    self.state.right_hand_kp[k] = PoseKp(
                        x=float(lm.x), y=float(lm.y), c=1.0)
                self.state.hands_present = bool(lh) or bool(rh)

                # Compatibilite : on remplit pose_count + pose_last_t
                self.state.pose_count = int(bool(body))
                self.state.pose_last_t = time.monotonic()
                if jpg_bytes:
                    self.state.last_webcam_jpeg = jpg_bytes

            dt = time.monotonic() - tA
            if dt < self.period:
                time.sleep(self.period - dt)
        cap.release()
        landmarker.close()
        LOG.info("holistic worker stopped")
