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

from data_only_viz.action_head import (
    ActionHead,
    EXPR_DIM,
    J3D_FINGERS,
    J3D_FINGERS_PER_HAND,
    LABELS,
)

LOG = logging.getLogger("action_head_pub")

DEFAULT_CKPT = (
    Path.home() / ".cache" / "av-live-action" / "checkpoints" / "action_head.pt"
)

# Approximate fingertip vertex indices on SMPL-X 10475-vert mesh.
# Order: L thumb, L index, L middle, L ring, L pinky,
#        R thumb, R index, R middle, R ring, R pinky.
SMPLX_FINGERTIP_VERTS: tuple[int, ...] = (
    7174, 7397, 7670, 7942, 8214,   # L
    4631, 4854, 5127, 5399, 5671,   # R
)

# 32 vertex indices on the 10475-vertex SMPL-X mesh:
# 22 body (UNCHANGED from v1) + 10 fingertips.
# NOTE: approximate vertex anchors -- real SMPL-X joints come from
# J_regressor @ v3d, but loading the regressor here is avoided for
# live OSC performance. Action-head training must use the same anchors.
SMPLX_JOINT_ANCHOR_VERTS: tuple[int, ...] = (
    # 22 body (UNCHANGED indices, same vertex IDs as before)
    8204, 3992, 6677, 3500, 3469, 6394, 3279, 3327, 6736, 3074,
    8846, 8889, 8848, 1300, 4660, 8964, 3013, 6470, 1602, 5083,
    2114, 5559,
    # 10 fingertips
    *SMPLX_FINGERTIP_VERTS,
)
assert len(SMPLX_JOINT_ANCHOR_VERTS) == 32

# Mouth-open: distance between two lip vertices on SMPL-X mesh.
# vert 8970 (upper outer lip), 8855 (lower outer lip) -- approximate.
SMPLX_UPPER_LIP_VERT: int = 8970
SMPLX_LOWER_LIP_VERT: int = 8855

# MediaPipe HAND fingertip indices (21-kp hand model).
MEDIAPIPE_HAND_FINGERTIPS: tuple[int, ...] = (4, 8, 12, 16, 20)

# MediaPipe 33-landmark indices mapped into the 22-joint slot order.
# NOTE: approximate mapping -- spine joints reuse hip/shoulder anchors.
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
        persons32, source_t, source_tag, is_new = self._read_sources()
        if not is_new:
            return
        if "smplx" in source_tag:
            self._last_smplx_t = source_t
        else:
            self._last_body_t = source_t
        current_pids: set[int] = set()
        if persons32:
            for pid, j3d, expr, mouth in persons32:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d,
                                                   expr=expr,
                                                   mouth_open=mouth)
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
    ) -> tuple[list[tuple[int, np.ndarray, np.ndarray, float]] | None,
               float, str, bool]:
        """Return (persons32, source_t, source_tag, is_new).

        Each person entry is (pid, j3d32, expr10, mouth_open).
        is_new is True when the timestamp advanced (even if person list
        is empty), so _tick can still run the purge loop.
        """
        with self.state.lock():
            persons_smplx = getattr(self.state, "persons_smplx", None)
            t_smplx = getattr(self.state, "smplx_last_t", 0.0)
            persons_b3d = getattr(self.state, "persons_body3d", None)
            ids_b3d = getattr(self.state, "persons_body_ids", None)
            t_body = getattr(self.state, "pose_last_t", 0.0)
            hands_ids = list(getattr(self.state, "persons_hands_ids", None) or [])
            hands_lists = list(getattr(self.state, "persons_hands", None) or [])
        # Prefer smplx when its timestamp advanced.
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray, np.ndarray, float]] = []
            for i, p in enumerate(persons_smplx or []):
                pid = int(p.get("pid", i))
                v3d = p.get("v3d")
                if v3d is None:
                    continue
                # CoreMLArray wraps a numpy array but has no __array__
                # protocol; unwrap via .numpy() before np.asarray.
                if hasattr(v3d, "numpy") and not isinstance(v3d, np.ndarray):
                    v3d = v3d.numpy()
                v3d_np = np.asarray(v3d, dtype=np.float32)
                if v3d_np.shape[0] < max(SMPLX_JOINT_ANCHOR_VERTS) + 1:
                    continue
                j3d32 = v3d_np[list(SMPLX_JOINT_ANCHOR_VERTS)].astype(np.float32)
                # expression
                expr = p.get("expression")
                if expr is not None:
                    if hasattr(expr, "numpy") and not isinstance(expr, np.ndarray):
                        expr = expr.numpy()
                    expr_np = np.asarray(expr, dtype=np.float32).flatten()
                else:
                    expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
                # mouth_open
                if v3d_np.shape[0] > max(SMPLX_UPPER_LIP_VERT, SMPLX_LOWER_LIP_VERT):
                    mouth = float(np.linalg.norm(
                        v3d_np[SMPLX_UPPER_LIP_VERT] - v3d_np[SMPLX_LOWER_LIP_VERT]
                    ))
                else:
                    mouth = 0.0
                out.append((pid, j3d32, expr_np, mouth))
            return out or None, t_smplx, "smplx", True
        if t_body > self._last_body_t:
            ids = ids_b3d or list(range(len(persons_b3d or [])))
            # Build hands lookup by pid
            hands_by_pid: dict[int, dict[str, Any]] = {}
            for hi, hkp in enumerate(hands_lists):
                hpid = int(hands_ids[hi]) if hi < len(hands_ids) else hi
                side = "L" if hi % 2 == 0 else "R"
                hands_by_pid.setdefault(hpid, {})[side] = hkp
            out = []
            for i, body in enumerate(persons_b3d or []):
                pid = int(ids[i]) if i < len(ids) else i
                arr = self._kp_list_to_array(body)
                if arr is None or arr.shape[0] < 33:
                    continue
                body22 = arr[list(MEDIAPIPE_TO_22)].astype(np.float32)
                # fingertips from hands if available
                tips = np.zeros((J3D_FINGERS, 3), dtype=np.float32)
                hpair = hands_by_pid.get(pid, {})
                for side_idx, side in enumerate(("L", "R")):
                    hkp = hpair.get(side)
                    if hkp is None:
                        continue
                    hkp_arr = self._kp_list_to_array(hkp)
                    if hkp_arr is None or hkp_arr.shape[0] < 21:
                        continue
                    for k, mp_idx in enumerate(MEDIAPIPE_HAND_FINGERTIPS):
                        tips[side_idx * J3D_FINGERS_PER_HAND + k] = hkp_arr[mp_idx]
                j3d32 = np.concatenate([body22, tips], axis=0)
                expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
                mouth = 0.0
                out.append((pid, j3d32, expr_np, mouth))
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
