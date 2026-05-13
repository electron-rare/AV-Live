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


def resolve_camera_index(requested: int) -> int:
    """`requested=-1` -> built-in auto, sinon valeur passee."""
    if requested < 0:
        return pick_builtin_camera(fallback=0)
    return requested
