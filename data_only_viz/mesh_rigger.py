"""Mesh rigging hybride keyframe (Multi-HMR) + delta Apple Vision.

Multi-HMR produit un mesh SMPL-X dense (10475 verts) tous les ~300 ms
sur M5 (PyTorch MPS ~3.5 fps). Entre deux keyframes, Apple Vision sur
ANE produit 30 fps de body keypoints 2D. On exploite le pelvis 2D de
Vision pour translater rigidement le mesh keyframe et donner une
perception fluide a 30 fps cote launcher RealityKit.

Limitations connues (premiere iteration) :
  - Translation rigide uniquement (pas de rotation, pas de LBS articule)
  - Pelvis 2D delta projete en X/Y a profondeur constante (z keyframe)
  - Pas de matching d'identite Vision <-> Multi-HMR : on prend la
    personne Vision la plus proche du pelvis projete keyframe
"""
from __future__ import annotations

import collections
import logging
import math
import threading
import time
from dataclasses import dataclass, field

import numpy as np

try:
    from scipy.optimize import linear_sum_assignment
    _HAVE_SCIPY = True
except ImportError:  # noqa: BLE001
    _HAVE_SCIPY = False

from .state import PoseKp, SMPLXPerson, State

LOG = logging.getLogger("mesh_rigger")


# Indices MediaPipe POSE_LANDMARKS pour les hanches (pelvis 2D = midpoint).
_LEFT_HIP = 23
_RIGHT_HIP = 24

# Focale par defaut Multi-HMR (camera intrinsics typiques utilisees
# dans multi_hmr_worker : focal = IMG_SIZE).
_IMG_SIZE = 672
_FOCAL = float(_IMG_SIZE)


@dataclass
class _Keyframe:
    """Snapshot d'un mesh Multi-HMR + reference Vision au moment T."""
    pid: int
    t: float
    # Mesh world coords (10475, 3) float32 incluant la translation
    vertices_3d: np.ndarray
    translation: np.ndarray            # (3,) world pelvis
    vision_pelvis_2d: tuple[float, float] | None  # (cx, cy) normalises 0..1


def _pelvis_2d_from_body(body: list[PoseKp]) -> tuple[float, float] | None:
    """Midpoint des deux hanches MediaPipe si confidence > 0."""
    if not body or len(body) <= _RIGHT_HIP:
        return None
    lh, rh = body[_LEFT_HIP], body[_RIGHT_HIP]
    if lh.c <= 0.1 or rh.c <= 0.1:
        return None
    return (0.5 * (lh.x + rh.x), 0.5 * (lh.y + rh.y))


def _body_bbox_norm(
    body: list[PoseKp],
) -> tuple[float, float, float, float] | None:
    """Bbox image-normalized [0,1] from a list of body landmarks
    (Vision 19 joints OR MediaPipe 33). None if not enough confident
    points."""
    if not body:
        return None
    xs = [kp.x for kp in body if kp.c > 0.05]
    ys = [kp.y for kp in body if kp.c > 0.05]
    if len(xs) < 4 or len(ys) < 4:
        return None
    x0, x1 = max(0.0, min(xs)), min(1.0, max(xs))
    y0, y1 = max(0.0, min(ys)), min(1.0, max(ys))
    # Pad 10% to capture full body silhouette.
    dx = (x1 - x0) * 0.10
    dy = (y1 - y0) * 0.10
    x0 = max(0.0, x0 - dx); x1 = min(1.0, x1 + dx)
    y0 = max(0.0, y0 - dy); y1 = min(1.0, y1 + dy)
    if x1 - x0 < 0.02 or y1 - y0 < 0.02:
        return None
    return (x0, y0, x1, y1)


def _mesh_bbox_norm(p: SMPLXPerson) -> tuple[float, float, float, float] | None:
    """Project SMPL-X mesh vertices to image-normalized bbox.

    Multi-HMR uses focal = IMG_SIZE camera intrinsics. World verts
    have z>0 (in front of camera)."""
    v = np.asarray(p.vertices_3d, dtype=np.float32)
    if v.size == 0 or v.shape[0] < 100:
        return None
    z = v[:, 2]
    valid = z > 1e-3
    if not np.any(valid):
        return None
    x_img = (v[valid, 0] * _FOCAL / z[valid]) / _IMG_SIZE + 0.5
    y_img = (v[valid, 1] * _FOCAL / z[valid]) / _IMG_SIZE + 0.5
    x0, x1 = float(x_img.min()), float(x_img.max())
    y0, y1 = float(y_img.min()), float(y_img.max())
    x0 = max(0.0, x0); x1 = min(1.0, x1)
    y0 = max(0.0, y0); y1 = min(1.0, y1)
    if x1 - x0 < 0.02 or y1 - y0 < 0.02:
        return None
    return (x0, y0, x1, y1)


def _iou_norm(
    a: tuple[float, float, float, float],
    b: tuple[float, float, float, float],
) -> float:
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    ix0 = max(ax0, bx0); iy0 = max(ay0, by0)
    ix1 = min(ax1, bx1); iy1 = min(ay1, by1)
    iw = max(0.0, ix1 - ix0); ih = max(0.0, iy1 - iy0)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    a_area = (ax1 - ax0) * (ay1 - ay0)
    b_area = (bx1 - bx0) * (by1 - by0)
    return float(inter / (a_area + b_area - inter + 1e-9))


def _vision_pid_match(
    keyframe_pelvis_2d: tuple[float, float] | None,
    vision_bodies: list[list[PoseKp]],
    vision_ids: list[int],
) -> int | None:
    """Retourne le pid Vision dont le pelvis 2D est le plus proche du
    keyframe pelvis projete. None si rien."""
    if keyframe_pelvis_2d is None or not vision_bodies:
        return None
    kx, ky = keyframe_pelvis_2d
    best_pid: int | None = None
    best_d2 = float("inf")
    for body, vpid in zip(vision_bodies, vision_ids):
        p = _pelvis_2d_from_body(body)
        if p is None:
            continue
        d2 = (p[0] - kx) ** 2 + (p[1] - ky) ** 2
        if d2 < best_d2:
            best_d2 = d2
            best_pid = int(vpid)
    return best_pid


class MeshRigger:
    """Rig le mesh SMPL-X keyframe via le delta pelvis Vision.

    Usage :
        rigger = MeshRigger(state)
        rigged_persons = rigger.apply(state.persons_smplx,
                                      state.persons_body,
                                      t_now)
    Thread-safe : ne mute pas le state, retourne une nouvelle liste.
    """

    def __init__(self, state: State, hold_window_s: float = 1.5,
                 dino_weight: float = 0.5,
                 dino_reid=None) -> None:
        self.state = state
        self.hold_window_s = hold_window_s
        self.dino_weight = float(dino_weight)
        self.dino_reid = dino_reid
        self._lock = threading.Lock()
        # pid Multi-HMR -> keyframe
        self._keyframes: dict[int, _Keyframe] = {}
        # pid Multi-HMR -> pid Vision matched (sticky across frames)
        self._vision_pid_map: dict[int, int] = {}
        # pid Multi-HMR -> recent DINO embeddings (mean -> reid signature)
        self._pid_embeddings: dict[int, collections.deque] = {}
        # Cached log throttle
        self._next_dino_log = 0.0

    def apply(
        self,
        persons_smplx: list[SMPLXPerson],
        persons_body: list[list[PoseKp]],
        persons_body_ids: list[int],
        t_now: float,
    ) -> list[SMPLXPerson]:
        """Retourne une liste SMPLXPerson translatee par delta Vision."""
        # 1) Detect new keyframes (timestamp tracked via state.smplx_last_t)
        with self._lock:
            current_pids = {p.pid for p in persons_smplx}
            # Drop stale keyframes (person disparue)
            for old_pid in list(self._keyframes):
                if old_pid not in current_pids:
                    self._keyframes.pop(old_pid, None)
                    self._vision_pid_map.pop(old_pid, None)
                    self._pid_embeddings.pop(old_pid, None)

            # 2) DINO fusion: if a reid backend is wired, try Hungarian
            # over (mesh keyframe pids) x (Vision body pids) using
            # alpha*IoU + (1-alpha)*cosine. This only kicks in when a
            # keyframe is detected this call AND we have an RGB frame.
            self._dino_match(persons_smplx, persons_body,
                             persons_body_ids)

            out: list[SMPLXPerson] = []
            for person in persons_smplx:
                kf = self._keyframes.get(person.pid)
                # Detect keyframe refresh : translation differs from kf
                is_new_kf = (kf is None or not np.allclose(
                    kf.translation, person.translation, atol=1e-4))
                if is_new_kf:
                    # Trouver le pid Vision le plus proche pour ce mesh.
                    # On projette le pelvis world en 2D image-normalized :
                    # x_img = (X / Z) * focal / IMG_SIZE + 0.5
                    pelvis_2d = self._project_pelvis(person.translation)
                    matched = _vision_pid_match(
                        pelvis_2d, persons_body, persons_body_ids)
                    if matched is None:
                        matched = self._vision_pid_map.get(person.pid)
                    if matched is not None:
                        self._vision_pid_map[person.pid] = matched
                    # Capture du pelvis 2D Vision au moment du keyframe
                    vp = None
                    if matched is not None:
                        try:
                            i = persons_body_ids.index(matched)
                            vp = _pelvis_2d_from_body(persons_body[i])
                        except (ValueError, IndexError):
                            vp = None
                    self._keyframes[person.pid] = _Keyframe(
                        pid=person.pid,
                        t=t_now,
                        vertices_3d=person.vertices_3d.copy(),
                        translation=person.translation.copy(),
                        vision_pelvis_2d=vp,
                    )
                    out.append(person)
                    continue

                # Entre keyframes : applique delta translation depuis
                # Vision pelvis 2D actuel vs keyframe pelvis 2D.
                if t_now - kf.t > self.hold_window_s:
                    # Trop ancien, on lache le rig (mesh statique)
                    out.append(person)
                    continue
                matched_pid = self._vision_pid_map.get(person.pid)
                if matched_pid is None or kf.vision_pelvis_2d is None:
                    out.append(person)
                    continue
                try:
                    i = persons_body_ids.index(matched_pid)
                except ValueError:
                    out.append(person)
                    continue
                current_vp = _pelvis_2d_from_body(persons_body[i])
                if current_vp is None:
                    out.append(person)
                    continue

                # Image-normalized 2D delta -> world XY delta a depth z_kf.
                # Pour un pelvis aux coords image (px in [0,1] centre 0.5),
                # X_world = (px - 0.5) * IMG_SIZE * Z / focal = (px-0.5)*Z
                # (focal=IMG_SIZE). Delta image -> Delta world a Z fixe.
                z_kf = float(kf.translation[2]) if abs(
                    kf.translation[2]) > 1e-3 else 1.0
                dx_img = current_vp[0] - kf.vision_pelvis_2d[0]
                dy_img = current_vp[1] - kf.vision_pelvis_2d[1]
                dx_world = dx_img * _IMG_SIZE * z_kf / _FOCAL
                dy_world = dy_img * _IMG_SIZE * z_kf / _FOCAL

                # Applique a tous les vertices + a translation.
                new_verts = kf.vertices_3d.copy()
                new_verts[:, 0] += np.float32(dx_world)
                new_verts[:, 1] += np.float32(dy_world)
                new_transl = kf.translation.copy()
                new_transl[0] += np.float32(dx_world)
                new_transl[1] += np.float32(dy_world)

                out.append(SMPLXPerson(
                    pid=person.pid,
                    vertices_3d=new_verts,
                    translation=new_transl,
                    confidence=person.confidence,
                    betas=person.betas,
                    expression=person.expression,
                ))
            return out

    # ------------------------------------------------------------------
    # DINOv2 reid hooks
    # ------------------------------------------------------------------
    def _dino_match(
        self,
        persons_smplx: list[SMPLXPerson],
        persons_body: list[list[PoseKp]],
        persons_body_ids: list[int],
    ) -> None:
        """Update self._vision_pid_map and self._pid_embeddings by
        matching mesh pids against Vision pids on alpha*IoU +
        (1-alpha)*DINO cosine. No-op if any prerequisite missing.

        Caller must hold self._lock."""
        if self.dino_reid is None or not _HAVE_SCIPY:
            return
        if not persons_smplx or not persons_body:
            return
        # Need at least one new keyframe to be worth running DINO.
        new_kf_pids: list[int] = []
        for p in persons_smplx:
            kf = self._keyframes.get(p.pid)
            if kf is None or not np.allclose(
                    kf.translation, p.translation, atol=1e-4):
                new_kf_pids.append(int(p.pid))
        if not new_kf_pids:
            return

        # Acquire current RGB frame (best effort, no double lock).
        frame = self.state.last_frame_rgb
        if frame is None:
            return
        H, W = frame.shape[:2]

        # Build Vision bboxes (image-normalized) and pixel crops.
        v_bboxes_norm: list[tuple[float, float, float, float]] = []
        v_crops: list[np.ndarray] = []
        v_pids: list[int] = []
        for body, vpid in zip(persons_body, persons_body_ids):
            bb = _body_bbox_norm(body)
            if bb is None:
                continue
            x0, y0, x1, y1 = bb
            px0 = max(0, int(x0 * W))
            py0 = max(0, int(y0 * H))
            px1 = min(W, int(x1 * W))
            py1 = min(H, int(y1 * H))
            if px1 <= px0 + 4 or py1 <= py0 + 4:
                continue
            v_bboxes_norm.append(bb)
            v_crops.append(frame[py0:py1, px0:px1].copy())
            v_pids.append(int(vpid))

        if not v_crops:
            return

        # Build mesh bboxes (image-normalized) from world pelvis proj.
        m_bboxes_norm: list[tuple[float, float, float, float]] = []
        m_pids_keep: list[int] = []
        m_crops: list[np.ndarray] = []
        for p in persons_smplx:
            bb = _mesh_bbox_norm(p)
            if bb is None:
                continue
            m_bboxes_norm.append(bb)
            m_pids_keep.append(int(p.pid))
            x0, y0, x1, y1 = bb
            px0 = max(0, int(x0 * W))
            py0 = max(0, int(y0 * H))
            px1 = min(W, int(x1 * W))
            py1 = min(H, int(y1 * H))
            if px1 > px0 + 4 and py1 > py0 + 4:
                m_crops.append(frame[py0:py1, px0:px1].copy())
            else:
                m_crops.append(None)  # type: ignore[arg-type]

        if not m_bboxes_norm:
            return

        # Embed Vision crops in one batch (still loops internally).
        t0 = time.perf_counter()
        try:
            v_emb = self.dino_reid.embed_crops(v_crops)
        except Exception as e:  # noqa: BLE001
            LOG.warning("dino_reid embed failed: %s", e)
            return

        # Build cost matrix mesh x vision : 1 - (alpha*IoU + (1-alpha)*cos)
        n_m = len(m_bboxes_norm)
        n_v = len(v_bboxes_norm)
        alpha = float(np.clip(self.dino_weight, 0.0, 1.0))
        cost = np.ones((n_m, n_v), dtype=np.float32)
        for i, mbb in enumerate(m_bboxes_norm):
            hist = self._pid_embeddings.get(m_pids_keep[i])
            mean_emb = None
            if hist:
                stack = np.stack(list(hist), axis=0)
                mean_emb = stack.mean(axis=0)
                n = np.linalg.norm(mean_emb) + 1e-8
                mean_emb = mean_emb / n
            for j, vbb in enumerate(v_bboxes_norm):
                iou = _iou_norm(mbb, vbb)
                if mean_emb is not None:
                    cos = float(np.dot(mean_emb, v_emb[j]))
                else:
                    cos = iou  # no history -> trust IoU
                score = alpha * iou + (1.0 - alpha) * max(0.0, cos)
                cost[i, j] = 1.0 - score

        rr, cc = linear_sum_assignment(cost)
        for i, j in zip(rr, cc):
            if cost[i, j] >= 0.95:
                continue  # weak match, ignore
            mpid = m_pids_keep[i]
            self._vision_pid_map[mpid] = v_pids[j]
            # Update embedding history for THIS mesh pid using the
            # Vision crop (most recent visual evidence).
            dq = self._pid_embeddings.setdefault(
                mpid, collections.deque(maxlen=10))
            dq.append(v_emb[j].copy())

        now = time.monotonic()
        dt_ms = (time.perf_counter() - t0) * 1e3
        if now >= self._next_dino_log:
            LOG.info(
                "dino_reid: embedded %d crops in %.1f ms (alpha=%.2f, "
                "matched %d mesh<->vision pairs)",
                len(v_crops), dt_ms, alpha, min(n_m, n_v))
            self._next_dino_log = now + 5.0

    @staticmethod
    def _project_pelvis(
        translation: np.ndarray,
    ) -> tuple[float, float] | None:
        """World pelvis (X,Y,Z) -> image-normalized 2D pelvis."""
        z = float(translation[2])
        if abs(z) < 1e-3:
            return None
        x_img = (float(translation[0]) * _FOCAL / z) / _IMG_SIZE + 0.5
        y_img = (float(translation[1]) * _FOCAL / z) / _IMG_SIZE + 0.5
        # Clamp en [0,1]
        if not (0.0 <= x_img <= 1.0 and 0.0 <= y_img <= 1.0):
            return None
        return (x_img, y_img)
