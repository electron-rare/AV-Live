"""Multi-personne : Pose+Face+Hand Landmarkers MediaPipe en parallele.

HolisticLandmarker est MONO-personne (par design). Pour multi-personnes
on utilise les 3 landmarkers spécialisés qui supportent `num_X=N` :
  - PoseLandmarker(num_poses=4)
  - FaceLandmarker(num_faces=4)
  - HandLandmarker(num_hands=8)   (jusqu'a 4 personnes × 2 mains)

Chaque inference tourne sur la MEME frame webcam. Les resultats sont
stockes independamment dans state.persons_body / persons_face /
persons_hands. Le renderer dessine TOUS les segments de toutes les
personnes, sans matching inter-modeles (acceptable visuellement).
"""
from __future__ import annotations

import logging
import threading
import time
import urllib.request
from pathlib import Path

from .euro_filter import SkeletonFilter
from .pose_bridge import PoseSoundBridge
from .state import PoseKp, State
from .tracker import IoUTracker

LOG = logging.getLogger("multi")

MODELS = {
    "pose": (
        "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
        "pose_landmarker_lite/float16/latest/pose_landmarker_lite.task"
    ),
    "face": (
        "https://storage.googleapis.com/mediapipe-models/face_landmarker/"
        "face_landmarker/float16/latest/face_landmarker.task"
    ),
    "hand": (
        "https://storage.googleapis.com/mediapipe-models/hand_landmarker/"
        "hand_landmarker/float16/latest/hand_landmarker.task"
    ),
}
CACHE_DIR = Path.home() / ".cache" / "av-live-mediapipe"


def _smooth_kps(skf: SkeletonFilter, pid: int, kps: list, t: float) -> list:
    """Applique le One Euro filter sur chaque keypoint d'une personne."""
    if pid < 0:
        return kps  # detection orpheline (sans track), pas de lissage
    out = []
    for k, kp in enumerate(kps):
        sx, sy, sz = skf.smooth(pid, k, kp.x, kp.y, kp.z, t)
        out.append(PoseKp(x=sx, y=sy, z=sz, c=kp.c))
    return out


def _ensure_model(name: str) -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{name}_landmarker.task"
    if path.exists() and path.stat().st_size > 100_000:
        return path
    LOG.info("downloading %s model ...", name)
    urllib.request.urlretrieve(MODELS[name], path)
    LOG.info("%s OK (%d bytes)", name, path.stat().st_size)
    return path


class MultiWorker:
    """Worker multi-personne (pose + face + hands landmarkers paralleles)."""

    def __init__(
        self,
        state: State,
        camera_index: int = 0,
        target_fps: float = 18.0,
        num_persons: int = 4,
        min_conf: float = 0.4,
    ) -> None:
        self.state = state
        self.camera_index = camera_index
        self.period = 1.0 / max(1.0, target_fps)
        self.num_persons = num_persons
        self.min_conf = min_conf
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        # Lissage + tracking pour stabiliser les keypoints frame a frame
        # et garder des IDs de couleur persistants entre frames.
        self._tracker_body = IoUTracker(iou_threshold=0.20, max_miss=10)
        self._tracker_face = IoUTracker(iou_threshold=0.15, max_miss=10)
        self._tracker_hand = IoUTracker(iou_threshold=0.10, max_miss=6)
        self._smooth_body = SkeletonFilter(min_cutoff=1.2, beta=0.06)
        self._smooth_face = SkeletonFilter(min_cutoff=1.8, beta=0.04)
        self._smooth_hand = SkeletonFilter(min_cutoff=2.0, beta=0.10)
        # Pont OSC pose -> sclang
        self._sound_bridge = PoseSoundBridge(throttle_hz=30.0)

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="multi", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        try:
            import cv2
            import mediapipe as mp
            from mediapipe.tasks.python import BaseOptions
            from mediapipe.tasks.python.vision import (
                PoseLandmarker, PoseLandmarkerOptions,
                FaceLandmarker, FaceLandmarkerOptions,
                HandLandmarker, HandLandmarkerOptions,
                RunningMode,
            )
        except ModuleNotFoundError as e:
            LOG.error("deps manquantes : %s — uv sync --extra pose", e)
            return

        try:
            pose_p = _ensure_model("pose")
            face_p = _ensure_model("face")
            hand_p = _ensure_model("hand")
        except Exception as e:  # noqa: BLE001
            LOG.error("download models failed: %s", e)
            return

        pose = PoseLandmarker.create_from_options(PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(pose_p)),
            running_mode=RunningMode.VIDEO,
            num_poses=self.num_persons,
            min_pose_detection_confidence=self.min_conf,
            min_pose_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        face = FaceLandmarker.create_from_options(FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(face_p)),
            running_mode=RunningMode.VIDEO,
            num_faces=self.num_persons,
            min_face_detection_confidence=self.min_conf,
            min_face_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        hand = HandLandmarker.create_from_options(HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(hand_p)),
            running_mode=RunningMode.VIDEO,
            num_hands=self.num_persons * 2,
            min_hand_detection_confidence=self.min_conf,
            min_hand_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        LOG.info("3 landmarkers prets (num=%d)", self.num_persons)

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
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
            ts = int(time.monotonic() * 1000) - t0_ms
            try:
                pose_res = pose.detect_for_video(mp_img, ts)
                face_res = face.detect_for_video(mp_img, ts)
                hand_res = hand.detect_for_video(mp_img, ts)
            except Exception as e:  # noqa: BLE001
                LOG.warning("inference: %s", e)
                time.sleep(self.period)
                continue

            # Encode webcam JPEG pour overlay
            ok2, jpg = cv2.imencode(".jpg", frame_bgr,
                                    [int(cv2.IMWRITE_JPEG_QUALITY), 70])
            jpg_bytes = bytes(jpg) if ok2 else None

            # Bodies : x/y normalises (image) + z (relative depth, NormalizedLandmark
            # fournit aussi z, plus precis que rien). pose_world_landmarks
            # donnerait des metres mais on garde un repere coherent avec face/hands.
            bodies = []
            pose_list = pose_res.pose_landmarks or []
            for landmarks_list in pose_list:
                kp_list = []
                for lm in landmarks_list[:33]:
                    v = lm.visibility if lm.visibility is not None else 1.0
                    z = float(lm.z) if lm.z is not None else 0.0
                    kp_list.append(PoseKp(
                        x=float(lm.x), y=float(lm.y), z=z, c=float(v)))
                bodies.append(kp_list)

            faces = []
            for landmarks_list in (face_res.face_landmarks or []):
                kp_list = []
                for lm in landmarks_list[:478]:
                    z = float(lm.z) if lm.z is not None else 0.0
                    kp_list.append(PoseKp(
                        x=float(lm.x), y=float(lm.y), z=z, c=1.0))
                faces.append(kp_list)

            hands = []
            for landmarks_list in (hand_res.hand_landmarks or []):
                kp_list = []
                for lm in landmarks_list[:21]:
                    z = float(lm.z) if lm.z is not None else 0.0
                    kp_list.append(PoseKp(
                        x=float(lm.x), y=float(lm.y), z=z, c=1.0))
                hands.append(kp_list)

            # --- Tracking IDs persistants entre frames -----------------
            ids_body = self._tracker_body.update(bodies)
            ids_face = self._tracker_face.update(faces)
            ids_hand = self._tracker_hand.update(hands)
            # --- Lissage One Euro par keypoint -------------------------
            t_now = time.monotonic()
            bodies = [_smooth_kps(self._smooth_body, ids_body[i], kps, t_now)
                      for i, kps in enumerate(bodies)]
            faces  = [_smooth_kps(self._smooth_face, ids_face[i], kps, t_now)
                      for i, kps in enumerate(faces)]
            hands  = [_smooth_kps(self._smooth_hand, ids_hand[i], kps, t_now)
                      for i, kps in enumerate(hands)]

            # Pont sonore : envoi OSC /pose/* a sclang (body + face + hands)
            self._sound_bridge.send(
                bodies, ids_body, t_now,
                persons_face=faces, persons_face_ids=ids_face,
                persons_hands=hands, persons_hands_ids=ids_hand)

            with self.state.lock():
                self.state.persons_body = bodies
                self.state.persons_face = faces
                self.state.persons_hands = hands
                self.state.persons_body_ids  = ids_body
                self.state.persons_face_ids  = ids_face
                self.state.persons_hands_ids = ids_hand
                # Compat single-person (1ere personne)
                if bodies:
                    self.state.body_present = True
                    for k in range(33):
                        self.state.body_kp[k] = bodies[0][k] if k < len(bodies[0]) else PoseKp()
                else:
                    self.state.body_present = False
                if faces:
                    self.state.face_present = True
                    for k in range(478):
                        self.state.face_kp[k] = faces[0][k] if k < len(faces[0]) else PoseKp()
                else:
                    self.state.face_present = False
                self.state.hands_present = bool(hands)
                self.state.pose_count = len(bodies)
                self.state.pose_last_t = time.monotonic()
                if jpg_bytes:
                    self.state.last_webcam_jpeg = jpg_bytes

            dt = time.monotonic() - tA
            if dt < self.period:
                time.sleep(self.period - dt)
        cap.release()
        pose.close(); face.close(); hand.close()
        LOG.info("multi worker stopped")
