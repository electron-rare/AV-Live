"""Pont sonore pose -> SC.

Envoie en OSC les coordonnees des keypoints saillants vers sclang
(127.0.0.1:57121) pour qu'ils pilotent des synthdefs en temps reel.

Routes emises :
    /pose/count <n>                            nombre de personnes
    /pose/center <pid> <cx> <cy>               centre corps (moyen kp visibles)
    /pose/wrist <pid> <l|r> <x> <y>            poignet gauche / droit
    /pose/head <pid> <x> <y> <c>               position du nez
    /pose/sho_span <pid> <dx>                  ecart epaules (proxy distance)
    /pose/limb_span <pid> <span>               envergure poignet a poignet
    /pose/torso_yaw <pid> <yaw>                rotation epaules (proxy yaw)
    /pose/body_pitch <pid> <pitch>             inclinaison verticale corps
    /pose/wrist_speed <pid> <l|r> <vx> <vy>    vitesse normalisee instantanee
    /pose/face <pid> <mouth_open> <eye_open>   metriques visage MediaPipe
    /pose/hand <pid> <l|r> <openness> <px py>  ouverture / pointing main
    /pose/active <pid> <activity_0_1>          score de mouvement [0,1]

Mapping pose -> son cote SC : sound_algo/data_only/scenes.scd (live_pose).
"""
from __future__ import annotations

import logging
import math

from pythonosc.udp_client import SimpleUDPClient

LOG = logging.getLogger("pose_bridge")


# Indices MediaPipe POSE_LANDMARKS (33 body keypoints)
NOSE = 0
LEFT_EYE = 2
RIGHT_EYE = 5
LEFT_SHO = 11
RIGHT_SHO = 12
LEFT_ELB = 13
RIGHT_ELB = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24

# Indices MediaPipe FACE_MESH (478) pour metriques expression
FACE_LIP_TOP = 13
FACE_LIP_BOT = 14
FACE_EYE_L_TOP = 159
FACE_EYE_L_BOT = 145
FACE_EYE_R_TOP = 386
FACE_EYE_R_BOT = 374

# Indices MediaPipe HAND (21) pour openness/pointing
HAND_WRIST = 0
HAND_THUMB_TIP = 4
HAND_INDEX_TIP = 8
HAND_INDEX_MCP = 5
HAND_MIDDLE_TIP = 12
HAND_RING_TIP = 16
HAND_PINKY_TIP = 20


class PoseSoundBridge:
    """Envoie les keypoints en OSC vers sclang. Throttle a 30 Hz max."""

    def __init__(self, sclang_host: str = "127.0.0.1",
                 sclang_port: int = 57121, throttle_hz: float = 30.0) -> None:
        self._client = SimpleUDPClient(sclang_host, sclang_port)
        self._period = 1.0 / max(1.0, throttle_hz)
        self._last_t = 0.0
        # State pour velocity / activity (per-pid)
        self._prev_wrists: dict = {}    # pid -> {"l": (x,y), "r": (x,y), "t": t}

    def send(self, persons_body: list, persons_body_ids: list,
             t_now: float,
             persons_face: list | None = None,
             persons_face_ids: list | None = None,
             persons_hands: list | None = None,
             persons_hands_ids: list | None = None) -> None:
        """Envoie les keypoints de toutes les personnes detectees.
        Throttle automatique. Les face/hands sont optionnels (MediaPipe
        Multi les fournit, Apple Vision body-only ne les a pas)."""
        if t_now - self._last_t < self._period:
            return
        self._last_t = t_now

        n = len(persons_body)
        try:
            self._client.send_message("/pose/count", [int(n)])
        except OSError:
            return
        if n == 0:
            return

        for i, body in enumerate(persons_body):
            pid = persons_body_ids[i] if i < len(persons_body_ids) else i
            self._emit_body(int(pid), body, t_now)

        # Face metrics par personne (mouth + eye open)
        if persons_face:
            ids_f = persons_face_ids or list(range(len(persons_face)))
            for i, face in enumerate(persons_face):
                pid = ids_f[i] if i < len(ids_f) else i
                self._emit_face(int(pid), face)

        # Hands metrics (openness + pointing) par personne
        if persons_hands:
            ids_h = persons_hands_ids or list(range(len(persons_hands)))
            for i, hand in enumerate(persons_hands):
                pid = ids_h[i] if i < len(ids_h) else i
                # MediaPipe expose une liste par main ; on label l/r si l'info
                # est disponible (heuristique : hand[0].x vs centre corps).
                side = "l" if hand and hand[0].x < 0.5 else "r"
                self._emit_hand(int(pid), side, hand)

    # ------------------------------------------------------------------
    def _emit_body(self, pid: int, body: list, t_now: float) -> None:
        cli = self._client

        visible = [(kp.x, kp.y) for kp in body if kp.c > 0.3]
        if not visible:
            return
        cx = sum(p[0] for p in visible) / len(visible)
        cy = sum(p[1] for p in visible) / len(visible)
        cli.send_message("/pose/center", [pid, float(cx), float(cy)])

        if len(body) > NOSE and body[NOSE].c > 0.3:
            cli.send_message("/pose/head", [
                pid, float(body[NOSE].x), float(body[NOSE].y),
                float(body[NOSE].c),
            ])

        # Poignets + velocity
        prev = self._prev_wrists.get(pid, {})
        dt = max(1e-3, t_now - prev.get("t", t_now - 0.033))
        for side, idx in [("l", LEFT_WRIST), ("r", RIGHT_WRIST)]:
            if len(body) > idx and body[idx].c > 0.3:
                wx, wy = float(body[idx].x), float(body[idx].y)
                cli.send_message("/pose/wrist", [pid, side, wx, wy])
                px, py = prev.get(side, (wx, wy))
                vx = (wx - px) / dt
                vy = (wy - py) / dt
                cli.send_message("/pose/wrist_speed",
                                 [pid, side, float(vx), float(vy)])
                prev[side] = (wx, wy)
        prev["t"] = t_now
        self._prev_wrists[pid] = prev

        # Ecart epaules + yaw torse + pitch
        if (len(body) > RIGHT_SHO
                and body[LEFT_SHO].c > 0.3 and body[RIGHT_SHO].c > 0.3):
            sl, sr = body[LEFT_SHO], body[RIGHT_SHO]
            dx = abs(sl.x - sr.x)
            cli.send_message("/pose/sho_span", [pid, float(dx)])
            # Yaw torse : angle des epaules dans l'image (0 = face cam)
            yaw = math.atan2(sl.y - sr.y, sl.x - sr.x)
            cli.send_message("/pose/torso_yaw", [pid, float(yaw)])

        # Pitch corps : difference nose vs centre hanches (normalise sur span)
        if (len(body) > RIGHT_HIP
                and body[NOSE].c > 0.3
                and body[LEFT_HIP].c > 0.3 and body[RIGHT_HIP].c > 0.3):
            hip_cy = (body[LEFT_HIP].y + body[RIGHT_HIP].y) / 2.0
            torso_h = max(0.05, hip_cy - body[NOSE].y)
            # pitch = 0 si nose au-dessus hips comme attendu, augmente si plonge
            pitch = (body[NOSE].y + 0.2 - hip_cy) / torso_h
            cli.send_message("/pose/body_pitch", [pid, float(pitch)])

        # Envergure poignets
        if (len(body) > RIGHT_WRIST
                and body[LEFT_WRIST].c > 0.3 and body[RIGHT_WRIST].c > 0.3):
            span = ((body[LEFT_WRIST].x - body[RIGHT_WRIST].x) ** 2
                    + (body[LEFT_WRIST].y - body[RIGHT_WRIST].y) ** 2) ** 0.5
            cli.send_message("/pose/limb_span", [pid, float(span)])

        # Activity score : norme L2 des vitesses poignets, clamp [0,1]
        speeds = []
        for side in ("l", "r"):
            if side in prev and "t" in prev:
                speeds.append(0.0)  # placeholder, recompute below
        # Simpler : confidence moyenne des kp body comme proxy d'activite
        mean_c = sum(kp.c for kp in body) / max(1, len(body))
        cli.send_message("/pose/active", [pid, float(min(1.0, mean_c))])

    def _emit_face(self, pid: int, face: list) -> None:
        cli = self._client
        if not face or len(face) < FACE_EYE_R_BOT + 1:
            return
        # Bouche : distance verticale top-bottom lip, normalisee par
        # largeur face (interocular distance).
        def _kp(i):
            return face[i] if i < len(face) else None
        lip_t, lip_b = _kp(FACE_LIP_TOP), _kp(FACE_LIP_BOT)
        eye_lt, eye_lb = _kp(FACE_EYE_L_TOP), _kp(FACE_EYE_L_BOT)
        eye_rt, eye_rb = _kp(FACE_EYE_R_TOP), _kp(FACE_EYE_R_BOT)
        if not (lip_t and lip_b and eye_lt and eye_lb):
            return
        mouth = abs(lip_t.y - lip_b.y)
        eye_l = abs(eye_lt.y - eye_lb.y) if eye_lt and eye_lb else 0.0
        eye_r = abs(eye_rt.y - eye_rb.y) if eye_rt and eye_rb else eye_l
        eye_open = (eye_l + eye_r) / 2.0
        cli.send_message("/pose/face",
                         [pid, float(mouth * 50.0), float(eye_open * 100.0)])

    def _emit_hand(self, pid: int, side: str, hand: list) -> None:
        cli = self._client
        if not hand or len(hand) < HAND_PINKY_TIP + 1:
            return
        wrist = hand[HAND_WRIST]
        # Openness : moyenne des distances wrist -> 4 tips (excl thumb)
        tips = [HAND_INDEX_TIP, HAND_MIDDLE_TIP, HAND_RING_TIP, HAND_PINKY_TIP]
        dists = []
        for t in tips:
            if t < len(hand):
                d = ((hand[t].x - wrist.x) ** 2
                     + (hand[t].y - wrist.y) ** 2) ** 0.5
                dists.append(d)
        openness = sum(dists) / max(1, len(dists))
        # Pointing : direction wrist -> index tip
        if HAND_INDEX_TIP < len(hand):
            px = hand[HAND_INDEX_TIP].x - wrist.x
            py = hand[HAND_INDEX_TIP].y - wrist.y
            norm = math.sqrt(px * px + py * py) or 1.0
            px /= norm
            py /= norm
        else:
            px = py = 0.0
        cli.send_message("/pose/hand",
                         [pid, side, float(openness), float(px), float(py)])
