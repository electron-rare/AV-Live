"""Capture webcam via AVFoundation natif (pyobjc), sans cv2.

Resout le mismatch d'indices entre `cv2.VideoCapture(N)` et l'ordre
des devices retournes par AVCaptureDeviceDiscoverySession : on
selectionne le device par `uniqueID` ou par type
(BuiltInWideAngleCamera) au lieu d'un index opaque.

Pattern :
- AVCaptureSession + AVCaptureVideoDataOutput
- Delegate avec @objc.python_method pour la copie numpy
- Global dispatch queue (libdispatch via ctypes) — pas de main queue
  pour ne pas bloquer NSApp
- Frame BGRA -> BGR HxWx3 uint8 partagee sous lock
- API .read() compatible cv2 : (ok, frame_bgr)
"""
from __future__ import annotations

import ctypes
import logging
import threading
import time
from typing import Optional

import numpy as np
import objc

import AVFoundation as AVF
import CoreMedia as CM
import Quartz
from Foundation import NSObject

LOG = logging.getLogger("av_capture")

_DEVICE_TYPES = [
    "AVCaptureDeviceTypeBuiltInWideAngleCamera",
    "AVCaptureDeviceTypeContinuityCamera",
    "AVCaptureDeviceTypeExternal",
    "AVCaptureDeviceTypeDeskViewCamera",
]


def _get_global_queue() -> object:
    """Retourne une dispatch_queue_t globale wrappee en pyobjc object."""
    libdispatch = ctypes.CDLL("/usr/lib/system/libdispatch.dylib")
    libdispatch.dispatch_get_global_queue.restype = ctypes.c_void_p
    libdispatch.dispatch_get_global_queue.argtypes = [
        ctypes.c_long, ctypes.c_ulong]
    # 0 = DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 = flags
    q_ptr = libdispatch.dispatch_get_global_queue(0, 0)
    return objc.objc_object(c_void_p=q_ptr)


def enumerate_devices() -> list[dict]:
    """Retourne la liste des devices video disponibles avec metadata
    : uniqueID, localizedName, deviceType."""
    session = (AVF.AVCaptureDeviceDiscoverySession
        .discoverySessionWithDeviceTypes_mediaType_position_(
            _DEVICE_TYPES, "vide", 0))
    devices = list(session.devices() or [])
    out = []
    for d in devices:
        out.append({
            "uniqueID": str(d.uniqueID()),
            "name": str(d.localizedName()),
            "type": (str(d.deviceType()) if hasattr(d, "deviceType")
                     else "").split(".")[-1],
            "_device": d,
        })
    return out


_BANNED_NAME_TOKENS = ("iphone", "gsm", "desk view", "continuity")


def find_builtin_device() -> Optional[dict]:
    """Selectionne la webcam Mac integree :
    - deviceType doit etre BuiltInWideAngleCamera
    - le nom ne doit contenir aucun de _BANNED_NAME_TOKENS
    Evite les pieges Continuity/iPhone/Desk View qui peuvent matcher
    BuiltInWideAngleCamera dans certaines configs."""
    for info in enumerate_devices():
        if "BuiltInWideAngleCamera" not in info["type"]:
            continue
        name_l = info["name"].lower()
        if any(tok in name_l for tok in _BANNED_NAME_TOKENS):
            continue
        return info
    return None


class _FrameDelegate(NSObject):
    """Delegate AVCaptureVideoDataOutput. Convertit BGRA -> BGR numpy
    et stocke la derniere frame sous lock."""

    def init(self):
        self = objc.super(_FrameDelegate, self).init()
        if self is None:
            return None
        self._buf = None
        self._lock = threading.Lock()
        self._frame_count = 0
        return self

    @objc.python_method
    def get_latest(self):
        with self._lock:
            if self._buf is None:
                return False, None, self._frame_count
            return True, self._buf.copy(), self._frame_count

    def captureOutput_didOutputSampleBuffer_fromConnection_(
            self, output, sample_buffer, connection):
        try:
            self._handle_sample_buffer(sample_buffer)
        except Exception as e:  # noqa: BLE001
            LOG.warning("frame conv failed: %s", e)

    @objc.python_method
    def _handle_sample_buffer(self, sample_buffer):
        pixel_buffer = CM.CMSampleBufferGetImageBuffer(sample_buffer)
        if pixel_buffer is None:
            return
        w = Quartz.CVPixelBufferGetWidth(pixel_buffer)
        h = Quartz.CVPixelBufferGetHeight(pixel_buffer)
        Quartz.CVPixelBufferLockBaseAddress(pixel_buffer, 1)  # read-only
        try:
            base_addr = Quartz.CVPixelBufferGetBaseAddress(pixel_buffer)
            stride = Quartz.CVPixelBufferGetBytesPerRow(pixel_buffer)
            # base_addr est un objc.varlist (void* wrapper). On va via
            # as_buffer(N) qui renvoie un memoryview de N octets.
            if base_addr is None:
                return
            buf = base_addr.as_buffer(h * stride)
            arr = np.frombuffer(buf, dtype=np.uint8).reshape(
                (h, stride // 4, 4))[:, :w, :3]  # BGRA -> BGR
            with self._lock:
                self._buf = np.ascontiguousarray(arr)
                self._frame_count += 1
        finally:
            Quartz.CVPixelBufferUnlockBaseAddress(pixel_buffer, 1)


class AVCapture:
    """API minimale cv2-like sur AVFoundation. Compatible drop-in pour
    les workers qui font `cap.read()` en boucle.

    Usage :
        cap = AVCapture(device_info)  # ou AVCapture.builtin()
        cap.start()
        ok, frame_bgr = cap.read()
        cap.stop()
    """

    def __init__(self, device_info: dict) -> None:
        self._info = device_info
        self._session = None
        self._delegate = None
        self._queue = None
        self._last_count = 0

    @classmethod
    def builtin(cls) -> Optional["AVCapture"]:
        info = find_builtin_device()
        return cls(info) if info is not None else None

    def start(self) -> bool:
        device = self._info["_device"]
        session = AVF.AVCaptureSession.alloc().init()
        try:
            input_, err = (
                AVF.AVCaptureDeviceInput
                .deviceInputWithDevice_error_(device, None))
        except Exception as e:  # noqa: BLE001
            LOG.error("AVCaptureDeviceInput failed: %s", e)
            return False
        if input_ is None:
            LOG.error("input is None (err=%s)", err)
            return False
        if not session.canAddInput_(input_):
            LOG.error("session refused input")
            return False
        session.addInput_(input_)

        output = AVF.AVCaptureVideoDataOutput.alloc().init()
        settings = {
            Quartz.kCVPixelBufferPixelFormatTypeKey:
                Quartz.kCVPixelFormatType_32BGRA,
        }
        output.setVideoSettings_(settings)
        output.setAlwaysDiscardsLateVideoFrames_(True)

        delegate = _FrameDelegate.alloc().init()
        queue = _get_global_queue()
        output.setSampleBufferDelegate_queue_(delegate, queue)

        if not session.canAddOutput_(output):
            LOG.error("session refused output")
            return False
        session.addOutput_(output)

        session.startRunning()
        self._session = session
        self._delegate = delegate
        self._queue = queue
        LOG.info("AV session running on '%s' (%s)",
                 self._info["name"], self._info["type"])
        return True

    def read(self, timeout_s: float = 0.5) -> tuple[bool, Optional[np.ndarray]]:
        """Bloque jusqu'a recevoir une frame NOUVELLE (frame_count
        different du dernier read), ou timeout. Retourne (ok, BGR
        HxWx3 uint8)."""
        if self._delegate is None:
            return False, None
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            ok, frame, count = self._delegate.get_latest()
            if ok and count != self._last_count:
                self._last_count = count
                return True, frame
            time.sleep(0.01)
        # Au timeout, on renvoie quand meme la derniere frame si elle
        # existe (pour les cas FPS < target)
        ok, frame, count = self._delegate.get_latest()
        if ok:
            self._last_count = count
            return True, frame
        return False, None

    def stop(self) -> None:
        if self._session is not None:
            try:
                self._session.stopRunning()
            except Exception:
                pass
            self._session = None
        self._delegate = None
        self._queue = None
