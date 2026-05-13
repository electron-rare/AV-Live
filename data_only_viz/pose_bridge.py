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

Mapping pose -> son est defini cote SC dans sound_algo/data_only/scenes.scd
(scene `live_pose`).
"""
from __future__ import annotations

import logging

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


class PoseSoundBridge:
    """Envoie les keypoints en OSC vers sclang. Throttle a 30 Hz max."""

    def __init__(self, sclang_host: str = "127.0.0.1",
                 sclang_port: int = 57121, throttle_hz: float = 30.0) -> None:
        self._client = SimpleUDPClient(sclang_host, sclang_port)
        self._period = 1.0 / max(1.0, throttle_hz)
        self._last_t = 0.0

    def send(self, persons_body: list, persons_body_ids: list, t_now: float) -> None:
        """Envoie les keypoints de toutes les personnes detectees.
        Throttle automatiquement."""
        if t_now - self._last_t < self._period:
            return
        self._last_t = t_now

        n = len(persons_body)
        try:
            self._client.send_message("/pose/count", [int(n)])
        except OSError:
            return  # SC pas la, on continue silencieusement
        if n == 0:
            return

        for i, body in enumerate(persons_body):
            pid = persons_body_ids[i] if i < len(persons_body_ids) else i
            self._emit_person(int(pid), body)

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

        # Envergure poignets (mouvement expressif)
        if (len(body) > RIGHT_WRIST
                and body[LEFT_WRIST].c > 0.3 and body[RIGHT_WRIST].c > 0.3):
            span = ((body[LEFT_WRIST].x - body[RIGHT_WRIST].x) ** 2
                    + (body[LEFT_WRIST].y - body[RIGHT_WRIST].y) ** 2) ** 0.5
            cli.send_message("/pose/limb_span", [pid, float(span)])
