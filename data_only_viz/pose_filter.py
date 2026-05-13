"""3D pose filtering chain : median spike removal, Kalman CV smoothing,
spring-damper organic inertia, lookahead extrapolation, IK angular clamps.

Operates on lists of Kp3D (metric, hip-centered) keyed by track id.

Stages are toggleable via the POSE_FILTER env var :
    POSE_FILTER=median+kalman+lookahead+ik   (default)
    POSE_FILTER=median
    POSE_FILTER=off
"""
from __future__ import annotations

import logging
import math
import os
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Iterable

from .state import Kp3D, State

LOG = logging.getLogger("pose_filter")

NUM_JOINTS = 33
DEFAULT_STAGES = ("median", "kalman", "lookahead", "ik")
ALL_STAGES = ("median", "kalman", "spring", "lookahead", "ik")

# MediaPipe POSE_LANDMARKS indices used by IK constraints.
L_SHOULDER, R_SHOULDER = 11, 12
L_ELBOW, R_ELBOW = 13, 14
L_WRIST, R_WRIST = 15, 16
L_HIP, R_HIP = 23, 24
L_KNEE, R_KNEE = 25, 26
L_ANKLE, R_ANKLE = 27, 28
L_FOOT, R_FOOT = 31, 32

# (parent_idx, joint_idx, child_idx, min_deg, max_deg)
JOINT_LIMITS: tuple[tuple[int, int, int, float, float], ...] = (
    (L_SHOULDER, L_ELBOW, L_WRIST, 0.0, 175.0),
    (R_SHOULDER, R_ELBOW, R_WRIST, 0.0, 175.0),
    (L_HIP, L_KNEE, L_ANKLE, 0.0, 175.0),
    (R_HIP, R_KNEE, R_ANKLE, 0.0, 175.0),
    (L_KNEE, L_ANKLE, L_FOOT, 60.0, 135.0),
    (R_KNEE, R_ANKLE, R_FOOT, 60.0, 135.0),
)


# ----------------------------- utilities --------------------------------

def _is_finite(v: float) -> bool:
    return v == v and v not in (float("inf"), float("-inf"))


def _kp_finite(kp: Kp3D) -> bool:
    return _is_finite(kp.x) and _is_finite(kp.y) and _is_finite(kp.z)


def _median(values: list[float]) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0.0
    if n % 2 == 1:
        return s[n // 2]
    return 0.5 * (s[n // 2 - 1] + s[n // 2])


def _std(values: list[float], mu: float) -> float:
    if not values:
        return 0.0
    var = sum((v - mu) ** 2 for v in values) / len(values)
    return math.sqrt(var)


# ----------------------------- median filter ----------------------------

class MedianFilter:
    """Per (pid, joint) ring buffer ; replaces spikes outside 3σ by median."""

    def __init__(self, window: int = 3) -> None:
        self.window = max(1, window)
        self._buf: dict[tuple[int, int], deque[tuple[float, float, float]]] = {}

    def reset(self) -> None:
        self._buf.clear()

    def apply(self, pid: int, joint_idx: int, x: float, y: float, z: float
              ) -> tuple[float, float, float]:
        key = (pid, joint_idx)
        buf = self._buf.get(key)
        if buf is None:
            buf = deque(maxlen=self.window)
            self._buf[key] = buf

        # Spike detection requires history.
        out = (x, y, z)
        if not (_is_finite(x) and _is_finite(y) and _is_finite(z)):
            if buf:
                med = (_median([v[0] for v in buf]),
                       _median([v[1] for v in buf]),
                       _median([v[2] for v in buf]))
                out = med
            else:
                out = (0.0, 0.0, 0.0)
        elif len(buf) >= self.window:
            for axis_idx, val in enumerate(out):
                col = [v[axis_idx] for v in buf]
                med = _median(col)
                sigma = _std(col, med)
                if sigma > 1e-6 and abs(val - med) > 3.0 * sigma:
                    out = tuple(med if i == axis_idx else out[i]
                                for i in range(3))  # type: ignore[assignment]
        buf.append(out)
        return out


# ----------------------------- Kalman CV --------------------------------

@dataclass
class _KalmanState:
    # State vector [x, y, z, vx, vy, vz]
    x: list[float] = field(default_factory=lambda: [0.0] * 6)
    # 6x6 covariance flattened
    P: list[list[float]] = field(default_factory=lambda: [[0.0] * 6 for _ in range(6)])
    initialised: bool = False
    last_t: float = 0.0


def _mat_eye(n: int, s: float = 1.0) -> list[list[float]]:
    return [[s if i == j else 0.0 for j in range(n)] for i in range(n)]


def _mat_mul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    ra, ca = len(A), len(A[0])
    cb = len(B[0])
    out = [[0.0] * cb for _ in range(ra)]
    for i in range(ra):
        Ai = A[i]
        for k in range(ca):
            aik = Ai[k]
            if aik == 0.0:
                continue
            Bk = B[k]
            for j in range(cb):
                out[i][j] += aik * Bk[j]
    return out


def _mat_add(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    return [[A[i][j] + B[i][j] for j in range(len(A[0]))] for i in range(len(A))]


def _mat_sub(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    return [[A[i][j] - B[i][j] for j in range(len(A[0]))] for i in range(len(A))]


def _mat_T(A: list[list[float]]) -> list[list[float]]:
    return [[A[i][j] for i in range(len(A))] for j in range(len(A[0]))]


def _mat_inv3(M: list[list[float]]) -> list[list[float]]:
    a, b, c = M[0]
    d, e, f = M[1]
    g, h, i = M[2]
    A = e * i - f * h
    B = -(d * i - f * g)
    C = d * h - e * g
    det = a * A + b * B + c * C
    if abs(det) < 1e-12:
        return _mat_eye(3, 1.0)
    inv_det = 1.0 / det
    return [
        [A * inv_det, -(b * i - c * h) * inv_det, (b * f - c * e) * inv_det],
        [B * inv_det,  (a * i - c * g) * inv_det, -(a * f - c * d) * inv_det],
        [C * inv_det, -(a * h - b * g) * inv_det, (a * e - b * d) * inv_det],
    ]


class KalmanCV:
    """Constant-velocity Kalman per (pid, joint_idx) on R^3."""

    def __init__(self, q: float = 1e-3, r: float = 1e-2) -> None:
        self.q = q
        self.r = r
        self._states: dict[tuple[int, int], _KalmanState] = {}
        self._H = [
            [1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
        ]

    def reset(self) -> None:
        self._states.clear()

    def get_velocity(self, pid: int, joint_idx: int) -> tuple[float, float, float]:
        st = self._states.get((pid, joint_idx))
        if st is None or not st.initialised:
            return (0.0, 0.0, 0.0)
        return (st.x[3], st.x[4], st.x[5])

    def step(self, pid: int, joint_idx: int, mx: float, my: float, mz: float,
             t_now: float) -> tuple[float, float, float]:
        key = (pid, joint_idx)
        st = self._states.get(key)
        if st is None:
            st = _KalmanState()
            self._states[key] = st

        if not st.initialised:
            st.x = [mx, my, mz, 0.0, 0.0, 0.0]
            st.P = _mat_eye(6, 1.0)
            st.initialised = True
            st.last_t = t_now
            return (mx, my, mz)

        dt = max(1e-3, min(0.2, t_now - st.last_t))
        st.last_t = t_now

        # Predict
        F = _mat_eye(6, 1.0)
        F[0][3] = dt
        F[1][4] = dt
        F[2][5] = dt
        x_pred = [
            st.x[0] + dt * st.x[3],
            st.x[1] + dt * st.x[4],
            st.x[2] + dt * st.x[5],
            st.x[3], st.x[4], st.x[5],
        ]
        Q = _mat_eye(6, self.q)
        P_pred = _mat_add(_mat_mul(_mat_mul(F, st.P), _mat_T(F)), Q)

        # Update
        z = [mx, my, mz]
        # y = z - H x_pred
        Hx = [x_pred[0], x_pred[1], x_pred[2]]
        y = [z[i] - Hx[i] for i in range(3)]
        # S = H P H^T + R  (3x3)
        HP = _mat_mul(self._H, P_pred)
        S = [[HP[i][j] for j in range(3)] for i in range(3)]
        # add HP*H^T rest cols (cols 3..5) -> 0 contribution since H rest zero
        for i in range(3):
            S[i][i] += self.r
        S_inv = _mat_inv3(S)
        # K = P H^T S^-1  (6x3)
        PHt = [[P_pred[i][j] for j in range(3)] for i in range(6)]
        K = _mat_mul(PHt, S_inv)
        # x = x_pred + K y
        x_new = [x_pred[i] + sum(K[i][j] * y[j] for j in range(3))
                 for i in range(6)]
        # P = (I - K H) P_pred
        KH = [[K[i][0] if j == 0 else (K[i][1] if j == 1 else (K[i][2] if j == 2 else 0.0))
               for j in range(6)] for i in range(6)]
        I6 = _mat_eye(6, 1.0)
        st.P = _mat_mul(_mat_sub(I6, KH), P_pred)
        st.x = x_new
        return (x_new[0], x_new[1], x_new[2])


# --------------------------- spring damper ------------------------------

class SpringDamper:
    """Critically-tunable spring-damper per (pid, joint_idx) on R^3."""

    def __init__(self, stiffness: float = 200.0, damping: float = 15.0,
                 mass: float = 1.0, enabled: bool = True) -> None:
        self.k = stiffness
        self.c = damping
        self.m = max(1e-3, mass)
        self.enabled = enabled
        self._pos: dict[tuple[int, int], list[float]] = {}
        self._vel: dict[tuple[int, int], list[float]] = {}
        self._last_t: dict[tuple[int, int], float] = {}

    def reset(self) -> None:
        self._pos.clear()
        self._vel.clear()
        self._last_t.clear()

    def step(self, pid: int, joint_idx: int, tx: float, ty: float, tz: float,
             t_now: float) -> tuple[float, float, float]:
        if not self.enabled:
            return (tx, ty, tz)
        key = (pid, joint_idx)
        pos = self._pos.get(key)
        if pos is None:
            self._pos[key] = [tx, ty, tz]
            self._vel[key] = [0.0, 0.0, 0.0]
            self._last_t[key] = t_now
            return (tx, ty, tz)
        dt = max(1e-3, min(0.1, t_now - self._last_t[key]))
        self._last_t[key] = t_now
        vel = self._vel[key]
        target = (tx, ty, tz)
        for i in range(3):
            # F = k(target - pos) - c * vel
            f = self.k * (target[i] - pos[i]) - self.c * vel[i]
            a = f / self.m
            vel[i] += a * dt
            pos[i] += vel[i] * dt
        return (pos[0], pos[1], pos[2])


# --------------------------- lookahead ----------------------------------

class LookaheadPredictor:
    """Linear extrapolation using Kalman velocities, capped to avoid blow-ups."""

    def __init__(self, lookahead_ms: float = 50.0, max_velocity: float = 5.0
                 ) -> None:
        self.lookahead_s = lookahead_ms / 1000.0
        self.max_v = max_velocity

    def step(self, x: float, y: float, z: float,
             vx: float, vy: float, vz: float) -> tuple[float, float, float]:
        def clamp(v: float) -> float:
            if v > self.max_v:
                return self.max_v
            if v < -self.max_v:
                return -self.max_v
            return v
        dt = self.lookahead_s
        return (x + clamp(vx) * dt, y + clamp(vy) * dt, z + clamp(vz) * dt)


# --------------------------- IK constraints -----------------------------

def _vec_sub(a: tuple[float, float, float], b: tuple[float, float, float]
             ) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _vec_add(a: tuple[float, float, float], b: tuple[float, float, float]
             ) -> tuple[float, float, float]:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _vec_scale(a: tuple[float, float, float], s: float
               ) -> tuple[float, float, float]:
    return (a[0] * s, a[1] * s, a[2] * s)


def _vec_dot(a: tuple[float, float, float], b: tuple[float, float, float]
             ) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _vec_norm(a: tuple[float, float, float]) -> float:
    return math.sqrt(_vec_dot(a, a))


def _vec_normalize(a: tuple[float, float, float], eps: float = 1e-9
                   ) -> tuple[float, float, float]:
    n = _vec_norm(a)
    if n < eps:
        return (1.0, 0.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)


def _slerp_dir(d_from: tuple[float, float, float],
               d_to: tuple[float, float, float],
               t: float) -> tuple[float, float, float]:
    """Slerp between two unit-ish vectors."""
    a = _vec_normalize(d_from)
    b = _vec_normalize(d_to)
    cos_a = max(-1.0, min(1.0, _vec_dot(a, b)))
    ang = math.acos(cos_a)
    if ang < 1e-6:
        return a
    sa = math.sin(ang)
    if abs(sa) < 1e-6:
        # antiparallel : pick an arbitrary perpendicular, then rotate.
        ortho = (1.0, 0.0, 0.0) if abs(a[0]) < 0.9 else (0.0, 1.0, 0.0)
        # Gram-Schmidt
        d = _vec_dot(ortho, a)
        perp = (ortho[0] - d * a[0], ortho[1] - d * a[1], ortho[2] - d * a[2])
        perp = _vec_normalize(perp)
        # rotate a by t*pi around perp axis : Rodrigues for angle = t*pi
        theta = t * ang
        cs, sn = math.cos(theta), math.sin(theta)
        # cross(perp, a)
        cx = perp[1] * a[2] - perp[2] * a[1]
        cy = perp[2] * a[0] - perp[0] * a[2]
        cz = perp[0] * a[1] - perp[1] * a[0]
        dot_pa = _vec_dot(perp, a)
        return (a[0] * cs + cx * sn + perp[0] * dot_pa * (1 - cs),
                a[1] * cs + cy * sn + perp[1] * dot_pa * (1 - cs),
                a[2] * cs + cz * sn + perp[2] * dot_pa * (1 - cs))
    w1 = math.sin((1.0 - t) * ang) / sa
    w2 = math.sin(t * ang) / sa
    return (a[0] * w1 + b[0] * w2,
            a[1] * w1 + b[1] * w2,
            a[2] * w1 + b[2] * w2)


class IKConstraints:
    """Clamp interior joint angles for elbows, knees, ankles."""

    def __init__(self, limits: Iterable[tuple[int, int, int, float, float]]
                 = JOINT_LIMITS) -> None:
        self.limits = tuple(limits)

    def apply(self, kps: list[Kp3D]) -> list[Kp3D]:
        if len(kps) < NUM_JOINTS:
            return kps
        out = list(kps)
        for parent_i, joint_i, child_i, min_deg, max_deg in self.limits:
            if max(parent_i, joint_i, child_i) >= len(out):
                continue
            p = (out[parent_i].x, out[parent_i].y, out[parent_i].z)
            j = (out[joint_i].x, out[joint_i].y, out[joint_i].z)
            c = (out[child_i].x, out[child_i].y, out[child_i].z)
            v_pj = _vec_sub(p, j)  # from joint to parent
            v_cj = _vec_sub(c, j)  # from joint to child
            n_pj = _vec_norm(v_pj)
            n_cj = _vec_norm(v_cj)
            if n_pj < 1e-6 or n_cj < 1e-6:
                continue
            cos_a = max(-1.0, min(1.0, _vec_dot(v_pj, v_cj) / (n_pj * n_cj)))
            ang_deg = math.degrees(math.acos(cos_a))
            min_r = math.radians(min_deg)
            max_r = math.radians(max_deg)
            target_r: float | None = None
            if ang_deg < min_deg:
                target_r = min_r
            elif ang_deg > max_deg:
                target_r = max_r
            if target_r is None:
                continue
            # Interpolate child direction toward parent direction (or away)
            # so the new angle matches target_r.
            cur_r = math.acos(cos_a)
            # t such that new_angle = (1-t)*cur + t*pi between dirs ; use slerp.
            # Find t in [0,1] s.t. slerp(d_cj, d_pj, t) makes angle = target_r
            # The angle between slerp result and d_pj is (1-t)*cur_r.
            # So target_r = (1 - t) * cur_r  ->  t = 1 - target_r / cur_r
            if cur_r < 1e-6:
                continue
            t = 1.0 - (target_r / cur_r)
            t = max(0.0, min(1.0, t))
            d_cj = _vec_normalize(v_cj)
            d_pj = _vec_normalize(v_pj)
            new_dir = _slerp_dir(d_cj, d_pj, t)
            new_child = _vec_add(j, _vec_scale(new_dir, n_cj))
            old = out[child_i]
            out[child_i] = Kp3D(x=new_child[0], y=new_child[1],
                                z=new_child[2], c=old.c)
        return out


# --------------------------- chain wrapper ------------------------------

def _parse_env_stages() -> tuple[str, ...]:
    raw = os.environ.get("POSE_FILTER")
    if raw is None:
        return DEFAULT_STAGES
    raw = raw.strip().lower()
    if raw in ("off", "none", "0", "false"):
        return ()
    parts = tuple(p.strip() for p in raw.replace(",", "+").split("+") if p.strip())
    return tuple(p for p in parts if p in ALL_STAGES)


class PoseFilterChain:
    """Chain : median → kalman → spring → lookahead → ik."""

    def __init__(self, state: State | None = None,
                 enabled_stages: Iterable[str] | None = None) -> None:
        self.state = state
        if enabled_stages is None:
            stages = _parse_env_stages()
        else:
            stages = tuple(s for s in enabled_stages if s in ALL_STAGES)
        self.enabled = stages
        self.median = MedianFilter(window=3)
        self.kalman = KalmanCV()
        self.spring = SpringDamper(enabled="spring" in self.enabled)
        self.lookahead = LookaheadPredictor()
        self.ik = IKConstraints()
        self.last_apply_ms: float = 0.0
        LOG.info("PoseFilterChain stages=%s", self.enabled or ("off",))

    def reset(self) -> None:
        self.median.reset()
        self.kalman.reset()
        self.spring.reset()

    def apply(self, bodies3d: list[list[Kp3D]], ids: list[int],
              t_now: float) -> list[list[Kp3D]]:
        if not bodies3d or not self.enabled:
            self.last_apply_ms = 0.0
            return bodies3d
        t0 = time.perf_counter()
        out: list[list[Kp3D]] = []
        use_median = "median" in self.enabled
        use_kalman = "kalman" in self.enabled
        use_spring = "spring" in self.enabled
        use_lookahead = "lookahead" in self.enabled
        use_ik = "ik" in self.enabled

        for body_i, kps in enumerate(bodies3d):
            pid = ids[body_i] if body_i < len(ids) else -1
            new_kps: list[Kp3D] = []
            for j_idx, kp in enumerate(kps):
                x, y, z, c = kp.x, kp.y, kp.z, kp.c
                if use_median:
                    x, y, z = self.median.apply(pid, j_idx, x, y, z)
                if use_kalman:
                    x, y, z = self.kalman.step(pid, j_idx, x, y, z, t_now)
                if use_spring:
                    x, y, z = self.spring.step(pid, j_idx, x, y, z, t_now)
                if use_lookahead and use_kalman:
                    vx, vy, vz = self.kalman.get_velocity(pid, j_idx)
                    x, y, z = self.lookahead.step(x, y, z, vx, vy, vz)
                new_kps.append(Kp3D(x=x, y=y, z=z, c=c))
            if use_ik:
                new_kps = self.ik.apply(new_kps)
            out.append(new_kps)

        self.last_apply_ms = (time.perf_counter() - t0) * 1000.0
        return out

    # ---- Face / hand smoothing entry points ---------------------------
    def apply_face(self, faces: list[list], ids: list[int],
                   t_now: float) -> list[list]:
        if not hasattr(self, "_face_chain"):
            self._face_chain = FaceFilterChain()
        return self._face_chain.apply(faces, ids, t_now)

    def apply_hand(self, hands: list[list], ids: list[int],
                   handedness: list[str] | None,
                   t_now: float) -> list[list]:
        if not hasattr(self, "_hand_chain"):
            self._hand_chain = HandFilterChain()
        return self._hand_chain.apply(hands, ids, handedness, t_now)


# ============================ face / hand =================================

# Face and hand filtering operate on PoseKp lists (normalized x,y in [0,1]
# + z relative depth + confidence). We only apply temporal smoothing
# (median + Kalman 2D + lookahead) — no IK, no spring.

def _parse_env_face_stages() -> tuple[str, ...]:
    raw = os.environ.get("POSE_FILTER_FACE")
    if raw is None:
        return ("median", "kalman", "lookahead")
    raw = raw.strip().lower()
    if raw in ("off", "none", "0", "false"):
        return ()
    parts = tuple(p.strip() for p in raw.replace(",", "+").split("+") if p.strip())
    return tuple(p for p in parts if p in ("median", "kalman", "lookahead"))


def _parse_env_hand_stages() -> tuple[str, ...]:
    raw = os.environ.get("POSE_FILTER_HAND")
    if raw is None:
        return ("median", "kalman", "lookahead")
    raw = raw.strip().lower()
    if raw in ("off", "none", "0", "false"):
        return ()
    parts = tuple(p.strip() for p in raw.replace(",", "+").split("+") if p.strip())
    return tuple(p for p in parts if p in ("median", "kalman", "lookahead"))


class AlphaBetaCV:
    """Lightweight alpha-beta filter (scalar Kalman approximation).

    Far cheaper than the 6x6 KalmanCV : O(1) per joint per axis with no
    matrix algebra. Suited to face/hand smoothing where the full CV
    Kalman is overkill.
    """

    def __init__(self, alpha: float = 0.55, beta: float = 0.15) -> None:
        self.alpha = alpha
        self.beta = beta
        # state[key] = [x, y, z, vx, vy, vz, last_t]
        self._st: dict[tuple[int, int], list[float]] = {}

    def reset(self) -> None:
        self._st.clear()

    def get_velocity(self, pid: int, joint_idx: int
                     ) -> tuple[float, float, float]:
        s = self._st.get((pid, joint_idx))
        if s is None:
            return (0.0, 0.0, 0.0)
        return (s[3], s[4], s[5])

    def step(self, pid: int, joint_idx: int, mx: float, my: float,
             mz: float, t_now: float) -> tuple[float, float, float]:
        key = (pid, joint_idx)
        s = self._st.get(key)
        if s is None:
            self._st[key] = [mx, my, mz, 0.0, 0.0, 0.0, t_now]
            return (mx, my, mz)
        dt = max(1e-3, min(0.2, t_now - s[6]))
        s[6] = t_now
        # Predict
        x_pred = s[0] + s[3] * dt
        y_pred = s[1] + s[4] * dt
        z_pred = s[2] + s[5] * dt
        # Residual
        rx = mx - x_pred
        ry = my - y_pred
        rz = mz - z_pred
        # Update
        s[0] = x_pred + self.alpha * rx
        s[1] = y_pred + self.alpha * ry
        s[2] = z_pred + self.alpha * rz
        s[3] += (self.beta / dt) * rx
        s[4] += (self.beta / dt) * ry
        s[5] += (self.beta / dt) * rz
        return (s[0], s[1], s[2])


class FaceFilterChain:
    """Per-pid temporal smoothing for face landmarks (median + Kalman + lookahead).

    Lookahead 30 ms ; max velocity in normalized units/s.
    """

    def __init__(self, lookahead_ms: float = 30.0,
                 enabled_stages: Iterable[str] | None = None) -> None:
        if enabled_stages is None:
            stages = _parse_env_face_stages()
        else:
            stages = tuple(s for s in enabled_stages
                           if s in ("median", "kalman", "lookahead"))
        self.enabled = stages
        self.median = MedianFilter(window=3)
        self.kalman = AlphaBetaCV(alpha=0.55, beta=0.15)
        self.lookahead = LookaheadPredictor(
            lookahead_ms=lookahead_ms, max_velocity=2.0)
        self.last_apply_ms: float = 0.0

    def reset(self) -> None:
        self.median.reset()
        self.kalman.reset()

    def apply(self, faces: list[list], ids: list[int],
              t_now: float) -> list[list]:
        if not faces or not self.enabled:
            self.last_apply_ms = 0.0
            return faces
        t0 = time.perf_counter()
        use_median = "median" in self.enabled
        use_kalman = "kalman" in self.enabled
        use_lookahead = "lookahead" in self.enabled
        out: list[list] = []
        for f_i, kps in enumerate(faces):
            pid = ids[f_i] if f_i < len(ids) else -1
            # Encode pid with a face-side namespace to avoid colliding with
            # body and hand kalman/median caches.
            key_pid = pid * 13 + 1 if pid >= 0 else pid
            new_kps = []
            for j_idx, kp in enumerate(kps):
                x, y, z, c = kp.x, kp.y, kp.z, kp.c
                if use_median:
                    x, y, z = self.median.apply(key_pid, j_idx, x, y, z)
                if use_kalman:
                    x, y, z = self.kalman.step(key_pid, j_idx, x, y, z, t_now)
                if use_lookahead and use_kalman:
                    vx, vy, vz = self.kalman.get_velocity(key_pid, j_idx)
                    x, y, z = self.lookahead.step(x, y, z, vx, vy, vz)
                new_kps.append(type(kp)(x=x, y=y, z=z, c=c))
            out.append(new_kps)
        self.last_apply_ms = (time.perf_counter() - t0) * 1000.0
        return out


class HandFilterChain:
    """Per-pid+side temporal smoothing for hand landmarks.

    Left and right hands keep independent filter state via a namespaced
    pid (pid*2 for left, pid*2+1 for right). When handedness is not
    provided, hands fall back to a side-agnostic namespace.
    """

    def __init__(self, lookahead_ms: float = 30.0,
                 enabled_stages: Iterable[str] | None = None) -> None:
        if enabled_stages is None:
            stages = _parse_env_hand_stages()
        else:
            stages = tuple(s for s in enabled_stages
                           if s in ("median", "kalman", "lookahead"))
        self.enabled = stages
        self.median = MedianFilter(window=3)
        self.kalman = AlphaBetaCV(alpha=0.6, beta=0.2)
        self.lookahead = LookaheadPredictor(
            lookahead_ms=lookahead_ms, max_velocity=4.0)
        self.last_apply_ms: float = 0.0

    def reset(self) -> None:
        self.median.reset()
        self.kalman.reset()

    def apply(self, hands: list[list], ids: list[int],
              handedness: list[str] | None,
              t_now: float) -> list[list]:
        if not hands or not self.enabled:
            self.last_apply_ms = 0.0
            return hands
        t0 = time.perf_counter()
        use_median = "median" in self.enabled
        use_kalman = "kalman" in self.enabled
        use_lookahead = "lookahead" in self.enabled
        out: list[list] = []
        for h_i, kps in enumerate(hands):
            pid = ids[h_i] if h_i < len(ids) else -1
            side = (handedness[h_i] if handedness and h_i < len(handedness)
                    else "u").lower()
            side_bit = 0 if side.startswith("l") else (1 if side.startswith("r") else 2)
            # Namespace : (pid << 2) | side_bit  — keeps L/R independent.
            key_pid = (pid * 4 + side_bit + 7) if pid >= 0 else pid
            new_kps = []
            for j_idx, kp in enumerate(kps):
                x, y, z, c = kp.x, kp.y, kp.z, kp.c
                if use_median:
                    x, y, z = self.median.apply(key_pid, j_idx, x, y, z)
                if use_kalman:
                    x, y, z = self.kalman.step(key_pid, j_idx, x, y, z, t_now)
                if use_lookahead and use_kalman:
                    vx, vy, vz = self.kalman.get_velocity(key_pid, j_idx)
                    x, y, z = self.lookahead.step(x, y, z, vx, vy, vz)
                new_kps.append(type(kp)(x=x, y=y, z=z, c=c))
            out.append(new_kps)
        self.last_apply_ms = (time.perf_counter() - t0) * 1000.0
        return out
