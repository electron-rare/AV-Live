"""Envoie les vertices SMPL-X de chaque personne via TCP sur :57130.

UDP ne suffit pas : 10475 verts x 3 floats x 4 = 125 700 octets par
personne, soit > MTU 1500. TCP fragmente proprement.

Protocole binaire little-endian, par frame :
    [4: longueur payload (uint32)]
    [4: magic 'SMPX']
    [4: n_persons (int32)]
    Pour chaque personne :
        [4: pid int32][4: confidence float32]
        [12: translation (3 float32)]
        [10*4: betas (10 float32)]
        [10*4: expression (10 float32)]
        [10475*3*4 = 125700: vertices (float32 LE)]
"""
from __future__ import annotations

import logging
import socket
import struct
import threading
import time
from typing import Sequence

import numpy as np

import os

from .mesh_rigger import MeshRigger
from .state import SMPLXPerson, State

try:
    from .dino_reid import DinoReid
except Exception:  # noqa: BLE001
    DinoReid = None  # type: ignore[assignment]

LOG = logging.getLogger("smplx_tcp")

MAGIC = b"SMPX"
PORT = 57130


class SMPLXTCPSender:
    def __init__(self, state: State, host: str = "127.0.0.1",
                 port: int = PORT, target_fps: float = 30.0,
                 enable_rigging: bool = True) -> None:
        import os as _os
        self.state = state
        self.host = _os.environ.get("AVBODY_HOST", host)
        self.port = port
        self.period = 1.0 / max(1.0, target_fps)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._sock: socket.socket | None = None
        # Hybrid keyframe rigging : entre deux keyframes Multi-HMR (~3 fps),
        # on translate le mesh via le delta pelvis Apple Vision (30 fps).
        # MULTIHMR_REID: 'dino' (try DINOv2 + IoU fusion, fallback IoU) /
        # 'iou' (pure IoU). Default: 'dino' if mlpackage exists.
        reid_mode = os.environ.get("MULTIHMR_REID", "dino").lower()
        dino = None
        if enable_rigging and reid_mode == "dino" and DinoReid is not None:
            try:
                if DinoReid.is_available():
                    dino = DinoReid()
                    LOG.info("MeshRigger: DINOv2 reid enabled")
                else:
                    LOG.info(
                        "MeshRigger: dino mlpackage absent, IoU only")
            except Exception as e:  # noqa: BLE001
                LOG.warning("MeshRigger: dino load failed (%s), IoU only", e)
                dino = None
        dino_weight = float(os.environ.get("MULTIHMR_REID_ALPHA", "0.5"))
        self._rigger = MeshRigger(
            state, dino_weight=dino_weight,
            dino_reid=dino) if enable_rigging else None

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name="smplx_tcp", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._close()

    def _ensure_connected(self) -> bool:
        if self._sock is not None:
            return True
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.5)
            s.connect((self.host, self.port))
            s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            s.settimeout(1.0)  # 1 s write timeout — must be > worst-case frame transit
            self._sock = s
            LOG.info("connected to %s:%d", self.host, self.port)
            return True
        except (socket.error, ConnectionRefusedError):
            return False

    def _send_or_close(self, payload: bytes) -> bool:
        """Send *payload* (already length-prefixed) over _sock.

        Returns True on success, False on any socket error (socket is closed).
        """
        try:
            self._sock.sendall(payload)
            return True
        except socket.timeout:
            LOG.warning("smplx_tcp: send timeout — receiver stalled, dropping connection")
            self._close()
            return False
        except (BrokenPipeError, ConnectionResetError, OSError) as e:
            LOG.warning("smplx_tcp: send failed (%s) — reconnecting", e)
            self._close()
            return False

    def _close(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    @staticmethod
    def _pad10(arr: "np.ndarray") -> "np.ndarray":
        """Return a contiguous float32 array of length 10, zero-padded if shorter."""
        flat = np.ascontiguousarray(arr, dtype="<f4").ravel()
        if len(flat) >= 10:
            return flat[:10]
        out = np.zeros(10, dtype="<f4")
        out[:len(flat)] = flat
        return out

    @staticmethod
    def _serialize_persons(persons: Sequence[SMPLXPerson]) -> bytes:
        buf = bytearray()
        buf += MAGIC
        buf += struct.pack("<i", len(persons))
        for p in persons:
            buf += struct.pack("<i", p.pid)
            buf += struct.pack("<f", float(p.confidence))
            trans = np.ascontiguousarray(p.translation, dtype="<f4").ravel()
            if len(trans) < 3:
                t3 = np.zeros(3, dtype="<f4")
                t3[:len(trans)] = trans
                trans = t3
            buf += trans[:3].tobytes()
            buf += SMPLXTCPSender._pad10(p.betas).tobytes()
            buf += SMPLXTCPSender._pad10(p.expression).tobytes()
            buf += np.ascontiguousarray(p.vertices_3d, dtype="<f4").tobytes()
        return bytes(buf)

    def _run(self) -> None:
        last_warn = 0.0
        n_sent = 0
        n_rigged = 0
        next_hb = time.monotonic() + 5.0
        while not self._stop.is_set():
            t0 = time.monotonic()
            if not self._ensure_connected():
                if t0 - last_warn > 5.0:
                    LOG.warning("RealityKit app pas connectee (%s:%d)",
                                self.host, self.port)
                    last_warn = t0
                time.sleep(1.0)
                continue

            with self.state.lock():
                persons = list(self.state.persons_smplx)
                body_kp = list(self.state.persons_body) if hasattr(
                    self.state, "persons_body") else []
                body_ids = list(self.state.persons_body_ids) if hasattr(
                    self.state, "persons_body_ids") else (
                    list(range(len(body_kp))) if body_kp else [])

            if persons and self._rigger is not None:
                rigged = self._rigger.apply(
                    persons, body_kp, body_ids, t0)
                if rigged is not persons:
                    n_rigged += 1
                persons = rigged

            if t0 >= next_hb:
                fps = n_sent / 5.0
                rig_pct = (n_rigged / n_sent * 100.0) if n_sent else 0.0
                LOG.info("hb: %.1f fps tcp, %.0f%% rigged",
                         fps, rig_pct)
                n_sent = 0
                n_rigged = 0
                next_hb = t0 + 5.0

            if persons:
                n_sent += 1
                t_ser_start = time.monotonic()
                payload = self._serialize_persons(persons)
                t_send_start = time.monotonic()
                if not self._send_or_close(
                        struct.pack("<I", len(payload)) + payload):
                    continue
                t_send_end = time.monotonic()
                dt_tcp = (t_send_end - t_ser_start) * 1e3
                if LOG.isEnabledFor(logging.DEBUG) or dt_tcp > 20.0:
                    LOG.log(
                        logging.DEBUG if dt_tcp <= 20.0 else logging.WARNING,
                        "tcp: ser=%.1f send=%.1fms",
                        (t_send_start - t_ser_start) * 1e3,
                        (t_send_end - t_send_start) * 1e3,
                    )

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
