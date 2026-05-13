"""Action classifier head on top of Multi-HMR j3d.

Streaming GRU-1-layer + MLP per-person, with a 16-frame ring buffer.
Trained windowed (Studio M3 Ultra MPS), inferred streaming (M5 eager CPU).

Output per step: (label_idx, probs (3,), kin (3,)) where kin is
(speed, accel_mag, symmetry_score).
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np

# Constants (SMPL-X joint indexing as used by Multi-HMR)
WINDOW_LEN: int = 16
J3D_JOINTS: int = 22
J3D_DIMS: int = 3
NUM_CLASSES: int = 3
LABELS: tuple[str, str, str] = ("debout", "assise", "danse")
FEATURE_DIM: int = J3D_JOINTS * J3D_DIMS * 3 + 3  # j3d + vel + accel + 3 scalars

# Joint indices (SMPL-X)
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


class FeatureExtractor:
    """Extract kinematic features from j3d window."""

    @staticmethod
    def _mean_knee_angle(j3d: np.ndarray) -> float:
        """Estimate mean knee angle (radians) from two frames.

        j3d : (22, 3) float32
        Returns: angle in radians (0 = fully extended, π ≈ fully bent)
        """
        hip_l = j3d[HIP_LEFT]
        knee_l = j3d[KNEE_LEFT]
        ankle_l = j3d[ANKLE_LEFT]

        # Vectors: hip→knee, knee→ankle
        v1 = knee_l - hip_l
        v2 = ankle_l - knee_l

        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)

        if norm1 < 1e-6 or norm2 < 1e-6:
            return np.pi / 2  # neutral default

        cos_angle = np.dot(v1, v2) / (norm1 * norm2)
        cos_angle = np.clip(cos_angle, -1.0, 1.0)
        angle = np.arccos(cos_angle)
        return float(angle)

    @staticmethod
    def kinetics(frames: list[np.ndarray]) -> tuple[float, float, float]:
        """Compute speed, accel, symmetry from frame window.

        frames : list of (22, 3) float32 arrays
        Returns: (speed m/s, accel m/s², symmetry -1..1)
        """
        if len(frames) < 2:
            return 0.0, 0.0, 0.0

        # Speed: mean joint velocity magnitude
        velocities = []
        for i in range(1, len(frames)):
            dj3d = frames[i] - frames[i - 1]
            vel_mag = np.linalg.norm(dj3d, axis=1).mean()
            velocities.append(vel_mag)

        speed = float(np.mean(velocities)) if velocities else 0.0

        # Accel: finite difference of velocities
        accel = 0.0
        if len(velocities) >= 2:
            accels = np.abs(np.diff(velocities))
            accel = float(np.mean(accels)) if len(accels) > 0 else 0.0

        # Symmetry: cosine similarity left/right shoulder and wrist
        cur = frames[-1]
        left_arm = np.concatenate([cur[SHOULDER_LEFT], cur[WRIST_LEFT]])
        right_arm = np.concatenate([cur[SHOULDER_RIGHT], cur[WRIST_RIGHT]])

        norm_l = np.linalg.norm(left_arm)
        norm_r = np.linalg.norm(right_arm)
        symmetry = 0.0
        if norm_l > 1e-6 and norm_r > 1e-6:
            symmetry = float(np.dot(left_arm, right_arm) / (norm_l * norm_r))

        return speed, accel, symmetry
