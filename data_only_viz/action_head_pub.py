"""Action-head publisher : reads state.persons_smplx / persons_body3d,
runs ActionHead per pid, emits /pose/action and /pose/kin via pose_bridge.

Stand-alone thread to avoid touching multi_hmr_worker.py while it
iterates. Polls state at ~30 Hz, deduplicates by smplx_last_t.
"""
from __future__ import annotations

import logging
import threading
import time
from pathlib import Path
from typing import Any

import numpy as np

from data_only_viz.action_head import ActionHead, LABELS

LOG = logging.getLogger("action_head_pub")

DEFAULT_CKPT = (
    Path.home() / ".cache" / "av-live-action" / "checkpoints" / "action_head.pt"
)

# 22 vertex indices on the 10475-vertex SMPL-X mesh, approximating
# the 22-joint kinematic chain used by ActionHead.
# NOTE: approximate vertex anchors — real SMPL-X joints come from
# J_regressor @ v3d, but loading the regressor here is avoided for
# live OSC performance. Action-head training must use the same anchors.
SMPLX_JOINT_ANCHOR_VERTS: tuple[int, ...] = (
    8204, 3992, 6677, 3500, 3469, 6394, 3279, 3327, 6736, 3074,
    8846, 8889, 8848, 1300, 4660, 8964, 3013, 6470, 1602, 5083,
    2114, 5559,
)

# MediaPipe 33-landmark indices mapped into the 22-joint slot order.
# NOTE: approximate mapping — spine joints reuse hip/shoulder anchors.
# https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
MEDIAPIPE_TO_22: tuple[int, ...] = (
    24, 23, 24, 23, 25, 26, 11, 27, 28, 11,
    31, 32, 0, 11, 12, 0, 11, 12, 13, 14, 15, 16,
)


class ActionHeadPublisher(threading.Thread):
    """Thread that polls state, runs ActionHead per pid, emits OSC."""

    def __init__(self, state: Any, bridge: Any,
                 ckpt_path: Path | None = DEFAULT_CKPT,
                 period_s: float = 1.0 / 30.0) -> None:
        super().__init__(daemon=True, name="action-head-pub")
        self.state = state
        self.bridge = bridge
        self.period = period_s
        try:
            ckpt = ckpt_path if (ckpt_path and ckpt_path.exists()) else None
            self.head = ActionHead(ckpt_path=ckpt, device="cpu")
            LOG.info("action_head loaded ckpt=%s",
                     ckpt if ckpt else "<random init>")
        except Exception as e:
            LOG.warning("action_head init failed: %s", e)
            self.head = None
        self._stop = threading.Event()
        self._last_smplx_t = 0.0
        self._last_body_t = 0.0
        self._last_pids: set[int] = set()

    def stop(self) -> None:
        self._stop.set()

    def run(self) -> None:
        if self.head is None:
            LOG.warning("publisher exiting: no action_head")
            return
        LOG.info("publisher started")
        while not self._stop.is_set():
            t0 = time.perf_counter()
            try:
                self._tick(t0)
            except Exception:
                LOG.exception("publisher tick failed")
            dt = time.perf_counter() - t0
            if dt < self.period:
                time.sleep(self.period - dt)
        LOG.info("publisher stopped")

    def _tick(self, t_now: float) -> None:
        persons22, source_t, source_tag, is_new = self._read_sources()
        if not is_new:
            return
        if "smplx" in source_tag:
            self._last_smplx_t = source_t
        else:
            self._last_body_t = source_t
        current_pids: set[int] = set()
        if persons22:
            for pid, j3d in persons22:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d)
                idx = LABELS.index(label)
                self.bridge.send_action(pid, idx, probs, t_now, force=True)
                self.bridge.send_kin(pid, kin, t_now, force=True)
                if pid not in self._last_pids:
                    self.bridge.send_enter(pid=pid)
        for gone in self._last_pids - current_pids:
            self.head.forget(gone)
            self.bridge.send_leave(pid=gone)
        self._last_pids = current_pids

    def _read_sources(
        self,
    ) -> tuple[list[tuple[int, np.ndarray]] | None, float, str, bool]:
        """Return (persons22, source_t, source_tag, is_new).

        is_new is True when the timestamp advanced (even if person list
        is empty), so _tick can still run the purge loop.
        """
        with self.state.lock():
            persons_smplx = getattr(self.state, "persons_smplx", None)
            t_smplx = getattr(self.state, "smplx_last_t", 0.0)
            persons_b3d = getattr(self.state, "persons_body3d", None)
            ids_b3d = getattr(self.state, "persons_body_ids", None)
            t_body = getattr(self.state, "pose_last_t", 0.0)
        # Prefer smplx when its timestamp advanced.
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray]] = []
            for i, p in enumerate(persons_smplx or []):
                pid = int(p.get("pid", i))
                v3d = p.get("v3d")
                if v3d is None:
                    continue
                v3d_np = np.asarray(v3d, dtype=np.float32)
                if v3d_np.shape[0] < max(SMPLX_JOINT_ANCHOR_VERTS) + 1:
                    continue
                j3d22 = v3d_np[list(SMPLX_JOINT_ANCHOR_VERTS)].astype(np.float32)
                out.append((pid, j3d22))
            return out or None, t_smplx, "smplx", True
        if t_body > self._last_body_t:
            ids = ids_b3d or list(range(len(persons_b3d or [])))
            out = []
            for i, body in enumerate(persons_b3d or []):
                pid = int(ids[i]) if i < len(ids) else i
                arr = self._kp_list_to_array(body)
                if arr is None or arr.shape[0] < 33:
                    continue
                j3d22 = arr[list(MEDIAPIPE_TO_22)].astype(np.float32)
                out.append((pid, j3d22))
            return out or None, t_body, "body3d", True
        return None, 0.0, "", False

    @staticmethod
    def _kp_list_to_array(body: Any) -> np.ndarray | None:
        """Best-effort conversion of a body keypoint list to (N, 3) array."""
        if body is None:
            return None
        if isinstance(body, np.ndarray):
            return body
        try:
            return np.asarray(
                [
                    (
                        getattr(kp, "x", kp[0]),
                        getattr(kp, "y", kp[1]),
                        getattr(kp, "z", kp[2] if len(kp) > 2 else 0.0),
                    )
                    for kp in body
                ],
                dtype=np.float32,
            )
        except (TypeError, IndexError, AttributeError):
            return None
