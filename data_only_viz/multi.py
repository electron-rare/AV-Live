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

from .action_head_pub import ActionHeadPublisher
from .euro_filter import SkeletonFilter
from .pose_bridge import PoseSoundBridge
from .pose_filter import PoseFilterChain
from .pose_filter import _is_finite  # noqa: PLC2701  (intentional internal use)
from .state import Kp3D, PoseKp, State
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
        self._action_pub = ActionHeadPublisher(state=self.state, bridge=self._sound_bridge)
        self._action_pub.start()
        # 3D pose filter chain : median, Kalman CV, lookahead, IK clamps.
        self._filter_chain = PoseFilterChain(state=self.state)
        # Discrimination state : per-pid frame counters for hysteresis.
        # _pid_lifetime : frames since pid created (visible).
        # _pid_last_bbox : last bbox seen for active pid (for re-association).
        # _pid_missing : frames since pid disappeared (None when active).
        self._pid_lifetime: dict[int, int] = {}
        self._pid_missing: dict[int, int] = {}
        self._pid_last_bbox: dict[int, tuple[float, float, float, float]] = {}
        # Discrimination thresholds — tunable via env.
        import os as _os
        self._ghost_min_visible = int(_os.environ.get("POSE_GHOST_MIN_VISIBLE", "10"))
        self._ghost_min_conf = float(_os.environ.get("POSE_GHOST_MIN_CONF", "0.5"))
        self._hand_min_visible = int(_os.environ.get("POSE_HAND_MIN_VISIBLE", "15"))
        self._face_min_visible = int(_os.environ.get("POSE_FACE_MIN_VISIBLE", "50"))
        self._nms_iou = float(_os.environ.get("POSE_NMS_IOU", "0.7"))
        # Counters exposed for debug.
        self._n_ghost_dropped = 0
        self._n_hand_dropped = 0
        self._n_face_dropped = 0

    # ------------------------------------------------------------------
    # Discrimination helpers — body ghost rejection, NMS, pid hysteresis,
    # face/hand visibility gates. All return filtered (kps, ids) lists.
    # ------------------------------------------------------------------
    @staticmethod
    def _bbox_from_kps(kps: list) -> tuple[float, float, float, float]:
        if not kps:
            return (0.0, 0.0, 0.0, 0.0)
        xs = [kp.x for kp in kps]
        ys = [kp.y for kp in kps]
        return (min(xs), min(ys), max(xs), max(ys))

    @staticmethod
    def _iou(a: tuple[float, float, float, float],
             b: tuple[float, float, float, float]) -> float:
        ix1 = max(a[0], b[0]); iy1 = max(a[1], b[1])
        ix2 = min(a[2], b[2]); iy2 = min(a[3], b[3])
        iw = max(0.0, ix2 - ix1); ih = max(0.0, iy2 - iy1)
        inter = iw * ih
        aw = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1])
        bw = max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])
        u = aw + bw - inter
        return inter / u if u > 1e-9 else 0.0

    def _reject_ghosts_and_nms(
        self,
        bodies: list[list],
        bodies3d: list[list[Kp3D]],
        ids_body: list[int],
    ) -> tuple[list[list], list[list[Kp3D]], list[int]]:
        """Drop body detections with <N high-confidence joints, then NMS."""
        if not bodies:
            return bodies, bodies3d, ids_body
        # Score each body by mean confidence ; track visibility count.
        keep_mask = [True] * len(bodies)
        scores: list[float] = []
        for i, kps in enumerate(bodies):
            n_visible = sum(
                1 for kp in kps
                if kp.c >= self._ghost_min_conf
                and _is_finite(kp.x) and _is_finite(kp.y))
            if n_visible < self._ghost_min_visible:
                keep_mask[i] = False
                self._n_ghost_dropped += 1
            scores.append(
                sum(kp.c for kp in kps) / len(kps) if kps else 0.0)
        # NMS on remaining bboxes.
        bboxes = [self._bbox_from_kps(kps) for kps in bodies]
        order = sorted(
            [i for i in range(len(bodies)) if keep_mask[i]],
            key=lambda i: -scores[i])
        kept_order: list[int] = []
        for i in order:
            drop = False
            for j in kept_order:
                if self._iou(bboxes[i], bboxes[j]) > self._nms_iou:
                    drop = True
                    break
            if drop:
                keep_mask[i] = False
            else:
                kept_order.append(i)
        new_bodies = [bodies[i] for i in range(len(bodies)) if keep_mask[i]]
        new_ids = [ids_body[i] for i in range(len(bodies))
                   if i < len(ids_body) and keep_mask[i]]
        # bodies3d aligned 1:1 with bodies.
        new_b3d: list[list[Kp3D]] = []
        if bodies3d:
            for i in range(min(len(bodies), len(bodies3d))):
                if keep_mask[i]:
                    new_b3d.append(bodies3d[i])
        return new_bodies, new_b3d, new_ids

    def _apply_pid_hysteresis(
        self,
        bodies: list[list],
        ids_body: list[int],
    ) -> list[int]:
        """Reuse a recently-disappeared pid when a young pid lands near
        its last bbox. Mutates self._pid_lifetime / _pid_missing /
        _pid_last_bbox in place. Returns possibly-remapped ids.
        """
        # Tick all known pids missing counter ; will reset for visible ones.
        for pid in list(self._pid_missing.keys()):
            self._pid_missing[pid] += 1
            if self._pid_missing[pid] > 60:  # forget after 2 s @30 fps
                self._pid_missing.pop(pid, None)
                self._pid_last_bbox.pop(pid, None)
                self._pid_lifetime.pop(pid, None)
        new_ids = list(ids_body)
        for i, pid in enumerate(ids_body):
            if pid < 0 or i >= len(bodies):
                continue
            bbox_i = self._bbox_from_kps(bodies[i])
            # If this pid is brand new (<10 frames) and we have an absent
            # older pid (>=30 frames lifetime, <30 frames missing) with a
            # close bbox, remap.
            age = self._pid_lifetime.get(pid, 0)
            if age < 10:
                best_old: int | None = None
                best_iou = 0.0
                for old_pid, miss in self._pid_missing.items():
                    if old_pid == pid:
                        continue
                    if self._pid_lifetime.get(old_pid, 0) < 30:
                        continue
                    if miss > 30:
                        continue
                    old_bbox = self._pid_last_bbox.get(old_pid)
                    if old_bbox is None:
                        continue
                    iou = self._iou(bbox_i, old_bbox)
                    if iou > 0.3 and iou > best_iou:
                        best_iou = iou
                        best_old = old_pid
                if best_old is not None:
                    new_ids[i] = best_old
                    pid = best_old
            # Bookkeeping for visible pid.
            self._pid_lifetime[pid] = self._pid_lifetime.get(pid, 0) + 1
            self._pid_missing.pop(pid, None)
            self._pid_last_bbox[pid] = bbox_i
        # Pids previously visible but absent this frame -> mark missing.
        visible = set(new_ids)
        for pid in list(self._pid_lifetime.keys()):
            if pid not in visible and pid not in self._pid_missing:
                self._pid_missing[pid] = 1
        return new_ids

    def _drop_low_visibility(
        self,
        kps_list: list[list],
        ids: list[int],
        min_visible: int,
        which: str,
    ) -> tuple[list[list], list[int]]:
        out_kps: list[list] = []
        out_ids: list[int] = []
        for i, kps in enumerate(kps_list):
            n_ok = sum(
                1 for kp in kps
                if _is_finite(kp.x) and _is_finite(kp.y)
                and (kp.x != 0.0 or kp.y != 0.0))
            if n_ok < min_visible:
                if which == "face":
                    self._n_face_dropped += 1
                else:
                    self._n_hand_dropped += 1
                continue
            out_kps.append(kps)
            out_ids.append(ids[i] if i < len(ids) else -1)
        return out_kps, out_ids

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

        # GPU delegate (Metal sur macOS) : libere le CPU pour OSC, state,
        # mesh_rigger. Multi-HMR remote macm1 + MediaPipe GPU M5 =
        # workload distribue. Toggle via MEDIAPIPE_DELEGATE=cpu si plante.
        import os as _os
        _deleg_name = _os.environ.get("MEDIAPIPE_DELEGATE", "gpu").lower()
        _deleg = (BaseOptions.Delegate.GPU if _deleg_name == "gpu"
                  else BaseOptions.Delegate.CPU)
        LOG.info("MediaPipe delegate = %s (env MEDIAPIPE_DELEGATE)",
                 _deleg.name)
        pose = PoseLandmarker.create_from_options(PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(pose_p),
                                     delegate=_deleg),
            running_mode=RunningMode.VIDEO,
            num_poses=self.num_persons,
            min_pose_detection_confidence=self.min_conf,
            min_pose_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        face = FaceLandmarker.create_from_options(FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(face_p),
                                     delegate=_deleg),
            running_mode=RunningMode.VIDEO,
            num_faces=self.num_persons,
            min_face_detection_confidence=self.min_conf,
            min_face_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        hand = HandLandmarker.create_from_options(HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(hand_p),
                                     delegate=_deleg),
            running_mode=RunningMode.VIDEO,
            num_hands=self.num_persons * 2,
            min_hand_detection_confidence=self.min_conf,
            min_hand_presence_confidence=self.min_conf,
            min_tracking_confidence=self.min_conf,
        ))
        LOG.info("3 landmarkers prets (num=%d, delegate=%s)",
                 self.num_persons, _deleg.name)

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

            # pose_world_landmarks : xyz metric, relative to hip-center.
            # Aligned 1:1 with pose_landmarks order. Empty fallback if
            # the MediaPipe build doesn't populate it.
            bodies3d: list[list[Kp3D]] = []
            world_list = getattr(pose_res, "pose_world_landmarks", None) or []
            for landmarks_list in world_list:
                kp3_list: list[Kp3D] = []
                for lm in landmarks_list[:33]:
                    v = lm.visibility if lm.visibility is not None else 1.0
                    kp3_list.append(Kp3D(
                        x=float(lm.x), y=float(lm.y),
                        z=float(lm.z if lm.z is not None else 0.0),
                        c=float(v)))
                bodies3d.append(kp3_list)

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
            # --- Discrimination : ghost reject + NMS + pid hysteresis --
            bodies, bodies3d, ids_body = self._reject_ghosts_and_nms(
                bodies, bodies3d, ids_body)
            ids_body = self._apply_pid_hysteresis(bodies, ids_body)
            faces, ids_face = self._drop_low_visibility(
                faces, ids_face, self._face_min_visible, "face")
            hands, ids_hand = self._drop_low_visibility(
                hands, ids_hand, self._hand_min_visible, "hand")
            # --- Lissage One Euro par keypoint -------------------------
            t_now = time.monotonic()
            bodies = [_smooth_kps(self._smooth_body, ids_body[i], kps, t_now)
                      for i, kps in enumerate(bodies)]
            faces  = [_smooth_kps(self._smooth_face, ids_face[i], kps, t_now)
                      for i, kps in enumerate(faces)]
            hands  = [_smooth_kps(self._smooth_hand, ids_hand[i], kps, t_now)
                      for i, kps in enumerate(hands)]
            # --- Filter chain face + hands (median + Kalman 2D + lookahead)
            faces = self._filter_chain.apply_face(faces, ids_face, t_now)
            hands = self._filter_chain.apply_hand(hands, ids_hand, None, t_now)

            # Pont sonore : envoi OSC /pose/* a sclang (body + face + hands)
            # 3D world landmarks share ids with bodies (same MediaPipe
            # detection, just a different coordinate space).
            ids_body3d = ids_body[:len(bodies3d)] if bodies3d else []
            if bodies3d:
                bodies3d = self._filter_chain.apply(bodies3d, ids_body3d, t_now)
            # Debug : log body3d count once / 5 s so we know MediaPipe
            # actually populates pose_world_landmarks.
            if not hasattr(self, "_dbg_b3d_t") or t_now - self._dbg_b3d_t > 5.0:
                LOG.info("body3d: n=%d (pose_world_landmarks)", len(bodies3d))
                self._dbg_b3d_t = t_now
            self._sound_bridge.send(
                bodies, ids_body, t_now,
                persons_face=faces, persons_face_ids=ids_face,
                persons_hands=hands, persons_hands_ids=ids_hand,
                persons_body3d=bodies3d, persons_body3d_ids=ids_body3d)

            with self.state.lock():
                self.state.persons_body = bodies
                self.state.persons_face = faces
                self.state.persons_hands = hands
                self.state.persons_body_ids  = ids_body
                self.state.persons_body3d = bodies3d
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
