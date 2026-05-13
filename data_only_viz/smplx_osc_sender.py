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

from .state import SMPLXPerson, State

LOG = logging.getLogger("smplx_tcp")

MAGIC = b"SMPX"
PORT = 57130


class SMPLXTCPSender:
    def __init__(self, state: State, host: str = "127.0.0.1",
                 port: int = PORT, target_fps: float = 12.0) -> None:
        self.state = state
        self.host = host
        self.port = port
        self.period = 1.0 / max(1.0, target_fps)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._sock: socket.socket | None = None

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

    def _close(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    @staticmethod
    def _serialize_persons(persons: Sequence[SMPLXPerson]) -> bytes:
        buf = bytearray()
        buf += MAGIC
        buf += struct.pack("<i", len(persons))
        for p in persons:
            buf += struct.pack("<i", p.pid)
            buf += struct.pack("<f", float(p.confidence))
            tx, ty, tz = (p.translation + (0.0, 0.0, 0.0))[:3]
            buf += struct.pack("<fff", float(tx), float(ty), float(tz))
            betas = list(p.betas[:10]) + [0.0] * max(0, 10 - len(p.betas))
            for b in betas[:10]:
                buf += struct.pack("<f", float(b))
            expr = list(p.expression[:10]) + [0.0] * max(0, 10 - len(p.expression))
            for e in expr[:10]:
                buf += struct.pack("<f", float(e))
            for vx, vy, vz in p.vertices_3d:
                buf += struct.pack("<fff", float(vx), float(vy), float(vz))
        return bytes(buf)

    def _run(self) -> None:
        last_warn = 0.0
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

            if persons:
                payload = self._serialize_persons(persons)
                try:
                    self._sock.sendall(
                        struct.pack("<I", len(payload)) + payload)
                except socket.timeout:
                    LOG.warning("smplx_tcp: send timeout — receiver stalled, dropping connection")
                    self._close()
                    continue
                except (BrokenPipeError, ConnectionResetError, OSError) as e:
                    LOG.warning("smplx_tcp: send failed (%s) — reconnecting", e)
                    self._close()
                    continue

            dt = time.monotonic() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
