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
    HANDS_KP_DIMS,
    HANDS_KP_PER_HAND,
    HANDS_KP_TOTAL,
    J3D_FINGERS,
    J3D_FINGERS_PER_HAND,
    LABELS,
)

LOG = logging.getLogger("action_head_pub")

DEFAULT_CKPT = (
    Path.home() / ".cache" / "av-live-action" / "checkpoints" / "action_head.pt"
)

# Canonical SMPL-X fingertip vertex IDs from smplx.vertex_ids.SMPLX_VERTEX_IDS.
# Order : L thumb, L index, L middle, L ring, L pinky,
#         R thumb, R index, R middle, R ring, R pinky.
SMPLX_FINGERTIP_VERTS: tuple[int, ...] = (
    5361, 4933, 5058, 5169, 5286,   # L : lthumb, lindex, lmiddle, lring, lpinky
    8079, 7669, 7794, 7905, 8022,   # R : rthumb, rindex, rmiddle, rring, rpinky
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

# MediaPipe FaceMesh inner-mouth landmark indices.
# 13 = upper inner mid, 14 = lower inner mid.
MEDIAPIPE_LIP_UPPER_INNER: int = 13
MEDIAPIPE_LIP_LOWER_INNER: int = 14

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
        from data_only_viz.hand_features import HandFeatureExtractor
        self._hand_ext = HandFeatureExtractor()
        self._init_finger_piano()

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
            for pid, j3d, expr_np, mouth, hands_kp42 in persons32:
                current_pids.add(pid)
                label, probs, kin = self.head.step(pid, j3d, expr=expr_np,
                                                    mouth_open=mouth,
                                                    hands_kp=hands_kp42)
                idx = LABELS.index(label)
                self.bridge.send_action(pid, idx, probs, t_now, force=True)
                self.bridge.send_kin(pid, kin, t_now, force=True)
                self.bridge.send_mouth(pid, mouth)
                if pid not in self._last_pids:
                    self.bridge.send_enter(pid=pid)
        for gone in self._last_pids - current_pids:
            self.head.forget(gone)
            self.bridge.send_leave(pid=gone)
        self._last_pids = current_pids
        self._emit_hands(t_now)
        self._emit_fingers(t_now)
        self._emit_pinch(t_now)

    def _emit_hands(self, t_now: float) -> None:
        """Lock state, extract hand features, emit /pose/hands once per tick."""
        with self.state.lock():
            hands = list(getattr(self.state, "persons_hands", None) or [])
            if not hands and getattr(self.state, "hands_present", False):
                lkp = getattr(self.state, "left_hand_kp", None)
                rkp = getattr(self.state, "right_hand_kp", None)
                hands = [h for h in (lkp, rkp) if h is not None and len(h) > 0]
        feats = self._hand_ext.step(hands)
        with self.state.lock():
            self.state.hand_feats = feats
        self.bridge.send_hands(feats, t_now)

    def _init_finger_piano(self) -> None:
        """Read FINGER_* env config and build the strike + pinch detectors."""
        import os
        from data_only_viz.finger_strike import (
            FingerStrikeDetector, PinchDetector,
        )
        self._finger_enabled = os.environ.get("FINGER_PIANO", "0") not in (
            "0", "", "false", "False",
        )
        # Pinch detection is gated independently of the air-piano finger-strike:
        # the matrix global actions want pinches WITHOUT the finger-strike "piano".
        self._pinch_enabled = os.environ.get("PINCH_ENABLE", "0") not in (
            "0", "", "false", "False",
        )
        vel = float(os.environ.get("FINGER_STRIKE_VEL", "0.02"))
        refr = float(os.environ.get("FINGER_STRIKE_REFRACTORY_MS", "120"))
        self._finger_det = FingerStrikeDetector(
            vel_thresh=vel, refractory_ms=refr,
        )
        self._pinch_det = PinchDetector(
            ratio_on=float(os.environ.get("PINCH_RATIO_ON", "0.45")),
            ratio_off=float(os.environ.get("PINCH_RATIO_OFF", "0.65")),
            refractory_ms=float(os.environ.get("PINCH_REFRACTORY_MS", "250")),
            margin=float(os.environ.get("PINCH_MARGIN", "0.20")),
            ext_ratio=float(os.environ.get("PINCH_EXT_RATIO", "1.35")),
            ext_min=int(os.environ.get("PINCH_EXT_MIN", "2")),
            debounce_frames=int(os.environ.get("PINCH_DEBOUNCE_FRAMES", "3")),
        )
        self._finger_dbg = os.environ.get("FINGER_DEBUG", "0") not in (
            "0", "", "false", "False",
        )
        # auto = iPhone Vision hands if fresh, else MediaPipe. Or force
        # "iphone" / "mediapipe".
        self._finger_source = os.environ.get("FINGER_SOURCE", "auto").lower()
        self._fdbg_n = 0

    def _pick_hands(self) -> tuple[list, str, bool]:
        """Return (hands, source_label, ip_fresh) per FINGER_SOURCE policy."""
        with self.state.lock():
            mp_hands = list(getattr(self.state, "persons_hands", None) or [])
            ip_hands = list(getattr(self.state, "persons_hands_iphone", None) or [])
            ip_t = getattr(self.state, "persons_hands_iphone_t", 0.0)
        ip_fresh = bool(ip_hands) and (time.perf_counter() - ip_t) < 0.5
        src = getattr(self, "_finger_source", "auto")
        if src == "iphone":
            return ip_hands, "iphone", ip_fresh
        if src == "mediapipe":
            return mp_hands, "mediapipe", ip_fresh
        return (ip_hands, "iphone", ip_fresh) if ip_fresh else (
            mp_hands, "mediapipe", ip_fresh)

    def _emit_fingers(self, t_now: float) -> None:
        """Detect finger strikes (air-piano) and emit /pose/finger."""
        if not getattr(self, "_finger_enabled", False):
            return
        hands, used, ip_fresh = self._pick_hands()
        events = self._finger_det.step(hands, t_now)
        if getattr(self, "_finger_dbg", False):
            self._fdbg_n += 1
            if events or self._fdbg_n % 30 == 0:
                LOG.info("fingers dbg: src=%s hands=%d strikes=%d (ip_fresh=%s)",
                         used, len(hands), len(events), ip_fresh)
        for ev in events:
            self.bridge.send_finger(ev)

    def _emit_pinch(self, t_now: float) -> None:
        """Detect thumb-to-finger pinches (matrix global actions) and emit
        /pose/pinch. Gated by PINCH_ENABLE, independently of the air-piano."""
        if not getattr(self, "_pinch_enabled", False):
            return
        hands, used, _ip = self._pick_hands()
        for ev in self._pinch_det.step(hands, t_now):
            if getattr(self, "_finger_dbg", False):
                LOG.info("pinch dbg: src=%s hand=%d finger=%d",
                         used, ev.hand, ev.finger)
            self.bridge.send_pinch(ev)

    def _read_sources(self) -> tuple[
        list[tuple[int, np.ndarray, np.ndarray, float, np.ndarray]] | None,
        float, str, bool,
    ]:
        """Return (persons32, source_t, source_tag, is_new).

        Each person entry is (pid, j3d32, expr10, mouth_open, hands_kp42x3).
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

        # Build pid -> hands_kp(42, 3) map from MediaPipe persons_hands.
        hands_by_pid: dict[int, np.ndarray] = self._build_hands_map(
            persons_hands or [], ids_hands or [],
        )
        # Build pid -> mouth_open scalar from MediaPipe persons_face lips.
        face_mouth_by_pid: dict[int, float] = self._build_face_mouth_map(
            persons_face or [], ids_face or [],
        )

        # SMPL-X path (preferred)
        if t_smplx > self._last_smplx_t:
            out: list[tuple[int, np.ndarray, np.ndarray, float, np.ndarray]] = []
            for i, p in enumerate(persons_smplx or []):
                # Support both SMPLXPerson dataclass (multi_hmr_worker, field
                # names: pid / vertices_3d / expression) and legacy dict format
                # (keys: "pid" / "v3d" / "expression").
                _is_dict = isinstance(p, dict)
                pid = int(p.get("pid", i) if _is_dict else p.pid)
                v3d = p.get("v3d") if _is_dict else p.vertices_3d
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
                # expression — field name matches in both dict and dataclass
                expr = p.get("expression") if _is_dict else p.expression
                if expr is not None:
                    if hasattr(expr, "numpy") and not isinstance(expr, np.ndarray):
                        expr = expr.numpy()
                    expr_np = np.asarray(expr, dtype=np.float32).flatten()
                else:
                    expr_np = np.zeros(EXPR_DIM, dtype=np.float32)
                # mouth_open: prefer MediaPipe face lips, fallback SMPL-X v3d.
                if pid in face_mouth_by_pid:
                    mouth = face_mouth_by_pid[pid]
                elif v3d_np.shape[0] > max(SMPLX_UPPER_LIP_VERT, SMPLX_LOWER_LIP_VERT):
                    mouth = float(np.linalg.norm(
                        v3d_np[SMPLX_UPPER_LIP_VERT] - v3d_np[SMPLX_LOWER_LIP_VERT]
                    ))
                else:
                    mouth = 0.0
                hands_kp42 = hands_by_pid.get(
                    pid, np.zeros((HANDS_KP_TOTAL, HANDS_KP_DIMS), dtype=np.float32)
                )
                out.append((pid, j3d32, expr_np, mouth, hands_kp42))
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
        """Best-effort conversion of a body keypoint list to (N, 3) array.

        Handles attribute objects (the Kp3D dataclass exposes .x/.y/.z) and
        indexable rows. Kp3D is NOT subscriptable, so the index fallback must
        not be evaluated eagerly (the old `getattr(kp, "x", kp[0])` raised
        TypeError on Kp3D and silently returned None — breaking the body3d /
        MediaPipe-only path that feeds action-head when no SMPL-X is present)."""
        if body is None:
            return None
        if isinstance(body, np.ndarray):
            return body
        rows = []
        for kp in body:
            if hasattr(kp, "x"):
                rows.append((kp.x, kp.y, getattr(kp, "z", 0.0)))
            else:
                try:
                    rows.append((kp[0], kp[1], kp[2] if len(kp) > 2 else 0.0))
                except (TypeError, IndexError):
                    return None
        if not rows:
            return None
        return np.asarray(rows, dtype=np.float32)
