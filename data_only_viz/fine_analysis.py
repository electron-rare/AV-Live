"""Analyse fine : crops haute resolution sur visage et mains detectes.

Strategie : la 1ere passe Apple Vision tourne sur la frame 640x480 entiere
(rapide, mais visage/mains sont petits → landmarks moins precis). Cette
seconde passe identifie les ROIs (bbox visage, bbox main) depuis les
detections initiales, **CROP** le frame original a la region, re-encode en
JPEG haute resolution et re-execute Vision dessus. Resultat : 3-10× plus
de pixels par region → landmarks ultra precis (utile pour mouth shape,
eye blink, doigts fins).

Pour ne pas tuer le fps : cadence reduite (10 Hz vs 30 Hz du worker
principal). Les crops sont effectues dans le MEME worker que la pass
plein-cadre — c'est `apple_vision_pose.py` qui appelle FineAnalyzer.refine()
apres chaque frame ou la 3eme frame seulement.
"""
from __future__ import annotations

import logging
import time

from Foundation import NSData

from .state import PoseKp

LOG = logging.getLogger("fine_analysis")


def _bbox_from_kps(kps: list[PoseKp], pad: float = 0.10
                   ) -> tuple[float, float, float, float] | None:
    """Calcule la bbox englobant les keypoints visibles, avec padding.
    Retourne (x_min, y_min, x_max, y_max) en coordonnees normalisees 0..1.
    None si aucun kp visible."""
    pts = [(kp.x, kp.y) for kp in kps if kp.c > 0.3]
    if not pts:
        return None
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    x1, y1, x2, y2 = min(xs), min(ys), max(xs), max(ys)
    dx, dy = (x2 - x1) * pad, (y2 - y1) * pad
    return (
        max(0.0, x1 - dx), max(0.0, y1 - dy),
        min(1.0, x2 + dx), min(1.0, y2 + dy),
    )


class FineAnalyzer:
    """Re-execute Vision sur des crops haute resolution des ROIs.

    Active automatiquement quand le worker pose detecte un visage ou des
    mains. Throttle interne pour ne pas saturer ANE.
    """

    def __init__(self, ns_vision: dict, throttle_hz: float = 10.0,
                 zoom_max: float = 4.0) -> None:
        self._ns = ns_vision
        self._period = 1.0 / max(1.0, throttle_hz)
        self._last_t = 0.0
        self._zoom_max = zoom_max
        self._VNImageRequestHandler = ns_vision.get("VNImageRequestHandler")
        self._VNDetectFaceLandmarksRequest = ns_vision.get(
            "VNDetectFaceLandmarksRequest")
        self._VNDetectHumanHandPoseRequest = ns_vision.get(
            "VNDetectHumanHandPoseRequest")

    def should_refine(self, t_now: float) -> bool:
        if t_now - self._last_t < self._period:
            return False
        self._last_t = t_now
        return True

    # ------------------------------------------------------------------
    def refine_face(self, frame_bgr, persons_face: list[list[PoseKp]],
                    parse_face_fn) -> list[list[PoseKp]]:
        """Pour chaque visage detecte, crop la region, re-encode JPEG et
        relance VNDetectFaceLandmarksRequest. Remplace les kp par les
        nouveaux (re-projettes en coordonnees image complete).

        `parse_face_fn(obs, x_origin, y_origin, scale_x, scale_y)` : helper
        fourni par le worker pour parser une VNFaceObservation et retourner
        une liste de PoseKp.
        """
        if (self._VNImageRequestHandler is None or
                self._VNDetectFaceLandmarksRequest is None or
                not persons_face):
            return persons_face
        try:
            import cv2
        except ImportError:
            return persons_face

        h, w = frame_bgr.shape[:2]
        out = []
        for face_kps in persons_face:
            bbox = _bbox_from_kps(face_kps, pad=0.20)
            if bbox is None:
                out.append(face_kps); continue
            # Crop pixels
            x1 = int(bbox[0] * w); y1 = int(bbox[1] * h)
            x2 = int(bbox[2] * w); y2 = int(bbox[3] * h)
            cw, ch = x2 - x1, y2 - y1
            if cw < 60 or ch < 60:
                out.append(face_kps); continue
            crop = frame_bgr[y1:y2, x1:x2]
            # Upscale pour donner plus de pixels au detecteur (ANE accepte
            # n'importe quelle taille mais plus de detail = plus precis)
            zoom = min(self._zoom_max, 640.0 / max(cw, ch))
            if zoom > 1.0:
                crop = cv2.resize(crop, None, fx=zoom, fy=zoom,
                                  interpolation=cv2.INTER_CUBIC)
            ok, jpg = cv2.imencode(".jpg", crop,
                                   [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            if not ok:
                out.append(face_kps); continue
            jpg_bytes = bytes(jpg)
            data = NSData.dataWithBytes_length_(jpg_bytes, len(jpg_bytes))
            handler = self._VNImageRequestHandler.alloc()\
                .initWithData_options_(data, {})
            req = self._VNDetectFaceLandmarksRequest.alloc().init()
            ret = handler.performRequests_error_([req], None)
            ok2 = ret[0] if isinstance(ret, tuple) else bool(ret)
            if not ok2:
                out.append(face_kps); continue
            results = req.results() or []
            if not results:
                out.append(face_kps); continue
            # Re-projette les coords du crop vers l'image entiere
            # bbox normalisees: x_origin=bbox[0], scale_x=(bbox[2]-bbox[0])
            obs = results[0]
            new_kps = parse_face_fn(
                obs,
                x_origin=bbox[0], y_origin=bbox[1],
                scale_x=(bbox[2] - bbox[0]),
                scale_y=(bbox[3] - bbox[1]),
            )
            out.append(new_kps if new_kps else face_kps)
        return out

    # ------------------------------------------------------------------
    def refine_hands(self, frame_bgr, persons_hands: list[list[PoseKp]],
                     parse_hand_fn) -> list[list[PoseKp]]:
        """Pareil que refine_face mais pour les mains.
        `parse_hand_fn(obs, x_origin, y_origin, scale_x, scale_y)` →
        list[PoseKp] de 21 elements."""
        if (self._VNImageRequestHandler is None or
                self._VNDetectHumanHandPoseRequest is None or
                not persons_hands):
            return persons_hands
        try:
            import cv2
        except ImportError:
            return persons_hands

        h, w = frame_bgr.shape[:2]
        out = []
        for hand_kps in persons_hands:
            bbox = _bbox_from_kps(hand_kps, pad=0.30)
            if bbox is None:
                out.append(hand_kps); continue
            x1 = int(bbox[0] * w); y1 = int(bbox[1] * h)
            x2 = int(bbox[2] * w); y2 = int(bbox[3] * h)
            cw, ch = x2 - x1, y2 - y1
            if cw < 40 or ch < 40:
                out.append(hand_kps); continue
            crop = frame_bgr[y1:y2, x1:x2]
            zoom = min(self._zoom_max, 320.0 / max(cw, ch))
            if zoom > 1.0:
                crop = cv2.resize(crop, None, fx=zoom, fy=zoom,
                                  interpolation=cv2.INTER_CUBIC)
            ok, jpg = cv2.imencode(".jpg", crop,
                                   [int(cv2.IMWRITE_JPEG_QUALITY), 85])
            if not ok:
                out.append(hand_kps); continue
            jpg_bytes = bytes(jpg)
            data = NSData.dataWithBytes_length_(jpg_bytes, len(jpg_bytes))
            handler = self._VNImageRequestHandler.alloc()\
                .initWithData_options_(data, {})
            req = self._VNDetectHumanHandPoseRequest.alloc().init()
            try:
                req.setMaximumHandCount_(1)  # un crop = une main
            except Exception:
                pass
            ret = handler.performRequests_error_([req], None)
            ok2 = ret[0] if isinstance(ret, tuple) else bool(ret)
            if not ok2:
                out.append(hand_kps); continue
            results = req.results() or []
            if not results:
                out.append(hand_kps); continue
            obs = results[0]
            new_kps = parse_hand_fn(
                obs,
                x_origin=bbox[0], y_origin=bbox[1],
                scale_x=(bbox[2] - bbox[0]),
                scale_y=(bbox[3] - bbox[1]),
            )
            out.append(new_kps if new_kps else hand_kps)
        return out
