"""Helper de selection de camera macOS : enumere les devices via
AVFoundation et retourne l'index OpenCV qui correspond a la webcam
built-in (BuiltInWideAngleCamera), en evitant Continuity Camera
(iPhone), Desk View, et External."""
from __future__ import annotations

import logging
from typing import Iterable

LOG = logging.getLogger("camera_select")


def list_cameras() -> list[tuple[int, str, str]]:
    """Retourne [(index, localized_name, device_type_short), ...]."""
    try:
        import objc
        from Foundation import NSBundle
        b = NSBundle.bundleWithPath_(
            "/System/Library/Frameworks/AVFoundation.framework")
        b.load()
        ns: dict = {}
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
        result = []
        for i, d in enumerate(devices):
            name = str(d.localizedName())
            dtype = str(d.deviceType() if hasattr(d, "deviceType") else "")
            result.append((i, name, dtype.split(".")[-1]))
        return result
    except Exception as e:  # noqa: BLE001
        LOG.warning("camera enum failed: %s", e)
        return []


def pick_builtin_camera(fallback: int = 0) -> int:
    """Retourne l'index du BuiltInWideAngleCamera, sinon fallback."""
    devices = list_cameras()
    for i, name, dtype in devices:
        LOG.info("camera [%d] %s (%s)", i, name, dtype)
    for i, _, dtype in devices:
        if "BuiltInWideAngleCamera" in dtype:
            LOG.info("camera Mac built-in -> index %d", i)
            return i
    return fallback


def probe_cv2_indices(max_idx: int = 4) -> list[tuple[int, int, int, float]]:
    """Pour chaque index cv2 0..max_idx, retourne (idx, w, h, mean) ou
    None pour les indices indisponibles. Le 'mean' est la luminance
    moyenne d'une frame — un capture standby (iPhone verrouille,
    Continuity inactive) a mean ~0-30 ; une cam active ~80+."""
    try:
        import cv2
        import numpy as np
    except ImportError:
        return []
    result = []
    for idx in range(max_idx):
        cap = cv2.VideoCapture(idx, cv2.CAP_AVFOUNDATION)
        if not cap.isOpened():
            cap.release()
            continue
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        # Drain 2 frames pour passer l'auto-exposure
        for _ in range(2):
            cap.read()
        ok, frame = cap.read()
        mean = float(np.mean(frame)) if (ok and frame is not None) else -1.0
        result.append((idx, w, h, mean))
        cap.release()
    return result


def resolve_camera_index(requested: int, min_mean: float = 50.0) -> int:
    """`requested=-1` -> probe cv2, prefere l'index avec frame_mean
    >= min_mean (rejette les flux noirs / standby). Sinon retourne
    `requested`."""
    if requested >= 0:
        return requested
    probes = probe_cv2_indices()
    for idx, w, h, mean in probes:
        LOG.info("cv2 probe [%d] %dx%d mean=%.1f", idx, w, h, mean)
    bright = [p for p in probes if p[3] >= min_mean]
    if bright:
        idx = bright[0][0]
        LOG.info("cv2 auto-pick index %d (mean %.1f >= %.1f)",
                 idx, bright[0][3], min_mean)
        return idx
    if probes:
        LOG.warning("no bright cv2 stream — defaulting to index %d",
                    probes[0][0])
        return probes[0][0]
    return 0
