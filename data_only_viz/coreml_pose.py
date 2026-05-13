"""Pipeline pose 100% natif M5 : AVFoundation + Vision + CoreML (ANE).

Architecture (zero-copy, ANE-first) :

    AVCaptureSession (live webcam)
        |  delegate Python (Obj-C protocol via pyobjc)
        v
    CMSampleBuffer -> CVPixelBuffer BGRA
        |  VNImageRequestHandler
        v
    VNCoreMLRequest (YOLO11n-pose .mlpackage, ANE)
        |  parse keypoints
        v
    IoUTracker (Hungarian) + SkeletonFilter (One Euro)
        |
        v
    state.persons_body / persons_body_ids / last_webcam_jpeg

Pourquoi cette stack vs MediaPipe / DETRPose ?

  - Decodage video AVFoundation : zero-copy, hardware-accelerated.
  - Vision wrappe le CVPixelBuffer en MLFeatureValue sans realloc.
  - YOLO11n-pose tient sur l'Apple Neural Engine M5 (<8 ms / frame
    en FP16) ; CPU/GPU sont laisses libres pour Metal/SuperCollider.
  - Pas de cv2 dans le hot path : encodage JPEG via CIImage +
    CGImageDestination, qui passe aussi par les codecs hardware.

API publique :
    CoreMLPoseWorker(state).start()  # thread daemon
    CoreMLPoseWorker(state).stop()
    CoreMLPoseWorker.is_available()  # @staticmethod, check .mlpackage

Frictions Python 3.14 :
  - `pyobjc-framework-Vision` n'est PAS publie sur PyPI au moment de
    cette ecriture. On contourne via `objc.loadBundle()` qui charge
    Vision.framework directement depuis /System/Library/Frameworks.
  - Idem pour CoreML : on utilise `objc.loadBundle()`. Les classes
    MLModel / VNCoreMLRequest deviennent disponibles dans le namespace
    global du module.
  - Le delegate AVCaptureVideoDataOutputSampleBufferDelegate est un
    PROTOCOLE Objective-C ; pyobjc accepte qu'on l'implemente en
    declarant le selector `captureOutput:didOutputSampleBuffer:fromConnection:`
    sur une NSObject — il sera resolu par duck typing au runtime.
"""
from __future__ import annotations

import logging
import os
import threading
import time
from pathlib import Path
from typing import TYPE_CHECKING

import objc
from Foundation import NSObject, NSURL

from .euro_filter import SkeletonFilter
from .state import PoseKp, State
from .tracker import IoUTracker

if TYPE_CHECKING:
    pass

LOG = logging.getLogger("coreml_pose")

CACHE_DIR = Path.home() / ".cache" / "av-live-coreml"
YOLO_MLPACKAGE = CACHE_DIR / "yolo11n-pose.mlpackage"


# ---------------------------------------------------------------------------
# Chargement Vision / CoreML / AVFoundation via objc.loadBundle
# ---------------------------------------------------------------------------
_FRAMEWORKS_LOADED = False
_NS: dict = {}


def _load_frameworks() -> dict:
    """Charge Vision + CoreML + AVFoundation dans un namespace partage.

    On le fait une seule fois ; les classes Obj-C sont enregistrees
    globalement par le runtime, mais on garde un dict pour acceder
    aux symboles sans polluer le module."""
    global _FRAMEWORKS_LOADED
    if _FRAMEWORKS_LOADED:
        return _NS
    objc.loadBundle("Vision", _NS,
                    "/System/Library/Frameworks/Vision.framework")
    objc.loadBundle("CoreML", _NS,
                    "/System/Library/Frameworks/CoreML.framework")
    objc.loadBundle("AVFoundation", _NS,
                    "/System/Library/Frameworks/AVFoundation.framework")
    objc.loadBundle("CoreMedia", _NS,
                    "/System/Library/Frameworks/CoreMedia.framework")
    _FRAMEWORKS_LOADED = True
    return _NS


# ---------------------------------------------------------------------------
# Helpers : encodage JPEG via Quartz (CIImage -> CGImageDestination)
# ---------------------------------------------------------------------------
def _pixelbuffer_to_jpeg(pixel_buffer, quality: float = 0.7) -> bytes | None:
    """Encode un CVPixelBuffer en JPEG via le pipeline hardware Quartz."""
    try:
        from Quartz import CIImage, CIContext
        from Foundation import NSMutableData
        from CoreFoundation import CFDictionaryCreate, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks  # noqa: F401
    except Exception:  # noqa: BLE001
        return None
    try:
        ci = CIImage.imageWithCVPixelBuffer_(pixel_buffer)
        if ci is None:
            return None
        ctx = CIContext.context()
        # On utilise jpegRepresentationOfImage:colorSpace:options: (macOS 10.12+)
        from Quartz import CGColorSpaceCreateDeviceRGB
        cs = CGColorSpaceCreateDeviceRGB()
        data = ctx.JPEGRepresentationOfImage_colorSpace_options_(
            ci, cs, {"kCGImageDestinationLossyCompressionQuality": quality})
        if data is None:
            return None
        return bytes(data)
    except Exception:  # noqa: BLE001
        return None


# ---------------------------------------------------------------------------
# Delegate AVCaptureVideoDataOutput
# ---------------------------------------------------------------------------
class _CaptureDelegate(NSObject):
    """Delegate Obj-C qui recoit chaque frame webcam.

    Implementation du protocole AVCaptureVideoDataOutputSampleBufferDelegate :
    pyobjc resout le selector par signature, pas besoin de declarer
    formellement le protocole."""

    def initWithWorker_(self, worker):  # noqa: N802
        self = objc.super(_CaptureDelegate, self).init()
        if self is None:
            return None
        self._worker = worker
        return self

    # Signature: -(void)captureOutput:(AVCaptureOutput*)output
    #              didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
    #              fromConnection:(AVCaptureConnection*)connection
    def captureOutput_didOutputSampleBuffer_fromConnection_(  # noqa: N802
            self, output, sample_buffer, connection):
        self._worker._on_frame(sample_buffer)


# ---------------------------------------------------------------------------
# Queue GCD serielle pour le delegate AVFoundation
# ---------------------------------------------------------------------------
def _make_serial_queue(label: str):
    """Cree une dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL) via objc.

    pyobjc expose les fonctions GCD via le module `objc`. La signature
    Python est : dispatch_queue_create(label_bytes, None) -> dispatch_queue_t.
    """
    try:
        from libdispatch import dispatch_queue_create  # type: ignore
        return dispatch_queue_create(label.encode("utf-8"), None)
    except ImportError:
        pass
    # Fallback : utiliser le runtime Obj-C via ctypes pour appeler
    # dispatch_queue_create. Toutefois pyobjc 11+ expose ces fonctions
    # via Foundation / objc directement.
    try:
        import Foundation  # noqa: F401
        # pyobjc enregistre dispatch_queue_create dans `objc` namespace
        from objc import _objc  # type: ignore  # noqa: F401
    except Exception:  # noqa: BLE001
        pass
    # Dernier recours : ctypes wrapper sur libdispatch (toujours present sur macOS)
    import ctypes
    libdispatch = ctypes.CDLL("/usr/lib/system/libdispatch.dylib")
    libdispatch.dispatch_queue_create.restype = ctypes.c_void_p
    libdispatch.dispatch_queue_create.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
    q = libdispatch.dispatch_queue_create(label.encode("utf-8"), None)
    return q


# ===========================================================================
# Worker principal
# ===========================================================================
class CoreMLPoseWorker:
    """Worker pose natif M5 — AVFoundation + Vision + CoreML (YOLO11n-pose).

    start() peut etre appele depuis n'importe quel thread tant que la run
    loop NSApplication tourne (le delegate AVFoundation est dispatche sur
    une queue serielle GCD dediee, pas sur le main thread)."""

    @staticmethod
    def is_available() -> bool:
        if not YOLO_MLPACKAGE.exists():
            return False
        try:
            _load_frameworks()
            return True
        except Exception:  # noqa: BLE001
            return False

    def __init__(
        self,
        state: State,
        target_fps: float = 30.0,
        num_persons: int = 4,
        score_thresh: float = 0.45,
    ) -> None:
        self.state = state
        self.target_fps = float(target_fps)
        self.num_persons = int(num_persons)
        self.score_thresh = float(score_thresh)
        self._frame_period = 1.0 / max(1.0, self.target_fps)
        self._last_emit = 0.0
        self._tracker = IoUTracker(iou_threshold=0.20, max_miss=10)
        self._smooth = SkeletonFilter(min_cutoff=1.2, beta=0.06)
        # Refs Obj-C
        self._session = None
        self._input = None
        self._output = None
        self._delegate = None
        self._queue = None
        self._vn_model = None
        self._frame_size: tuple[int, int] = (640, 480)
        # Metriques
        self._n_frames = 0
        self._n_emitted = 0
        self._sum_infer_ms = 0.0
        self._started = False

    # ------------------------------------------------------------------
    def start(self) -> None:
        if self._started:
            return
        try:
            self._setup_pipeline()
        except Exception as e:  # noqa: BLE001
            LOG.error("setup pipeline echoue : %s", e)
            return
        self._started = True
        # startRunning peut bloquer brievement — on le fait dans un thread
        # daemon pour ne pas geler le main thread AppKit.
        threading.Thread(
            target=self._start_session, name="coreml-session-start",
            daemon=True).start()

    def stop(self) -> None:
        self._started = False
        try:
            if self._session is not None:
                self._session.stopRunning()
        except Exception:  # noqa: BLE001
            pass
        LOG.info("coreml-pose stop — %d frames, %d emises, %.1f ms moy inference",
                 self._n_frames, self._n_emitted,
                 (self._sum_infer_ms / max(1, self._n_emitted)))

    # ------------------------------------------------------------------
    def _setup_pipeline(self) -> None:
        ns = _load_frameworks()
        AVCaptureSession = ns["AVCaptureSession"]
        AVCaptureDevice = ns["AVCaptureDevice"]
        AVCaptureDeviceInput = ns["AVCaptureDeviceInput"]
        AVCaptureVideoDataOutput = ns["AVCaptureVideoDataOutput"]
        AVMediaTypeVideo = ns["AVMediaTypeVideo"]
        MLModel = ns["MLModel"]
        MLModelConfiguration = ns["MLModelConfiguration"]
        VNCoreMLModel = ns["VNCoreMLModel"]

        # 1) Charger le modele
        cfg = MLModelConfiguration.alloc().init()
        try:
            cfg.setComputeUnits_(0)  # MLComputeUnitsAll
        except Exception:  # noqa: BLE001
            pass
        url = NSURL.fileURLWithPath_(str(YOLO_MLPACKAGE))
        ml_model, err = MLModel.modelWithContentsOfURL_configuration_error_(
            url, cfg, None)
        if ml_model is None:
            raise RuntimeError(f"MLModel load: {err}")
        vn_model, err = VNCoreMLModel.modelForMLModel_error_(ml_model, None)
        if vn_model is None:
            raise RuntimeError(f"VNCoreMLModel wrap: {err}")
        self._vn_model = vn_model
        LOG.info("CoreML pose worker — modele %s charge (computeUnits=all=ANE+GPU+CPU)",
                 YOLO_MLPACKAGE.name)

        # 2) Session capture
        session = AVCaptureSession.alloc().init()
        try:
            session.setSessionPreset_("AVCaptureSessionPreset640x480")
        except Exception:  # noqa: BLE001
            pass

        device = AVCaptureDevice.defaultDeviceWithMediaType_(AVMediaTypeVideo)
        if device is None:
            raise RuntimeError("aucune camera (AVCaptureDevice defaultDevice)")
        input_, err = AVCaptureDeviceInput.deviceInputWithDevice_error_(
            device, None)
        if input_ is None:
            raise RuntimeError(f"AVCaptureDeviceInput: {err}")
        if not session.canAddInput_(input_):
            raise RuntimeError("session.canAddInput == False")
        session.addInput_(input_)
        self._input = input_

        # 3) Output BGRA
        output = AVCaptureVideoDataOutput.alloc().init()
        BGRA = 0x42475241  # kCVPixelFormatType_32BGRA
        try:
            # cle officielle = kCVPixelBufferPixelFormatTypeKey
            from Quartz import kCVPixelBufferPixelFormatTypeKey
            output.setVideoSettings_({kCVPixelBufferPixelFormatTypeKey: BGRA})
        except Exception:  # noqa: BLE001
            # Fallback : nom de cle litteral
            output.setVideoSettings_({"PixelFormatType": BGRA})
        output.setAlwaysDiscardsLateVideoFrames_(True)
        if not session.canAddOutput_(output):
            raise RuntimeError("session.canAddOutput == False")
        session.addOutput_(output)
        self._output = output

        # 4) Delegate + queue serielle GCD
        delegate = _CaptureDelegate.alloc().initWithWorker_(self)
        queue = _make_serial_queue("av-live.coreml.pose")
        output.setSampleBufferDelegate_queue_(delegate, queue)
        self._delegate = delegate
        self._queue = queue
        self._session = session

    def _start_session(self) -> None:
        if self._session is None:
            return
        LOG.info("AVCaptureSession.startRunning ...")
        self._session.startRunning()
        LOG.info("session running — fps_target=%.0f num_persons=%d thresh=%.2f",
                 self.target_fps, self.num_persons, self.score_thresh)

    # ------------------------------------------------------------------
    # Callback delegate — appele par GCD sur la queue serielle "coreml.pose"
    # ------------------------------------------------------------------
    def _on_frame(self, sample_buffer) -> None:
        self._n_frames += 1
        now = time.monotonic()
        if now - self._last_emit < self._frame_period:
            return
        self._last_emit = now
        t0 = time.monotonic()
        try:
            self._process_frame(sample_buffer)
        except Exception as e:  # noqa: BLE001
            LOG.warning("process_frame: %s", e)
            return
        self._sum_infer_ms += (time.monotonic() - t0) * 1000.0
        self._n_emitted += 1

    def _process_frame(self, sample_buffer) -> None:
        ns = _NS
        VNImageRequestHandler = ns["VNImageRequestHandler"]
        VNCoreMLRequest = ns["VNCoreMLRequest"]
        # CMSampleBufferGetImageBuffer renvoie un CVPixelBuffer
        from Quartz import (
            CMSampleBufferGetImageBuffer,
            CVPixelBufferGetWidth,
            CVPixelBufferGetHeight,
        )
        pixel_buffer = CMSampleBufferGetImageBuffer(sample_buffer)
        if pixel_buffer is None:
            return
        w = CVPixelBufferGetWidth(pixel_buffer)
        h = CVPixelBufferGetHeight(pixel_buffer)
        self._frame_size = (w, h)

        # Construction du request synchrone : on capture les resultats
        # dans une closure puis on perform().
        results_box: list = []

        def _handler(request, error):
            r = request.results()
            if r is not None:
                # On copie les pointeurs Obj-C immediatement
                for obs in r:
                    results_box.append(obs)

        request = VNCoreMLRequest.alloc().initWithModel_completionHandler_(
            self._vn_model, _handler)
        try:
            # Image crop & scale : on laisse Vision faire le scaleFit ;
            # YOLO11n-pose attend 640x640.
            request.setImageCropAndScaleOption_(1)  # VNImageCropAndScaleOptionScaleFit
        except Exception:  # noqa: BLE001
            pass

        handler = VNImageRequestHandler.alloc().initWithCVPixelBuffer_options_(
            pixel_buffer, {})
        ok, err = handler.performRequests_error_([request], None)
        if not ok:
            LOG.debug("perform request error: %s", err)
            return

        # Parsing : Vision retourne soit VNRecognizedPointsObservation
        # (modele "pose" classique), soit VNCoreMLFeatureValueObservation
        # (modele YOLO converti par ultralytics — tenseur brut).
        bodies = self._parse_results(results_box, w, h)

        # Tracking + lissage
        ids = self._tracker.update(bodies)
        t_now = time.monotonic()
        bodies_smooth = []
        for i, kps in enumerate(bodies):
            pid = ids[i] if i < len(ids) else -1
            if pid < 0:
                bodies_smooth.append(kps)
                continue
            out = []
            for k, kp in enumerate(kps):
                sx, sy, sz = self._smooth.smooth(pid, k, kp.x, kp.y, kp.z, t_now)
                out.append(PoseKp(x=sx, y=sy, z=sz, c=kp.c))
            bodies_smooth.append(out)

        # JPEG webcam (best effort)
        jpg = _pixelbuffer_to_jpeg(pixel_buffer, quality=0.65)

        with self.state.lock():
            self.state.persons_body = bodies_smooth
            self.state.persons_body_ids = ids
            # On vide face/hands : YOLO11n-pose ne les fournit pas.
            self.state.persons_face = []
            self.state.persons_hands = []
            self.state.face_present = False
            self.state.hands_present = False
            if bodies_smooth:
                self.state.body_present = True
                # Compat single-person : 17 kp dans body_kp[0..17],
                # le reste reste a zero.
                first = bodies_smooth[0]
                for k in range(33):
                    self.state.body_kp[k] = (
                        first[k] if k < 17 and k < len(first) else PoseKp())
                for k in range(17):
                    self.state.pose_kp[k] = (
                        first[k] if k < len(first) else PoseKp())
            else:
                self.state.body_present = False
            self.state.pose_count = len(bodies_smooth)
            self.state.pose_last_t = t_now
            if jpg:
                self.state.last_webcam_jpeg = jpg

    # ------------------------------------------------------------------
    # Parsing des observations Vision -> list[list[PoseKp]]
    # ------------------------------------------------------------------
    def _parse_results(self, results, w: int, h: int) -> list[list[PoseKp]]:
        """Convertit les VN*Observation en keypoints normalises 0..1.

        Deux formats possibles selon la conversion CoreML :
          (a) VNHumanBodyPoseObservation : API Vision native, 17 kp pre-parses
              avec joint names (CGPoint normalises + confidence).
          (b) VNCoreMLFeatureValueObservation : tenseur brut YOLO output
              (post-NMS si nms=True dans l'export ultralytics) — format
              (N, 56) = [cx, cy, bw, bh, conf, kp_x1, kp_y1, kp_v1, ..., x17, y17, v17]
              en pixels du modele (640x640).
        """
        bodies: list[list[PoseKp]] = []
        if not results:
            return bodies

        # Cas (a) : Vision pre-parse
        first = results[0]
        cls_name = first.className() if hasattr(first, "className") else ""
        if "BodyPose" in cls_name or "HumanBodyPose" in cls_name:
            for obs in results[: self.num_persons * 2]:
                conf = float(obs.confidence()) if hasattr(obs, "confidence") else 1.0
                if conf < self.score_thresh:
                    continue
                kps = self._extract_body_pose_obs(obs)
                if kps:
                    bodies.append(kps)
            return bodies[: self.num_persons]

        # Cas (b) : tenseur YOLO brut
        for obs in results:
            try:
                fv = obs.featureValue()
            except Exception:  # noqa: BLE001
                continue
            arr = fv.multiArrayValue() if fv is not None else None
            if arr is None:
                continue
            parsed = self._parse_yolo_tensor(arr)
            bodies.extend(parsed)
        # tri par conf decroissant + cap
        bodies.sort(key=lambda kps: -max((k.c for k in kps), default=0.0))
        return bodies[: self.num_persons]

    def _extract_body_pose_obs(self, obs) -> list[PoseKp]:
        """Extrait 17 kp d'un VNHumanBodyPoseObservation (ordre COCO).

        L'API Vision retourne les points via recognizedPointsForGroupKey:error:
        OU recognizedPointForJointName:error:. On utilise l'ordre COCO :
        nose, leye, reye, lear, rear, lsh, rsh, lel, rel, lwr, rwr,
        lhi, rhi, lkn, rkn, lan, ran.
        """
        joint_names = [
            "nose", "left_eye", "right_eye", "left_ear", "right_ear",
            "left_shoulder", "right_shoulder",
            "left_elbow", "right_elbow",
            "left_wrist", "right_wrist",
            "left_hip", "right_hip",
            "left_knee", "right_knee",
            "left_ankle", "right_ankle",
        ]
        out: list[PoseKp] = []
        for name in joint_names:
            try:
                pt, _err = obs.recognizedPointForJointName_error_(name, None)
            except Exception:  # noqa: BLE001
                pt = None
            if pt is None:
                out.append(PoseKp())
                continue
            try:
                loc = pt.location()
                cf = float(pt.confidence())
                # Vision : y origin en bas, on flip pour aligner avec image y-down
                out.append(PoseKp(x=float(loc.x), y=1.0 - float(loc.y),
                                  z=0.0, c=cf))
            except Exception:  # noqa: BLE001
                out.append(PoseKp())
        return out

    def _parse_yolo_tensor(self, ml_array) -> list[list[PoseKp]]:
        """Parse un MLMultiArray YOLO11n-pose post-NMS -> bodies.

        Shape attendu apres export ultralytics nms=True : (1, N, 56)
        avec 56 = box(4) + conf(1) + 17 * (x,y,v) = 4+1+51.
        Sans NMS : (1, 56, M) transpose. On gere les deux."""
        try:
            shape = list(ml_array.shape)
            dims = [int(s) for s in shape]
        except Exception:  # noqa: BLE001
            return []
        # Acceder aux donnees via dataPointer() est risque ; on passe par
        # itemAtIndexedSubscript: ou la conversion en numpy via .float32 view.
        try:
            import numpy as np
            # MLMultiArray expose 'dataPointer' (raw void*) — on prefere
            # construire un buffer Python via getBytes:length: indirect.
            count = 1
            for d in dims:
                count *= d
            buf = ml_array.dataPointer()
            # pyobjc renvoie un objc.varlist ou un voidp — on tente numpy.frombuffer
            arr = np.frombuffer(buf, dtype=np.float32, count=count).reshape(dims)
        except Exception:  # noqa: BLE001
            return []

        # Squeeze batch
        while arr.ndim > 2 and arr.shape[0] == 1:
            arr = arr[0]
        if arr.ndim != 2:
            return []
        # Si shape (56, M) au lieu de (M, 56) -> transpose
        if arr.shape[0] == 56 and arr.shape[1] != 56:
            arr = arr.T
        elif arr.shape[1] != 56 and arr.shape[0] != 56:
            return []

        bodies: list[list[PoseKp]] = []
        for row in arr:
            conf = float(row[4])
            if conf < self.score_thresh:
                continue
            kps: list[PoseKp] = []
            for k in range(17):
                kx = float(row[5 + k * 3 + 0])
                ky = float(row[5 + k * 3 + 1])
                kv = float(row[5 + k * 3 + 2])
                # Coords en pixels du modele 640x640 -> normaliser
                kps.append(PoseKp(x=kx / 640.0, y=ky / 640.0, z=0.0, c=kv))
            bodies.append(kps)
        return bodies
