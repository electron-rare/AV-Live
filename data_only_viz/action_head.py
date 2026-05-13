"""Action classifier head on top of Multi-HMR j3d.

Streaming GRU-1-layer + MLP per-person, with a 16-frame ring buffer.
Trained windowed (Studio M3 Ultra MPS), inferred streaming (M5 eager CPU).

Output per step: (label_idx, probs (3,), kin (3,)) where kin is
(speed_m_s, accel_m_s2, symmetry_in_minus1_plus1).
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
import torch
from torch import nn

HIDDEN_DIM: int = 48
MLP_HIDDEN: int = 32
WARMUP_FRAMES: int = 3
NAN_SKIP_BUDGET: int = 5

WINDOW_LEN: int = 16
J3D_BODY: int = 22
J3D_FINGERS_PER_HAND: int = 5
J3D_FINGERS: int = 2 * J3D_FINGERS_PER_HAND  # 10
J3D_JOINTS: int = J3D_BODY + J3D_FINGERS     # 32
J3D_DIMS: int = 3
NUM_CLASSES: int = 3
LABELS: tuple[str, str, str] = ("debout", "assise", "danse")

EXPR_DIM: int = 10
EXTRA_SCALARS: int = 4   # hip_y, knee_angle, sym_score, mouth_open

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
# NEW v3 : MediaPipe Hands keypoints block.
HANDS_KP_PER_HAND: int = 21
HANDS_KP_TOTAL: int = 2 * HANDS_KP_PER_HAND       # 42
HANDS_KP_DIMS: int = 3
HANDS_KP_FLAT: int = HANDS_KP_TOTAL * HANDS_KP_DIMS  # 126

# Layout per step (v3) :
#   [0      :  96]  j3d   (32, 3)
<<<<<<< HEAD
#   [96     : 192]  vel   (32, 3)
#   [192    : 288]  accel (32, 3)
#   [288    : 414]  hands_kp (42, 3) zero-padded if absent
#   [414    : 424]  expression (10,)
#   [424    : 428]  scalars (hip_y, knee_angle, sym, mouth_open)
FEATURE_DIM: int = J3D_JOINTS * J3D_DIMS * 3 + HANDS_KP_FLAT + EXPR_DIM + EXTRA_SCALARS  # 428
=======
# Layout per step:
#   [0      : 96 ]  j3d   (32, 3)
#   [96     : 192]  vel   (32, 3)
#   [192    : 288]  accel (32, 3)
#   [288    : 298]  expression (10,)
#   [298    : 302]  scalars (hip_y, knee_angle, sym, mouth_open)
FEATURE_DIM: int = J3D_JOINTS * J3D_DIMS * 3 + EXPR_DIM + EXTRA_SCALARS  # 302
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
#   [96     : 192]  vel   (32, 3)
#   [192    : 288]  accel (32, 3)
#   [288    : 414]  hands_kp (42, 3) zero-padded if absent
#   [414    : 424]  expression (10,)
#   [424    : 428]  scalars (hip_y, knee_angle, sym, mouth_open)
FEATURE_DIM: int = J3D_JOINTS * J3D_DIMS * 3 + HANDS_KP_FLAT + EXPR_DIM + EXTRA_SCALARS  # 428
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)

# Body joint indices (unchanged from v1, indices 0..21).
HIP_LEFT: int = 1
HIP_RIGHT: int = 2
KNEE_LEFT: int = 4
KNEE_RIGHT: int = 5
ANKLE_LEFT: int = 7
ANKLE_RIGHT: int = 8
SHOULDER_LEFT: int = 16
SHOULDER_RIGHT: int = 17
WRIST_LEFT: int = 20
WRIST_RIGHT: int = 21

# Fingertip indices (new, 22..31), order: L thumb..pinky, R thumb..pinky.
FINGERTIP_LEFT_BASE: int = 22
FINGERTIP_RIGHT_BASE: int = 27


class FeatureExtractor:
    """Stateless feature builder over a list of recent j3d frames.

<<<<<<< HEAD
<<<<<<< HEAD
    Vector layout (FEATURE_DIM = 428, v3):
      [0   :  96]  j3d current frame, flattened (32 joints x 3 dims)
      [96  : 192]  velocity j3d[t] - j3d[t-1] (32 x 3)
      [192 : 288]  acceleration vel[t] - vel[t-1] (32 x 3)
      [288 : 414]  hands_kp (42, 3) MediaPipe Hands, zero-padded if absent
      [414 : 424]  expression PCA coefficients (10,)
      [424 : 428]  kinetics scalars (hip_y, knee_angle, symmetry_score, mouth_open)
=======
    Vector layout (FEATURE_DIM = 302):
      [0   : 96 ]  j3d current frame, flattened (32 joints x 3 dims)
      [96  : 192]  velocity j3d[t] - j3d[t-1] (32 x 3)
      [192 : 288]  acceleration vel[t] - vel[t-1] (32 x 3)
      [288 : 298]  expression PCA coefficients (10,)
      [298 : 302]  kinetics scalars (hip_y, knee_angle, symmetry_score, mouth_open)
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
    Vector layout (FEATURE_DIM = 428, v3):
      [0   :  96]  j3d current frame, flattened (32 joints x 3 dims)
      [96  : 192]  velocity j3d[t] - j3d[t-1] (32 x 3)
      [192 : 288]  acceleration vel[t] - vel[t-1] (32 x 3)
      [288 : 414]  hands_kp (42, 3) MediaPipe Hands, zero-padded if absent
      [414 : 424]  expression PCA coefficients (10,)
      [424 : 428]  kinetics scalars (hip_y, knee_angle, symmetry_score, mouth_open)
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
    """

    @staticmethod
    def from_buffer(frames: list[np.ndarray],
                    expr: np.ndarray | None = None,
<<<<<<< HEAD
<<<<<<< HEAD
                    mouth_open: float = 0.0,
                    hands_kp: np.ndarray | None = None) -> np.ndarray:
=======
                    mouth_open: float = 0.0) -> np.ndarray:
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
                    mouth_open: float = 0.0,
                    hands_kp: np.ndarray | None = None) -> np.ndarray:
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        if not frames:
            return np.zeros(FEATURE_DIM, dtype=np.float32)
        cur = frames[-1]
        prev = frames[-2] if len(frames) >= 2 else cur
        prev2 = frames[-3] if len(frames) >= 3 else prev
        vel = (cur - prev).astype(np.float32, copy=False)
        prev_vel = (prev - prev2).astype(np.float32, copy=False)
        accel = (vel - prev_vel).astype(np.float32, copy=False)
        hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
        knee_angle = FeatureExtractor._mean_knee_angle(cur)
        sym = FeatureExtractor._symmetry_score(vel)
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        # hands block (42, 3) -> 126
        hands_flat = np.zeros(HANDS_KP_FLAT, dtype=np.float32)
        if hands_kp is not None:
            hk = np.asarray(hands_kp, dtype=np.float32)
            if hk.shape == (HANDS_KP_TOTAL, HANDS_KP_DIMS):
                hands_flat = hk.reshape(-1).astype(np.float32, copy=False)
        # expression
<<<<<<< HEAD
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        if expr is None:
            expr_vec = np.zeros(EXPR_DIM, dtype=np.float32)
        else:
            expr_vec = np.zeros(EXPR_DIM, dtype=np.float32)
            n = min(EXPR_DIM, len(expr))
            expr_vec[:n] = expr[:n]
        return np.concatenate([
            cur.reshape(-1),
            vel.reshape(-1),
            accel.reshape(-1),
<<<<<<< HEAD
<<<<<<< HEAD
            hands_flat,
=======
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
            hands_flat,
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
            expr_vec,
            np.array([hip_y, knee_angle, sym, float(mouth_open)], dtype=np.float32),
        ]).astype(np.float32, copy=False)

    @staticmethod
    def kinetics(frames: list[np.ndarray]) -> np.ndarray:
        """Return (speed, accel_mag, symmetry) averaged over the buffer."""
        if len(frames) < 2:
            return np.zeros(3, dtype=np.float32)
        arr = np.stack(frames).astype(np.float32, copy=False)
        diffs = arr[1:] - arr[:-1]
        speeds = np.linalg.norm(diffs, axis=-1).mean(axis=-1)
        speed = float(speeds.mean())
        if len(frames) >= 3:
            ddiffs = diffs[1:] - diffs[:-1]
            accel = float(np.linalg.norm(ddiffs, axis=-1).mean())
        else:
            accel = 0.0
        sym = FeatureExtractor._symmetry_score(diffs[-1])
        return np.array([speed, accel, sym], dtype=np.float32)

    @staticmethod
    def _mean_knee_angle(j3d: np.ndarray) -> float:
        """Angle (rad) at left+right knees, averaged."""
        def _angle(hip: int, knee: int, ankle: int) -> float:
            v1 = j3d[hip] - j3d[knee]
            v2 = j3d[ankle] - j3d[knee]
            n1 = np.linalg.norm(v1) + 1e-6
            n2 = np.linalg.norm(v2) + 1e-6
            cos = float(np.dot(v1, v2) / (n1 * n2))
            return float(np.arccos(np.clip(cos, -1.0, 1.0)))
        return 0.5 * (_angle(HIP_LEFT, KNEE_LEFT, ANKLE_LEFT)
                      + _angle(HIP_RIGHT, KNEE_RIGHT, ANKLE_RIGHT))

    @staticmethod
    def _symmetry_score(vel: np.ndarray) -> float:
        """Cosine sim between left-arm and mirrored right-arm velocity."""
        left = vel[WRIST_LEFT].copy()
        right = vel[WRIST_RIGHT].copy()
        right_mirror = right.copy()
        right_mirror[0] = -right_mirror[0]
        n1 = np.linalg.norm(left) + 1e-6
        n2 = np.linalg.norm(right_mirror) + 1e-6
        return float(np.dot(left, right_mirror) / (n1 * n2))


class PerPersonBuffer:
    """Per-pid ring buffer of j3d frames (deque maxlen=WINDOW_LEN)."""

    __slots__ = ("_buffers",)

    def __init__(self) -> None:
        self._buffers: dict[int, deque[np.ndarray]] = {}

    def append(self, pid: int, j3d: np.ndarray) -> None:
        if j3d.shape != (J3D_JOINTS, J3D_DIMS):
            raise ValueError(
                f"j3d must be ({J3D_JOINTS}, {J3D_DIMS}), got {j3d.shape}"
            )
        dq = self._buffers.get(pid)
        if dq is None:
            dq = deque(maxlen=WINDOW_LEN)
            self._buffers[pid] = dq
        dq.append(j3d.astype(np.float32, copy=False))

    def frames_for(self, pid: int) -> list[np.ndarray]:
        dq = self._buffers.get(pid)
        return list(dq) if dq is not None else []

    def forget(self, pid: int) -> None:
        self._buffers.pop(pid, None)

    def __len__(self) -> int:
        return len(self._buffers)

    def pids(self) -> list[int]:
        return list(self._buffers.keys())


class ActionHeadModel(nn.Module):
    """1-layer GRU + small MLP head.

    Input  : (B, FEATURE_DIM) -- single step
    Hidden : (1, B, HIDDEN_DIM)
    Output : (B, NUM_CLASSES) logits, new hidden
    """

    def __init__(self) -> None:
        super().__init__()
        self.gru = nn.GRU(input_size=FEATURE_DIM,
                          hidden_size=HIDDEN_DIM,
                          num_layers=1,
                          batch_first=True)
        self.mlp = nn.Sequential(
            nn.Linear(HIDDEN_DIM, MLP_HIDDEN),
            nn.ReLU(inplace=True),
            nn.Linear(MLP_HIDDEN, NUM_CLASSES),
        )

    def init_hidden(self, batch: int = 1, device: str = "cpu") -> torch.Tensor:
        return torch.zeros(1, batch, HIDDEN_DIM, device=device)

    def forward(self, x: torch.Tensor,
                h: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        out, h_new = self.gru(x.unsqueeze(1), h)
        logits = self.mlp(out.squeeze(1))
        return logits, h_new


class ActionHead:
    """Streaming action classifier per person.

    Use:
        head = ActionHead(ckpt_path=...)
        label, probs, kin = head.step(pid, j3d)
        head.forget(pid)
    """

    def __init__(self,
                 ckpt_path: Path | None = None,
                 device: str = "cpu") -> None:
        self._device = device
        self._model = ActionHeadModel().to(device).eval()
        if ckpt_path is not None:
            payload = torch.load(ckpt_path, map_location=device,
                                 weights_only=True)
            state = payload.get("model_state_dict", payload)
            self._model.load_state_dict(state)
        self._buffers = PerPersonBuffer()
        self._hidden: dict[int, torch.Tensor] = {}
        self._nan_streak: dict[int, int] = {}

    def step(self, pid: int, j3d: np.ndarray,
             expr: np.ndarray | None = None,
<<<<<<< HEAD
<<<<<<< HEAD
             mouth_open: float = 0.0,
             hands_kp: np.ndarray | None = None) -> tuple[str, np.ndarray, np.ndarray]:
=======
             mouth_open: float = 0.0) -> tuple[str, np.ndarray, np.ndarray]:
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
             mouth_open: float = 0.0,
             hands_kp: np.ndarray | None = None) -> tuple[str, np.ndarray, np.ndarray]:
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        if np.isnan(j3d).any():
            streak = self._nan_streak.get(pid, 0) + 1
            self._nan_streak[pid] = streak
            if streak > NAN_SKIP_BUDGET:
                self.forget(pid)
            probs = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            return LABELS[0], probs, np.zeros(3, dtype=np.float32)
        self._nan_streak[pid] = 0
        self._buffers.append(pid, j3d)
        frames = self._buffers.frames_for(pid)
        if len(frames) < WARMUP_FRAMES:
            probs = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            return LABELS[0], probs, np.zeros(3, dtype=np.float32)
<<<<<<< HEAD
<<<<<<< HEAD
        feat = FeatureExtractor.from_buffer(frames, expr=expr, mouth_open=mouth_open,
                                             hands_kp=hands_kp)
=======
        feat = FeatureExtractor.from_buffer(frames, expr=expr, mouth_open=mouth_open)
>>>>>>> aedcb0f (feat(data-only-viz): action-head v2 fingers+face)
=======
        feat = FeatureExtractor.from_buffer(frames, expr=expr, mouth_open=mouth_open,
                                             hands_kp=hands_kp)
>>>>>>> beb94d2 (feat(data-only-viz): action-head v3 hands+lips)
        kin = FeatureExtractor.kinetics(frames)
        h = self._hidden.get(pid)
        if h is None:
            h = self._model.init_hidden(batch=1, device=self._device)
        x = torch.from_numpy(feat).unsqueeze(0).to(self._device)
        with torch.no_grad():
            logits, h_new = self._model(x, h)
            probs_t = torch.softmax(logits, dim=-1).squeeze(0)
        self._hidden[pid] = h_new
        probs = probs_t.cpu().numpy().astype(np.float32, copy=False)
        return LABELS[int(np.argmax(probs))], probs, kin

    def forget(self, pid: int) -> None:
        self._buffers.forget(pid)
        self._hidden.pop(pid, None)
        self._nan_streak.pop(pid, None)
