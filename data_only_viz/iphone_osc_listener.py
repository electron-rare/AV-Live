"""OSC UDP listener for the iOS ARBodyTracker app.

Subscribes to /body3d/kp on UDP :57128 (distinct from MediaPipe
output :57126). Each /body3d/kp pid joint_idx x y z message stores
one joint of ARKit's 91-joint ARSkeleton3D into
state.persons_arkit_joints[pid] (np.ndarray shape (91, 3), float32).
A background GC drops pids whose last_t is older than 1.0 s.

Worker pattern mirrors osc_listener.OscListener.
"""
from __future__ import annotations

import logging
import threading
import time
from typing import Any

import numpy as np
from pythonosc import dispatcher, osc_server

from .state import State

LOG = logging.getLogger("iphone_osc")

IPHONE_OSC_PORT = 57128
ARKIT_NUM_JOINTS = 91
STALE_SEC = 1.0


class IphoneOSCListener:
    def __init__(self, state: State, host: str = "0.0.0.0",
                 port: int = IPHONE_OSC_PORT) -> None:
        self.state = state
        self.host = host
        self.port = port
        self._server: osc_server.ThreadingOSCUDPServer | None = None
        self._server_thread: threading.Thread | None = None
        self._gc_thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._last_hb: float = 0.0

    def start(self) -> None:
        d = dispatcher.Dispatcher()
        d.map("/body3d/kp", self._on_kp)
        d.map("/body3d/count", self._on_count)
        self._server = osc_server.ThreadingOSCUDPServer(
            (self.host, self.port), d)
        self._server_thread = threading.Thread(
            target=self._server.serve_forever,
            name="iphone_osc", daemon=True)
        self._server_thread.start()
        self._gc_thread = threading.Thread(
            target=self._gc_loop, name="iphone_gc", daemon=True)
        self._gc_thread.start()
        LOG.info("iphone OSC listening on %s:%d", self.host, self.port)

    def stop(self) -> None:
        self._stop.set()
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server = None
        if self._server_thread is not None:
            self._server_thread.join(timeout=2.0)
            self._server_thread = None
        if self._gc_thread is not None:
            self._gc_thread.join(timeout=2.0)
            self._gc_thread = None

    def _on_kp(self, _addr: str, *args: Any) -> None:
        if len(args) < 5:
            return
        try:
            pid = int(args[0])
            joint_idx = int(args[1])
            x = float(args[2])
            y = float(args[3])
            z = float(args[4])
        except (TypeError, ValueError):
            return
        if not (0 <= joint_idx < ARKIT_NUM_JOINTS):
            return
        with self.state.lock():
            arr = self.state.persons_arkit_joints.get(pid)
            if arr is None or arr.shape != (ARKIT_NUM_JOINTS, 3):
                arr = np.zeros((ARKIT_NUM_JOINTS, 3), dtype=np.float32)
                self.state.persons_arkit_joints[pid] = arr
            arr[joint_idx] = (x, y, z)
            self.state.persons_arkit_last_t[pid] = time.perf_counter()

    def _on_count(self, _addr: str, *args: Any) -> None:
        # Optional : we currently don't gate on count, but parse for log.
        if not args:
            return
        try:
            n = int(args[0])
        except (TypeError, ValueError):
            return
        now = time.monotonic()
        if now - self._last_hb > 5.0:
            self._last_hb = now
            LOG.info("hb: %d ARKit bodies live", n)

    def _gc_stale(self) -> None:
        cutoff = time.perf_counter() - STALE_SEC
        with self.state.lock():
            drop = [
                pid for pid, t in self.state.persons_arkit_last_t.items()
                if t < cutoff
            ]
            for pid in drop:
                self.state.persons_arkit_joints.pop(pid, None)
                self.state.persons_arkit_last_t.pop(pid, None)

    def _gc_loop(self) -> None:
        while not self._stop.is_set():
            self._gc_stale()
            time.sleep(0.5)
