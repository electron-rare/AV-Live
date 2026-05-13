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

import math
import threading
import time
from dataclasses import dataclass, field

import numpy as np

from .state import PoseKp, SMPLXPerson, State


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

    def __init__(self, state: State, hold_window_s: float = 1.5) -> None:
        self.state = state
        self.hold_window_s = hold_window_s
        self._lock = threading.Lock()
        # pid Multi-HMR -> keyframe
        self._keyframes: dict[int, _Keyframe] = {}
        # pid Multi-HMR -> pid Vision matched (sticky across frames)
        self._vision_pid_map: dict[int, int] = {}

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
