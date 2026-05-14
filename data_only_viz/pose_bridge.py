"""Pont sonore pose -> SC.

Envoie en OSC les coordonnees des keypoints saillants vers sclang
(127.0.0.1:57121) pour qu'ils pilotent des synthdefs en temps reel.

Routes emises :
    /pose/count <n>                    nombre de personnes detectees
    /pose/center <pid> <cx> <cy>       centre du corps (moyenne kp visibles)
    /pose/wrist <pid> <l|r> <x> <y>    poignet gauche / droit (normalises)
    /pose/head <pid> <x> <y> <c>       position du nez (visage)
    /pose/sho_span <pid> <dx>          ecart epaules (estime distance camera)
    /pose/limb_span <pid> <span>       envergure brassse (poignet a poignet)
    /face/count <n>                    nombre de visages detectes
    /face/kp <pid> <idx> <x> <y> <z> <c>  68-pt subset (dlib mapping)
    /hand/count <n_left> <n_right>     nombre de mains gauche / droite
    /hand/kp <pid> <side[0=L|1=R]> <idx> <x> <y> <z> <c>  21 landmarks
    /pose3d/count <n>                  nombre de squelettes 3D
    /pose3d/kp <pid> <idx> <x> <y> <z> <c>  33 MediaPipe world landmarks (metres)

Mapping pose -> son est defini cote SC dans sound_algo/data_only/scenes.scd
(scene `live_pose`). Face / hand keypoints are consumed by the Swift
launcher (AVLiveBody) on 127.0.0.1:57126 for skeleton overlay rendering.
"""
from __future__ import annotations

import logging
from typing import Any, Iterable, Sequence

from pythonosc.udp_client import SimpleUDPClient

LOG = logging.getLogger("pose_bridge")


# Indices MediaPipe POSE_LANDMARKS (cf JOINT_MAP dans apple_vision_pose.py)
NOSE        = 0
LEFT_SHO    = 11
RIGHT_SHO   = 12
LEFT_WRIST  = 15
RIGHT_WRIST = 16
LEFT_HIP    = 23
RIGHT_HIP   = 24


# MediaPipe FaceMesh (468 landmarks) -> 68-point dlib-style subset.
# Mapping inspired by community references (Google MediaPipe ->
# iBUG 68 facial landmarks). Order matches dlib 68-point convention :
#   [0..16]  jaw contour (left to right)
#   [17..21] right brow
#   [22..26] left brow
#   [27..30] nose bridge (top to tip)
#   [31..35] nostril base (right to left)
#   [36..41] right eye (CCW from outer corner)
#   [42..47] left eye  (CCW from inner corner)
#   [48..59] outer lip (CCW from right corner)
#   [60..67] inner lip (CCW from right corner)
FACE_68_FROM_MP: tuple[int, ...] = (
    # Jaw (17)
    127, 234, 132, 172, 150, 176, 148, 152,
    377, 400, 365, 397, 361, 401, 366, 447, 356,
    # Right brow (5) — mediapipe perspective is mirrored vs subject
    70, 63, 105, 66, 107,
    # Left brow (5)
    336, 296, 334, 293, 300,
    # Nose bridge (4)
    168, 6, 197, 195,
    # Nostril base (5)
    98, 97, 2, 326, 327,
    # Right eye (6)
    33, 160, 158, 133, 153, 144,
    # Left eye (6)
    362, 385, 387, 263, 373, 380,
    # Outer lip (12)
    61, 39, 37, 0, 267, 269, 291, 405, 314, 17, 84, 181,
    # Inner lip (8)
    78, 81, 13, 311, 308, 402, 14, 178,
)
assert len(FACE_68_FROM_MP) == 68


class PoseSoundBridge:
    """Envoie les keypoints en OSC vers sclang. Throttle a 30 Hz max."""

    def __init__(self, sclang_host: str = "127.0.0.1",
                 sclang_port: int = 57121, throttle_hz: float = 30.0) -> None:
        self._client = SimpleUDPClient(sclang_host, sclang_port)
        # Broadcast secondaire vers AV-Live-Body (Swift) pour overlay
        # skeleton dans la fenetre RealityKit. Silent si pas connecte.
        import os as _os
        _avbody_host = _os.environ.get("AVBODY_HOST", "127.0.0.1")
        self._avbody = SimpleUDPClient(_avbody_host, 57126)
        self._period = 1.0 / max(1.0, throttle_hz)
        self._last_t = 0.0

    def send(self, persons_body: list, persons_body_ids: list, t_now: float,
             *,
             persons_face: Sequence[Sequence[Any]] | None = None,
             persons_face_ids: Sequence[int] | None = None,
             persons_hands: Sequence[Sequence[Any]] | None = None,
             persons_hands_ids: Sequence[int] | None = None,
             persons_body3d: Sequence[Sequence[Any]] | None = None,
             persons_body3d_ids: Sequence[int] | None = None) -> None:
        """Envoie les keypoints de toutes les personnes detectees.
        Throttle automatiquement. Face / hand sont optionnels et envoyes
        sur le meme socket :57126 vers AVLiveBody."""
        if t_now - self._last_t < self._period:
            return
        self._last_t = t_now

        n = len(persons_body)
        try:
            self._client.send_message("/pose/count", [int(n)])
            try: self._avbody.send_message("/pose/count", [int(n)])
            except OSError: pass
        except OSError:
            return  # SC pas la, on continue silencieusement

        if n > 0:
            for i, body in enumerate(persons_body):
                pid = persons_body_ids[i] if i < len(persons_body_ids) else i
                self._emit_person(int(pid), body)

        # Face / hand : independant de la presence de body kp (utile en
        # mode face-only ou hand-only).
        if persons_face is not None:
            self._send_face(persons_face, persons_face_ids or [])
        if persons_hands is not None:
            self._send_hand(persons_hands, persons_hands_ids or [])
        if persons_body3d is not None:
            self._send_body3d(persons_body3d, persons_body3d_ids or [])

    # ------------------------------------------------------------------
    def _emit_person(self, pid: int, body: list) -> None:
        cli = self._client

        # Centre = moyenne des kp visibles
        visible = [(kp.x, kp.y) for kp in body if kp.c > 0.3]
        if not visible:
            return
        cx = sum(p[0] for p in visible) / len(visible)
        cy = sum(p[1] for p in visible) / len(visible)
        cli.send_message("/pose/center", [pid, float(cx), float(cy)])
        try: self._avbody.send_message("/pose/center", [pid, float(cx), float(cy)])
        except OSError: pass

        # Nez (visage) — important pour piloter une voix
        if len(body) > NOSE and body[NOSE].c > 0.3:
            cli.send_message("/pose/head", [
                pid, float(body[NOSE].x), float(body[NOSE].y),
                float(body[NOSE].c),
            ])

        # Poignets gauche/droit
        if len(body) > LEFT_WRIST and body[LEFT_WRIST].c > 0.3:
            cli.send_message("/pose/wrist", [
                pid, "l", float(body[LEFT_WRIST].x), float(body[LEFT_WRIST].y),
            ])
        if len(body) > RIGHT_WRIST and body[RIGHT_WRIST].c > 0.3:
            cli.send_message("/pose/wrist", [
                pid, "r", float(body[RIGHT_WRIST].x), float(body[RIGHT_WRIST].y),
            ])

        # Ecart epaules (proxy distance camera : plus large = plus pres)
        if (len(body) > RIGHT_SHO
                and body[LEFT_SHO].c > 0.3 and body[RIGHT_SHO].c > 0.3):
            dx = abs(body[LEFT_SHO].x - body[RIGHT_SHO].x)
            cli.send_message("/pose/sho_span", [pid, float(dx)])
            try: self._avbody.send_message("/pose/sho_span", [pid, float(dx)])
            except OSError: pass

        # Envergure poignets (mouvement expressif)
        if (len(body) > RIGHT_WRIST
                and body[LEFT_WRIST].c > 0.3 and body[RIGHT_WRIST].c > 0.3):
            span = ((body[LEFT_WRIST].x - body[RIGHT_WRIST].x) ** 2
                    + (body[LEFT_WRIST].y - body[RIGHT_WRIST].y) ** 2) ** 0.5
            cli.send_message("/pose/limb_span", [pid, float(span)])
            try: self._avbody.send_message("/pose/limb_span", [pid, float(span)])
            except OSError: pass

    # ------------------------------------------------------------------
    def send_face(self, persons_face: Sequence[Sequence[Any]],
                  persons_face_ids: Sequence[int], t_now: float,
                  force: bool = False) -> None:
        """Public throttled entry point for face keypoints.

        Emits a 68-point dlib-style subset of the 468 MediaPipe FaceMesh
        landmarks per person on /face/count + /face/kp routes.
        """
        if not force and (t_now - self._last_t) < self._period:
            return
        self._send_face(persons_face, persons_face_ids)

    def send_hand(self, persons_hands: Sequence[Sequence[Any]],
                  persons_hands_ids: Sequence[int], t_now: float,
                  force: bool = False) -> None:
        """Public throttled entry point for hand keypoints.

        Emits the full 21-landmark hand skeleton per detected hand on
        /hand/count + /hand/kp routes. Side is inferred from id parity
        (MediaPipe Hand task does not flag left/right reliably) : we
        treat odd ids as right, even as left, which matches the
        convention used by the smoother / tracker upstream.
        """
        if not force and (t_now - self._last_t) < self._period:
            return
        self._send_hand(persons_hands, persons_hands_ids)

    def _send_face(self, persons_face: Sequence[Sequence[Any]],
                   persons_face_ids: Sequence[int]) -> None:
        n = len(persons_face)
        try:
            self._avbody.send_message("/face/count", [int(n)])
        except OSError:
            return
        for i, face in enumerate(persons_face):
            if not face:
                continue
            pid = persons_face_ids[i] if i < len(persons_face_ids) else i
            n_lm = len(face)
            for slot, mp_idx in enumerate(FACE_68_FROM_MP):
                if mp_idx >= n_lm:
                    continue
                kp = face[mp_idx]
                try:
                    self._avbody.send_message("/face/kp", [
                        int(pid), int(slot),
                        float(kp.x), float(kp.y),
                        float(getattr(kp, "z", 0.0)),
                        float(getattr(kp, "c", 1.0)),
                    ])
                except OSError:
                    return

    def _send_hand(self, persons_hands: Sequence[Sequence[Any]],
                   persons_hands_ids: Sequence[int]) -> None:
        n_left = 0
        n_right = 0
        for i in range(len(persons_hands)):
            pid = persons_hands_ids[i] if i < len(persons_hands_ids) else i
            if int(pid) % 2 == 0:
                n_left += 1
            else:
                n_right += 1
        try:
            self._avbody.send_message("/hand/count", [int(n_left), int(n_right)])
        except OSError:
            return
        for i, hand in enumerate(persons_hands):
            if not hand:
                continue
            pid = persons_hands_ids[i] if i < len(persons_hands_ids) else i
            side = 1 if int(pid) % 2 else 0
            for idx, kp in enumerate(hand[:21]):
                try:
                    self._avbody.send_message("/hand/kp", [
                        int(pid), int(side), int(idx),
                        float(kp.x), float(kp.y),
                        float(getattr(kp, "z", 0.0)),
                        float(getattr(kp, "c", 1.0)),
                    ])
                except OSError:
                    return

    def send_body3d(self, persons_body3d: Sequence[Sequence[Any]],
                    persons_body3d_ids: Sequence[int], t_now: float,
                    force: bool = False) -> None:
        """Public throttled entry point for 3D body world landmarks.

        Emits 33 MediaPipe pose_world_landmarks per person on
        /pose3d/count + /pose3d/kp routes. Coordinates are in meters,
        relative to the hip-center (MediaPipe convention: x=right,
        y=down, z=forward from the camera).
        """
        if not force and (t_now - self._last_t) < self._period:
            return
        self._send_body3d(persons_body3d, persons_body3d_ids)

    def _send_body3d(self, persons_body3d: Sequence[Sequence[Any]],
                     persons_body3d_ids: Sequence[int]) -> None:
        n = len(persons_body3d)
        try:
            self._avbody.send_message("/pose3d/count", [int(n)])
        except OSError:
            return
        for i, body in enumerate(persons_body3d):
            if not body:
                continue
            pid = persons_body3d_ids[i] if i < len(persons_body3d_ids) else i
            for idx, kp in enumerate(body[:33]):
                try:
                    self._avbody.send_message("/pose3d/kp", [
                        int(pid), int(idx),
                        float(kp.x), float(kp.y),
                        float(getattr(kp, "z", 0.0)),
                        float(getattr(kp, "c", 1.0)),
                    ])
                except OSError:
                    return

    # ------------------------------------------------------------------
    def send_action(self, pid: int, label_idx: int,
                    probs, t_now: float, force: bool = False) -> None:
        """Send action classification result via /pose/action OSC route.

        Sends: [pid (int), label_idx (int), prob_0 (float), prob_1 (float), prob_2 (float)]
        """
        if not force and (t_now - self._last_t) < self._period:
            return
        p = [float(probs[0]), float(probs[1]), float(probs[2])]
        self._client.send_message("/pose/action", [int(pid), int(label_idx), *p])

    def send_kin(self, pid: int, kin,
                 t_now: float, force: bool = False) -> None:
        """Send kinematic angles via /pose/kin OSC route.

        Sends: [pid (int), kin_0 (float), kin_1 (float), kin_2 (float)]
        """
        if not force and (t_now - self._last_t) < self._period:
            return
        self._client.send_message(
            "/pose/kin",
            [int(pid), float(kin[0]), float(kin[1]), float(kin[2])],
        )

    def send_enter(self, pid: int) -> None:
        """Send lifecycle event when person enters frame."""
        self._client.send_message("/pose/enter", [int(pid)])

    def send_leave(self, pid: int) -> None:
        """Send lifecycle event when person leaves frame."""
        self._client.send_message("/pose/leave", [int(pid)])
