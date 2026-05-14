"""Threaded wrapper that polls State and calls FusionWorker.run_once.

ICP fusion runs as a background thread parallel to the autonomous
Multi-HMR worker. It pulls the latest LiDAR frame from a
LidarTCPReader, stages it into State, and applies in-place ICP
registration to ``state.persons_smplx[*].vertices_3d``.

Opt-in via ``ICP_FUSION=1`` from main.py.
"""
from __future__ import annotations

import logging
import threading
import time
from typing import Optional

from .icp_fusion import FusionWorker, IcpConfig
from .lidar_calib import load_extrinsic
from .lidar_receiver import LidarTCPReader

_LOG = logging.getLogger(__name__)


class IcpFusionThread:
    """Background thread: pull LiDAR frames, run FusionWorker on state."""

    def __init__(self, state, host: str, port: int,
                 target_hz: float = 8.0) -> None:
        self._state = state
        self._reader = LidarTCPReader(host=host, port=port)
        self._worker = FusionWorker(extrinsic=load_extrinsic(),
                                    config=IcpConfig())
        self._period_s = 1.0 / max(target_hz, 0.5)
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        if self._thread is not None:
            return
        self._reader.start()
        self._thread = threading.Thread(
            target=self._run, name="icp-fusion", daemon=True)
        self._thread.start()
        _LOG.info("icp-fusion thread started")

    def stop(self) -> None:
        self._stop.set()
        self._reader.stop()
        if self._thread is not None:
            self._thread.join(timeout=2.0)
            self._thread = None

    def _run(self) -> None:
        while not self._stop.is_set():
            t0 = time.monotonic()
            frame = self._reader.latest()
            if frame is not None and self._state.persons_smplx:
                # State doesn't expose a fine-grained lock for these
                # fields here; rely on FusionWorker.run_once being
                # write-only on persons_smplx[*].vertices_3d (replace in
                # place) and the readers being tolerant of mid-update.
                self._state.lidar_points = frame.points
                self._state.lidar_timestamp_ns = frame.timestamp_ns
                try:
                    self._state.icp_metadata = self._worker.run_once(
                        self._state)
                except Exception as exc:  # noqa: BLE001
                    _LOG.warning("icp fusion failed: %s", exc)
                    self._state.icp_metadata = None
            elapsed = time.monotonic() - t0
            if self._stop.wait(max(0.0, self._period_s - elapsed)):
                return
