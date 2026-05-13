"""Apple Vision body pose — version cv2 + Vision (sans AVCaptureSession).

Le pipeline AVCaptureSession + dispatch_queue + delegate crashe silencieusement
sur Python 3.14 (probablement libdispatch via ctypes). On bypass : capture
webcam via cv2.VideoCapture (deja eprouve dans multi.py), inference Vision
via VNImageRequestHandler en passant un JPEG bytes.

Avantages :
- Pas de delegate AVF, pas de dispatch_queue ctypes
- Pattern thread daemon classique, robuste
- VNDetectHumanBodyPoseRequest ANE-accelerated meme via JPEG handler

Inconvenients vs AVCaptureSession :
- Encodage JPEG entre cv2 et Vision (~3 ms overhead)
- Pas de zero-copy CVPixelBuffer

Active : AV_LIVE_APPLE_VISION=1 uv run python -m data_only_viz.main --pose
"""
from __future__ import annotations

import logging
import threading
import time

import objc
from Foundation import NSBundle, NSData

from .euro_filter import SkeletonFilter
from .fine_analysis import FineAnalyzer
from .mesh_topology import FACE_OFFSETS
from .pose_bridge import PoseSoundBridge
from .state import PoseKp, State
from .tracker import IoUTracker

LOG = logging.getLogger("apple_vision_pose")


# Ordre des 21 joints VNHumanHandPoseObservation (standard MediaPipe).
HAND_JOINTS: tuple[str, ...] = (
    "VNHLKWrist",
    "VNHLKThumbCMC", "VNHLKThumbMP", "VNHLKThumbIP", "VNHLKThumbTip",
    "VNHLKIndexMCP", "VNHLKIndexPIP", "VNHLKIndexDIP", "VNHLKIndexTip",
    "VNHLKMiddleMCP", "VNHLKMiddlePIP", "VNHLKMiddleDIP", "VNHLKMiddleTip",
    "VNHLKRingMCP", "VNHLKRingPIP", "VNHLKRingDIP", "VNHLKRingTip",
    "VNHLKLittleMCP", "VNHLKLittlePIP", "VNHLKLittleDIP", "VNHLKLittleTip",
)

# Regions de VNFaceLandmarks2D dans l'ordre attendu par FACE_OFFSETS.
FACE_REGIONS: tuple[tuple[str, int], ...] = (
    ("faceContour", 17),
    ("leftEye", 8),
    ("rightEye", 8),
    ("leftEyebrow", 6),
    ("rightEyebrow", 6),
    ("outerLips", 14),
    ("innerLips", 10),
    ("nose", 6),
    ("medianLine", 6),
)


# ---------------------------------------------------------------------------
# Charge Vision via loadBundle (pas de pyobjc-framework-Vision sur PyPI)
# ---------------------------------------------------------------------------
_NS: dict = {}
_LOADED = False


def _load_vision() -> dict:
    """Charge Vision.framework dans le namespace _NS (lazy, idempotent)."""
    global _LOADED
    if _LOADED:
        return _NS
    bundle = NSBundle.bundleWithPath_("/System/Library/Frameworks/Vision.framework")
    if bundle is None or not bundle.load():
        raise RuntimeError("Impossible de charger Vision.framework")
    objc.loadBundle("Vision", _NS, bundle.bundlePath())
    # Enregistrer la metadata explicite : pointAtIndex_ prend un NSUInteger
    # et retourne un CGPoint struct (pas une id). Sans ca pyobjc voit
    # un selector 0-arg et plante avec "Need 0 arguments, got 1".
    try:
        objc.registerMetaDataForSelector(
            b'VNFaceLandmarkRegion2D', b'pointAtIndex:',
            {
                'arguments': {2: {'type': objc._C_NSUInteger}},
                'retval': {'type': b'{CGPoint=dd}'},
            }
        )
    except Exception:
        pass
    _LOADED = True
    return _NS


# Mapping joint Apple Vision -> indice MediaPipe POSE_LANDMARKS
# (cf https://developers.google.com/mediapipe/solutions/vision/pose_landmarker)
JOINT_MAP: dict[str, int] = {
    "nose":              0,
    "left_eye":          1,
    "right_eye":         4,
    "left_ear":          7,
    "right_ear":         8,
    "left_shoulder":    11,
    "right_shoulder":   12,
    "left_elbow":       13,
    "right_elbow":      14,
    "left_wrist":       15,
    "right_wrist":      16,
    "left_hip":         23,
    "right_hip":        24,
    "left_knee":        25,
    "right_knee":       26,
    "left_ankle":       27,
    "right_ankle":      28,
}


class AppleVisionPoseWorker:
    """Worker thread : cv2.VideoCapture + VNDetectHumanBodyPoseRequest."""

    def __init__(
        self,
        state: State,
        camera_index: int = 0,
        target_fps: float = 30.0,
        num_persons: int = 4,
        score_thresh: float = 0.30,
    ) -> None:
        self.state = state
        self.camera_index = camera_index
        self.period = 1.0 / max(1.0, target_fps)
        self.target_fps = target_fps
        self.num_persons = num_persons
        self.score_thresh = score_thresh
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        # Lissage + tracking (reutilises de multi.py)
        self._tracker = IoUTracker(iou_threshold=0.20, max_miss=10)
        self._smooth = SkeletonFilter(min_cutoff=1.2, beta=0.06)
        # Pont OSC pose -> sclang (pour piloter du son live)
        self._sound_bridge = PoseSoundBridge(throttle_hz=30.0)
        # Analyse fine : crops haute resolution sur visage/mains
        # (cadence 10 Hz pour ne pas saturer ANE)
        self._fine_analyzer: FineAnalyzer | None = None

    @staticmethod
    def is_available() -> bool:
        """True si Vision.framework + cv2 + Foundation chargent OK."""
        try:
            _load_vision()
            import cv2  # noqa: F401
            return True
        except Exception:
            return False

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="apple-vision-pose", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    # ------------------------------------------------------------------
    def _pick_builtin_camera(self) -> int:
        """Energe les cameras via AVFoundation, retourne l'index de la
        BuiltIn (MacBook Pro / FaceTime HD), evite Continuity Camera
        (iPhone) et Desk View. Fallback sur self.camera_index (0)."""
        try:
            from Foundation import NSBundle
            b = NSBundle.bundleWithPath_(
                "/System/Library/Frameworks/AVFoundation.framework")
            b.load()
            ns = {}
            objc.loadBundle("AVFoundation", ns, b.bundlePath())
            DiscoverySession = ns["AVCaptureDeviceDiscoverySession"]
            session = (DiscoverySession
                .discoverySessionWithDeviceTypes_mediaType_position_(
                    ["AVCaptureDeviceTypeBuiltInWideAngleCamera",
                     "AVCaptureDeviceTypeContinuityCamera",
                     "AVCaptureDeviceTypeExternal",
                     "AVCaptureDeviceTypeDeskViewCamera"],
                    "vide", 0))
            devices = session.devices() or []
            for i, d in enumerate(devices):
                name = str(d.localizedName())
                dtype = str(d.deviceType() if hasattr(d, "deviceType") else "")
                LOG.info("camera [%d] %s (%s)", i, name, dtype.split(".")[-1])
            # Cherche l'index BuiltInWideAngleCamera
            for i, d in enumerate(devices):
                dtype = str(d.deviceType() if hasattr(d, "deviceType") else "")
                if "BuiltInWideAngleCamera" in dtype:
                    LOG.info("camera Mac built-in -> index %d", i)
                    return i
        except Exception as e:
            LOG.warning("camera enum failed: %s", e)
        return self.camera_index

    def _run(self) -> None:
        try:
            import cv2
            import numpy as np  # noqa: F401
        except ModuleNotFoundError as e:
            LOG.error("deps manquantes : %s — uv sync --extra pose", e)
            return
        try:
            ns = _load_vision()
        except Exception as e:  # noqa: BLE001
            LOG.error("Vision.framework KO : %s", e)
            return

        VNImageRequestHandler = ns["VNImageRequestHandler"]
        VNDetectHumanBodyPoseRequest = ns["VNDetectHumanBodyPoseRequest"]
        # Face + hands : noms exposes par Vision.framework.
        VNDetectFaceLandmarksRequest = ns.get("VNDetectFaceLandmarksRequest")
        VNDetectHumanHandPoseRequest = ns.get("VNDetectHumanHandPoseRequest")
        if VNDetectFaceLandmarksRequest is None:
            LOG.warning("VNDetectFaceLandmarksRequest absent — face mesh OFF")
        if VNDetectHumanHandPoseRequest is None:
            LOG.warning("VNDetectHumanHandPoseRequest absent — hand mesh OFF")

        # Force cam Mac built-in (evite Continuity Camera iPhone par defaut)
        cam_idx = self._pick_builtin_camera()
        cap = cv2.VideoCapture(cam_idx)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        if not cap.isOpened():
            LOG.error("camera index %d indisponible (TCC ?)", cam_idx)
            return
        LOG.info("camera ouverte index=%d — VNDetectHumanBodyPoseRequest ANE actif", cam_idx)

        n_frames = 0
        sum_ms = 0.0
        while not self._stop.is_set():
            tA = time.monotonic()
            ok, frame_bgr = cap.read()
            if not ok or frame_bgr is None:
                time.sleep(self.period)
                continue
            h, w = frame_bgr.shape[:2]

            # Encode JPEG une seule fois (webcam HUD + Vision input)
            ok2, jpg = cv2.imencode(".jpg", frame_bgr,
                                    [int(cv2.IMWRITE_JPEG_QUALITY), 75])
            if not ok2:
                time.sleep(self.period)
                continue
            jpg_bytes = bytes(jpg)

            # Vision : VNImageRequestHandler accepte des bytes via NSData
            data = NSData.dataWithBytes_length_(jpg_bytes, len(jpg_bytes))
            handler = VNImageRequestHandler.alloc().initWithData_options_(
                data, {})
            request = VNDetectHumanBodyPoseRequest.alloc().init()
            # On execute 3 requetes (body + face + hands) sur la MEME
            # frame : 1 inference ANE pour les 3 (parallelisation interne
            # Vision). Si une requete est indisponible, on passe.
            requests = [request]
            face_request = None
            hand_request = None
            if VNDetectFaceLandmarksRequest is not None:
                face_request = VNDetectFaceLandmarksRequest.alloc().init()
                requests.append(face_request)
            if VNDetectHumanHandPoseRequest is not None:
                hand_request = VNDetectHumanHandPoseRequest.alloc().init()
                try:
                    hand_request.setMaximumHandCount_(self.num_persons * 2)
                except Exception:
                    pass
                requests.append(hand_request)

            try:
                t_inf = time.monotonic()
                # pyobjc peut retourner soit bool, soit (bool, error) selon
                # la version. On normalise.
                ret = handler.performRequests_error_(requests, None)
                if isinstance(ret, tuple):
                    ok3, err = ret
                else:
                    ok3, err = bool(ret), None
                infer_ms = (time.monotonic() - t_inf) * 1000.0
                sum_ms += infer_ms
                n_frames += 1
            except Exception as e:  # noqa: BLE001
                LOG.warning("Vision performRequests crash : %s", e)
                time.sleep(self.period)
                continue
            if not ok3:
                if n_frames < 5:
                    LOG.warning("Vision request failed: %s", err)
                time.sleep(self.period)
                continue

            results = request.results() or []
            bodies: list[list[PoseKp]] = []
            n_body_raw = len(results)
            for obs in results[: self.num_persons * 2]:
                kps = self._parse_observation(obs)
                if kps is not None:
                    bodies.append(kps)

            # ---- Face landmarks ------------------------------------
            faces: list[list[PoseKp]] = []
            n_face_raw = 0
            if face_request is not None:
                try:
                    face_results = face_request.results() or []
                except Exception:
                    face_results = []
                n_face_raw = len(face_results)
                for obs in face_results[: self.num_persons * 2]:
                    fkps = self._parse_face_observation(obs)
                    if fkps is not None:
                        faces.append(fkps)

            # ---- Hand poses ----------------------------------------
            hands: list[list[PoseKp]] = []
            n_hand_raw = 0
            if hand_request is not None:
                try:
                    hand_results = hand_request.results() or []
                except Exception:
                    hand_results = []
                n_hand_raw = len(hand_results)
                for obs in hand_results[: self.num_persons * 2]:
                    hkps = self._parse_hand_observation(obs)
                    if hkps is not None:
                        hands.append(hkps)

            # Log debug : raw counts vs parsed counts (toutes les ~3s)
            if n_frames % 90 == 0:
                LOG.info("Vision raw: body=%d face=%d hand=%d  "
                         "parsed: body=%d face=%d hand=%d",
                         n_body_raw, n_face_raw, n_hand_raw,
                         len(bodies), len(faces), len(hands))

            # ---- Analyse fine : re-inference sur crops haute resolution
            # (visage/mains agrandis 4x avant repasse Vision). Throttle 10 Hz.
            if self._fine_analyzer is None:
                self._fine_analyzer = FineAnalyzer(ns, throttle_hz=10.0)
            t_now = time.monotonic()
            if self._fine_analyzer.should_refine(t_now):
                # Wrappers de re-projection : les kps du crop sont en
                # coordonnees crop normalisees ; on les remap dans l'image
                # entiere via (x_origin, y_origin) + scale.
                def _wrap_face(obs, x_origin, y_origin, scale_x, scale_y):
                    kps = self._parse_face_observation(obs)
                    if kps is None:
                        return None
                    return [PoseKp(
                        x=x_origin + k.x * scale_x,
                        y=y_origin + k.y * scale_y,
                        z=k.z, c=k.c,
                    ) for k in kps]

                def _wrap_hand(obs, x_origin, y_origin, scale_x, scale_y):
                    kps = self._parse_hand_observation(obs)
                    if kps is None:
                        return None
                    return [PoseKp(
                        x=x_origin + k.x * scale_x,
                        y=y_origin + k.y * scale_y,
                        z=k.z, c=k.c,
                    ) for k in kps]

                faces = self._fine_analyzer.refine_face(
                    frame_bgr, faces, _wrap_face)
                hands = self._fine_analyzer.refine_hands(
                    frame_bgr, hands, _wrap_hand)

            # Tracking + lissage (t_now deja defini au bloc fine analysis)
            ids = self._tracker.update(bodies)
            bodies_smooth = []
            for i, kps in enumerate(bodies):
                pid = ids[i] if i < len(ids) else -1
                if pid >= 0:
                    smoothed = []
                    for k, kp in enumerate(kps):
                        if kp.c > 0.0:
                            sx, sy, sz = self._smooth.smooth(
                                pid, k, kp.x, kp.y, kp.z, t_now)
                            smoothed.append(PoseKp(x=sx, y=sy, z=sz, c=kp.c))
                        else:
                            smoothed.append(kp)
                    bodies_smooth.append(smoothed)
                else:
                    bodies_smooth.append(kps)

            # Pont sonore vers sclang (OSC /pose/* sur 57121)
            self._sound_bridge.send(bodies_smooth, ids, t_now)

            with self.state.lock():
                self.state.persons_body = bodies_smooth
                self.state.persons_body_ids = ids
                self.state.persons_face = faces
                # Pas de tracking dedie pour les faces : IDs = index.
                self.state.persons_face_ids = list(range(len(faces)))
                self.state.persons_hands = hands
                self.state.persons_hands_ids = list(range(len(hands)))
                self.state.body_present = bool(bodies_smooth)
                self.state.face_present = bool(faces)
                self.state.hands_present = bool(hands)
                self.state.pose_count = len(bodies_smooth)
                self.state.pose_last_t = time.monotonic()
                self.state.last_webcam_jpeg = jpg_bytes
                # Compat single-person : copie le 1er body dans pose_kp legacy
                if bodies_smooth and bodies_smooth[0]:
                    for k in range(min(17, len(bodies_smooth[0]))):
                        self.state.body_kp[k] = bodies_smooth[0][k]

            # Throttle target_fps
            dt = time.monotonic() - tA
            if dt < self.period:
                time.sleep(self.period - dt)

        cap.release()
        avg = sum_ms / max(1, n_frames)
        LOG.info("apple-vision stop — %d frames, %.1f ms moy inference",
                 n_frames, avg)

    # ------------------------------------------------------------------
    def _parse_observation(self, obs) -> list[PoseKp] | None:
        """Recupere TOUS les joints via recognizedPointsForGroupKey:
        retourne un dict {jointName: VNRecognizedPoint}. On mappe les keys
        retournees (peu importe leur format string exact) sur les indices
        MediaPipe via un suffixe (case insensitive).
        """
        try:
            conf = float(obs.confidence())
        except Exception:
            conf = 1.0
        if conf < self.score_thresh:
            return None

        kps = [PoseKp() for _ in range(33)]
        # Apple Vision body joints sont nommes selon la hierarchie ARKit
        # skeleton, pas les COCO/MP names. Les vraies cles :
        #   head_joint, neck_1_joint, root,
        #   left_shoulder_1_joint, right_shoulder_1_joint,
        #   left_forearm_joint,    right_forearm_joint,
        #   left_hand_joint,       right_hand_joint,
        #   left_upLeg_joint,      right_upLeg_joint,
        #   left_leg_joint,        right_leg_joint,
        #   left_foot_joint,       right_foot_joint
        APPLE_TO_MP = {
            "head_joint":             0,   # nose (approximation)
            "left_shoulder_1_joint": 11,
            "right_shoulder_1_joint":12,
            "left_forearm_joint":    13,   # elbow gauche
            "right_forearm_joint":   14,
            "left_hand_joint":       15,   # poignet gauche
            "right_hand_joint":      16,
            "left_upLeg_joint":      23,   # hanche
            "right_upLeg_joint":     24,
            "left_leg_joint":        25,   # genou
            "right_leg_joint":       26,
            "left_foot_joint":       27,   # cheville
            "right_foot_joint":      28,
        }
        for apple_name, mp_idx in APPLE_TO_MP.items():
            try:
                ret = obs.recognizedPointForJointName_error_(apple_name, None)
                pt = ret[0] if isinstance(ret, tuple) else ret
                if pt is None:
                    continue
                pc = float(pt.confidence())
                if pc < 0.1:
                    continue
                loc = pt.location()
                kps[mp_idx] = PoseKp(
                    x=float(loc.x),
                    y=1.0 - float(loc.y),
                    z=0.0,
                    c=pc,
                )
            except Exception:
                continue

        # Si la 1ere passe ne trouve rien, debug log les vraies keys
        n_visible = sum(1 for k in kps if k.c > 0.1)
        if n_visible == 0 and not hasattr(self, "_logged_keys"):
            try:
                ret = obs.availableJointNames_error_(None)
                names = ret[0] if isinstance(ret, tuple) else ret
                LOG.info("availableJointNames: %s", list(names)[:10] if names else "EMPTY")
                self._logged_keys = True
            except Exception as e:
                LOG.info("availableJointNames KO: %s", e)
                self._logged_keys = True

        # Verifie qu'on a au moins quelques kp visibles
        n_visible = sum(1 for k in kps if k.c > 0.1)
        if n_visible < 4:
            return None
        return kps

    # ------------------------------------------------------------------
    def _parse_face_observation(self, obs) -> list[PoseKp] | None:
        """Parse les face landmarks Apple Vision via `pointAtIndex_(k)`
        (API stable qui retourne un CGPoint struct, pas un UnsafePointer
        problematique). Resout le blocage pyobjc PyObjCPointer.
        """
        """Extrait les landmarks face Apple Vision en liste plate de PoseKp.

        Layout : offsets FACE_OFFSETS (cf mesh_topology.py). Le bbox de
        l'observation (.boundingBox normalize 0..1) sert a re-projeter
        les normalizedPoints (normalises DANS le bbox) vers le repere
        plein cadre normalise (0..1, top-left).
        """
        try:
            landmarks = obs.landmarks()
            if landmarks is None:
                if not hasattr(self, "_face_no_lm_logged"):
                    LOG.info("face: obs.landmarks() == None — face mesh OFF")
                    self._face_no_lm_logged = True
                return None
            bb = obs.boundingBox()
            bx, by = float(bb.origin.x), float(bb.origin.y)
            bw, bh = float(bb.size.width), float(bb.size.height)
        except Exception as e:
            if not hasattr(self, "_face_err_logged"):
                LOG.info("face parse err: %s", e)
                self._face_err_logged = True
            return None

        # Pre-rempli a (0,0,0,0). On comble les regions disponibles.
        kps: list[PoseKp] = [PoseKp() for _ in range(83)]

        def fill(region_name: str, start: int, end: int) -> None:
            region = None
            # Essaye 3 acces : methode obj-c, attribut Python, KVC
            for fetcher in (
                lambda: getattr(landmarks, region_name)(),
                lambda: getattr(landmarks, region_name),
                lambda: landmarks.valueForKey_(region_name),
            ):
                try:
                    region = fetcher()
                    if region is not None:
                        break
                except Exception:
                    continue
            if region is None:
                if not hasattr(self, "_logged_face_fail_" + region_name):
                    LOG.info("face: region %s introuvable", region_name)
                    setattr(self, "_logged_face_fail_" + region_name, True)
                return
            try:
                count = int(region.pointCount())
            except Exception:
                return
            if not hasattr(self, "_logged_face_ok_" + region_name):
                LOG.info("face: region %s count=%d", region_name, count)
                setattr(self, "_logged_face_ok_" + region_name, True)
            # API stable : pointAtIndex_(k) retourne un CGPoint struct.
            n = min(count, end - start)
            n_written = 0
            for k in range(n):
                try:
                    pt = region.pointAtIndex_(k)
                    # CGPoint en pyobjc : tuple (x, y) ou struct
                    try:
                        nx_bb = float(pt.x); ny_bb = float(pt.y)
                    except (AttributeError, TypeError):
                        nx_bb = float(pt[0]); ny_bb = float(pt[1])
                    fx = bx + nx_bb * bw
                    fy_bl = by + ny_bb * bh
                    kps[start + k] = PoseKp(
                        x=fx, y=1.0 - fy_bl, z=0.0, c=1.0)
                    n_written += 1
                except Exception as e:
                    if not hasattr(self, "_logged_face_pt_err"):
                        LOG.info("face: pt %s[%d] err: %s (pt=%r)",
                                 region_name, k, e, type(pt).__name__
                                 if 'pt' in dir() else "??")
                        self._logged_face_pt_err = True
                    continue
            if n_written > 0 and not hasattr(self, "_logged_face_write_" + region_name):
                LOG.info("face: %s wrote %d points", region_name, n_written)
                setattr(self, "_logged_face_write_" + region_name, True)

        # faceContour
        fill("faceContour", *FACE_OFFSETS["contour"])
        fill("leftEye",     *FACE_OFFSETS["left_eye"])
        fill("rightEye",    *FACE_OFFSETS["right_eye"])
        fill("leftEyebrow", *FACE_OFFSETS["left_brow"])
        fill("rightEyebrow",*FACE_OFFSETS["right_brow"])
        fill("outerLips",   *FACE_OFFSETS["outer_lips"])
        fill("innerLips",   *FACE_OFFSETS["inner_lips"])
        fill("nose",        *FACE_OFFSETS["nose"])
        fill("medianLine",  *FACE_OFFSETS["median"])

        # Pupilles : VNFaceLandmarkRegion2D simple (1 point chacune).
        for region_name, idx in (("leftPupil", 81), ("rightPupil", 82)):
            try:
                region = getattr(landmarks, region_name)()
                if region is None or region.pointCount() < 1:
                    continue
                pt = region.pointAtIndex_(0)
                try:
                    px, py = float(pt.x), float(pt.y)
                except (AttributeError, TypeError):
                    px, py = float(pt[0]), float(pt[1])
                fx = bx + px * bw
                fy_bl = by + py * bh
                kps[idx] = PoseKp(x=fx, y=1.0 - fy_bl, z=0.0, c=1.0)
            except Exception:
                continue

        n_visible = sum(1 for k in kps if k.c > 0.0)
        if n_visible < 8:
            return None
        return kps

    # ------------------------------------------------------------------
    def _parse_hand_observation(self, obs) -> list[PoseKp] | None:
        """Extrait les 21 joints d'une VNHumanHandPoseObservation."""
        kps = [PoseKp() for _ in range(21)]
        n_visible = 0
        for k, joint_name in enumerate(HAND_JOINTS):
            try:
                ret = obs.recognizedPointForJointName_error_(joint_name, None)
                pt = ret[0] if isinstance(ret, tuple) else ret
                if pt is None:
                    continue
                pc = float(pt.confidence())
                if pc < 0.1:
                    continue
                loc = pt.location()
                kps[k] = PoseKp(
                    x=float(loc.x),
                    y=1.0 - float(loc.y),
                    z=0.0,
                    c=pc,
                )
                n_visible += 1
            except Exception:
                continue
        if n_visible < 4:
            return None
        return kps
