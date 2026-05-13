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
<<<<<<< HEAD
<<<<<<< HEAD
    HANDS_KP_DIMS,
    HANDS_KP_PER_HAND,
    HANDS_KP_TOTAL,
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
    HANDS_KP_DIMS,
    HANDS_KP_PER_HAND,
    HANDS_KP_TOTAL,
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
    J3D_FINGERS,
    J3D_FINGERS_PER_HAND,
    LABELS,
)

LOG = logging.getLogger("action_head_pub")

DEFAULT_CKPT = (
    Path.home() / ".cache" / "av-live-action" / "checkpoints" / "action_head.pt"
)

<<<<<<< HEAD
<<<<<<< HEAD
# Canonical SMPL-X fingertip vertex IDs from smplx.vertex_ids.SMPLX_VERTEX_IDS.
# Order : L thumb, L index, L middle, L ring, L pinky,
#         R thumb, R index, R middle, R ring, R pinky.
SMPLX_FINGERTIP_VERTS: tuple[int, ...] = (
    5361, 4933, 5058, 5169, 5286,   # L : lthumb, lindex, lmiddle, lring, lpinky
    8079, 7669, 7794, 7905, 8022,   # R : rthumb, rindex, rmiddle, rring, rpinky
=======
# Approximate fingertip vertex indices on SMPL-X 10475-vert mesh.
# Order: L thumb, L index, L middle, L ring, L pinky,
#        R thumb, R index, R middle, R ring, R pinky.
SMPLX_FINGERTIP_VERTS: tuple[int, ...] = (
    7174, 7397, 7670, 7942, 8214,   # L
    4631, 4854, 5127, 5399, 5671,   # R
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
# Canonical SMPL-X fingertip vertex IDs from smplx.vertex_ids.SMPLX_VERTEX_IDS.
# Order : L thumb, L index, L middle, L ring, L pinky,
#         R thumb, R index, R middle, R ring, R pinky.
SMPLX_FINGERTIP_VERTS: tuple[int, ...] = (
    5361, 4933, 5058, 5169, 5286,   # L : lthumb, lindex, lmiddle, lring, lpinky
    8079, 7669, 7794, 7905, 8022,   # R : rthumb, rindex, rmiddle, rring, rpinky
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
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

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
# MediaPipe FaceMesh inner-mouth landmark indices.
# 13 = upper inner mid, 14 = lower inner mid.
MEDIAPIPE_LIP_UPPER_INNER: int = 13
MEDIAPIPE_LIP_LOWER_INNER: int = 14

<<<<<<< HEAD
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
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
<<<<<<< HEAD
<<<<<<< HEAD
            for pid, j3d, expr_np, mouth, hands_kp42 in persons32:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d, expr=expr_np,
                                                    mouth_open=mouth,
                                                    hands_kp=hands_kp42)
=======
            for pid, j3d, expr, mouth in persons32:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d,
                                                   expr=expr,
                                                   mouth_open=mouth)
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
            for pid, j3d, expr_np, mouth, hands_kp42 in persons32:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d, expr=expr_np,
                                                    mouth_open=mouth,
                                                    hands_kp=hands_kp42)
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                idx = LABELS.index(label)
                self.bridge.send_action(pid, idx, probs, t_now, force=True)
                self.bridge.send_kin(pid, kin, t_now, force=True)
                if pid not in self._last_pids:
                    self.bridge.send_enter(pid=pid)
        for gone in self._last_pids - current_pids:
            self.head.forget(gone)
            self.bridge.send_leave(pid=gone)
        self._last_pids = current_pids

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
    def _read_sources(self) -> tuple[
        list[tuple[int, np.ndarray, np.ndarray, float, np.ndarray]] | None,
        float, str, bool,
    ]:
<<<<<<< HEAD
        """Return (persons32, source_t, source_tag, is_new).

        Each person entry is (pid, j3d32, expr10, mouth_open, hands_kp42x3).
=======
    def _read_sources(
        self,
    ) -> tuple[list[tuple[int, np.ndarray, np.ndarray, float]] | None,
               float, str, bool]:
        """Return (persons32, source_t, source_tag, is_new).

        Each person entry is (pid, j3d32, expr10, mouth_open).
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
        """Return (persons32, source_t, source_tag, is_new).

        Each person entry is (pid, j3d32, expr10, mouth_open, hands_kp42x3).
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        is_new is True when the timestamp advanced (even if person list
        is empty), so _tick can still run the purge loop.
        """
        with self.state.lock():
            persons_smplx = getattr(self.state, "persons_smplx", None)
            t_smplx = getattr(self.state, "smplx_last_t", 0.0)
            persons_b3d = getattr(self.state, "persons_body3d", None)
            ids_b3d = getattr(self.state, "persons_body_ids", None)
            persons_face = getattr(self.state, "persons_face", None)
            ids_face = getattr(self.state, "persons_face_ids", None)
            persons_hands = getattr(self.state, "persons_hands", None)
            ids_hands = getattr(self.state, "persons_hands_ids", None)
            t_body = getattr(self.state, "pose_last_t", 0.0)
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)

        # Build pid -> hands_kp(42, 3) map from MediaPipe persons_hands.
        hands_by_pid: dict[int, np.ndarray] = self._build_hands_map(
            persons_hands or [], ids_hands or [],
        )
        # Build pid -> mouth_open scalar from MediaPipe persons_face lips.
        face_mouth_by_pid: dict[int, float] = self._build_face_mouth_map(
            persons_face or [], ids_face or [],
        )

        # SMPL-X path (preferred)
<<<<<<< HEAD
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray, np.ndarray, float, np.ndarray]] = []
=======
            hands_ids = list(getattr(self.state, "persons_hands_ids", None) or [])
            hands_lists = list(getattr(self.state, "persons_hands", None) or [])
        # Prefer smplx when its timestamp advanced.
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray, np.ndarray, float]] = []
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray, np.ndarray, float, np.ndarray]] = []
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
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
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                # mouth_open: prefer MediaPipe face lips, fallback SMPL-X v3d.
                if pid in face_mouth_by_pid:
                    mouth = face_mouth_by_pid[pid]
                elif v3d_np.shape[0] > max(SMPLX_UPPER_LIP_VERT, SMPLX_LOWER_LIP_VERT):
<<<<<<< HEAD
=======
                # mouth_open
                if v3d_np.shape[0] > max(SMPLX_UPPER_LIP_VERT, SMPLX_LOWER_LIP_VERT):
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                    mouth = float(np.linalg.norm(
                        v3d_np[SMPLX_UPPER_LIP_VERT] - v3d_np[SMPLX_LOWER_LIP_VERT]
                    ))
                else:
                    mouth = 0.0
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                hands_kp42 = hands_by_pid.get(
                    pid, np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
                )
                out.append((pid, j3d32, expr_np, mouth, hands_kp42))
<<<<<<< HEAD
=======
                out.append((pid, j3d32, expr_np, mouth))
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
            return out or None, t_smplx, "smplx", True

        # MediaPipe body3d fallback
        if t_body > self._last_body_t:
            ids = ids_b3d or list(range(len(persons_b3d or [])))
            out = []
            for i, body in enumerate(persons_b3d or []):
                pid = int(ids[i]) if i < len(ids) else i
                arr = self._kp_list_to_array(body)
                if arr is None or arr.shape[0] < 33:
                    continue
                body22 = arr[list(MEDIAPIPE_TO_22)].astype(np.float32)
<<<<<<< HEAD
<<<<<<< HEAD
                # fingertips from persons_hands if available
                tips = np.zeros((J3D_FINGERS, 3), dtype=np.float32)
                hands_kp42 = hands_by_pid.get(
                    pid, np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
                )
                # extract fingertips from hands_kp42 (idx 4,8,12,16,20 each side)
                for side_idx in (0, 1):
                    base = side_idx * HANDS_KP_PER_HAND
                    for k, mp_tip in enumerate(MEDIAPIPE_HAND_FINGERTIPS):
                        if base + mp_tip < hands_kp42.shape[0]:
                            tips[side_idx * J3D_FINGERS_PER_HAND + k] = \
                                hands_kp42[base + mp_tip]
                j3d32 = np.concatenate([body22, tips], axis=0)
                mouth = face_mouth_by_pid.get(pid, 0.0)
                expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
                out.append((pid, j3d32, expr_np, mouth, hands_kp42))
=======
                # fingertips from hands if available
=======
                # fingertips from persons_hands if available
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
                tips = np.zeros((J3D_FINGERS, 3), dtype=np.float32)
                hands_kp42 = hands_by_pid.get(
                    pid, np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
                )
                # extract fingertips from hands_kp42 (idx 4,8,12,16,20 each side)
                for side_idx in (0, 1):
                    base = side_idx * HANDS_KP_PER_HAND
                    for k, mp_tip in enumerate(MEDIAPIPE_HAND_FINGERTIPS):
                        if base + mp_tip < hands_kp42.shape[0]:
                            tips[side_idx * J3D_FINGERS_PER_HAND + k] = \
                                hands_kp42[base + mp_tip]
                j3d32 = np.concatenate([body22, tips], axis=0)
                mouth = face_mouth_by_pid.get(pid, 0.0)
                expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
<<<<<<< HEAD
                mouth = 0.0
                out.append((pid, j3d32, expr_np, mouth))
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
                out.append((pid, j3d32, expr_np, mouth, hands_kp42))
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
            return out or None, t_body, "body3d", True
        return None, 0.0, "", False

    def _build_hands_map(self, persons_hands: list,
                          ids_hands: list) -> dict[int, np.ndarray]:
        """Combine left+right hand kp arrays per pid into a single (42, 3) array.

        persons_hands is a flat list ; ids_hands maps each hand-list entry to a
        pid (and odd/even index indicates which side). When the user's pipeline
        keeps a different convention, this helper makes the best effort and
        pads zeros for missing sides.
        """
        out: dict[int, np.ndarray] = {}
        for hi, hkp in enumerate(persons_hands):
            if hkp is None:
                continue
            pid_raw = ids_hands[hi] if hi < len(ids_hands) else hi
            try:
                pid = int(pid_raw)
            except (TypeError, ValueError):
                pid = hi
            side = hi % 2  # 0 = L, 1 = R
            arr = self._kp_list_to_array(hkp)
            if arr is None or arr.shape[0] < HANDS_KP_PER_HAND:
                continue
            slot = out.setdefault(
                pid, np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
            )
            base = side * HANDS_KP_PER_HAND
            slot[base:base + HANDS_KP_PER_HAND] = arr[:HANDS_KP_PER_HAND]
        return out

    def _build_face_mouth_map(self, persons_face: list,
                               ids_face: list) -> dict[int, float]:
        """Compute mouth_open = norm(upper_inner_lip - lower_inner_lip) per pid."""
        out: dict[int, float] = {}
        for fi, fkp in enumerate(persons_face):
            if fkp is None:
                continue
            arr = self._kp_list_to_array(fkp)
            if arr is None or arr.shape[0] <= MEDIAPIPE_LIP_LOWER_INNER:
                continue
            upper = arr[MEDIAPIPE_LIP_UPPER_INNER]
            lower = arr[MEDIAPIPE_LIP_LOWER_INNER]
            mouth = float(np.linalg.norm(upper - lower))
            try:
                pid = int(ids_face[fi]) if fi < len(ids_face) else fi
            except (TypeError, ValueError):
                pid = fi
            out[pid] = mouth
        return out

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
