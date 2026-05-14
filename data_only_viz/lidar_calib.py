"""iPhone LiDAR (ARKit world) <-> webcam (Multi-HMR camera) extrinsic.

Persisted as a small JSON document so calibration survives across launches.
The default location is ``~/.config/av-live/lidar_extrinsic.json``; override
with the ``ICP_LIDAR_EXTRINSIC`` env var.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

DEFAULT_EXTRINSIC_PATH = Path.home() / ".config" / "av-live" / "lidar_extrinsic.json"


@dataclass
class Extrinsic:
    """4x4 rigid transform from ARKit world frame to Multi-HMR camera frame."""

    T_arkit_to_cam: np.ndarray = field(default_factory=lambda: np.eye(4))
    confidence: float = 0.0
    captured_at_iso: str = ""

    @staticmethod
    def identity() -> "Extrinsic":
        return Extrinsic(T_arkit_to_cam=np.eye(4), confidence=0.0, captured_at_iso="")


def save_extrinsic(e: Extrinsic, path: Path | None = None) -> Path:
    path = Path(path) if path is not None else _path_from_env()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "T_arkit_to_cam": e.T_arkit_to_cam.astype(float).tolist(),
        "confidence": float(e.confidence),
        "captured_at_iso": e.captured_at_iso,
    }
    path.write_text(json.dumps(payload, indent=2))
    return path


def load_extrinsic(path: Path | None = None) -> Extrinsic:
    path = Path(path) if path is not None else _path_from_env()
    if not path.exists():
        return Extrinsic.identity()
    payload = json.loads(path.read_text())
    return Extrinsic(
        T_arkit_to_cam=np.array(payload["T_arkit_to_cam"], dtype=np.float64),
        confidence=float(payload.get("confidence", 0.0)),
        captured_at_iso=str(payload.get("captured_at_iso", "")),
    )


def _path_from_env() -> Path:
    p = os.environ.get("ICP_LIDAR_EXTRINSIC")
    return Path(p) if p else DEFAULT_EXTRINSIC_PATH


def kabsch_rigid(src: np.ndarray, tgt: np.ndarray) -> np.ndarray:
    """Closed-form rigid alignment (Kabsch via SVD).

    Returns a 4x4 transform T such that ``tgt ≈ (src @ R.T) + t``.
    """
    src = np.asarray(src, dtype=np.float64)
    tgt = np.asarray(tgt, dtype=np.float64)
    if src.shape != tgt.shape:
        raise ValueError(f"shape mismatch: src={src.shape} tgt={tgt.shape}")
    if src.shape[0] < 3 or src.shape[1] != 3:
        raise ValueError("kabsch_rigid needs at least 3 paired 3D points")
    src_c = src.mean(axis=0)
    tgt_c = tgt.mean(axis=0)
    H = (src - src_c).T @ (tgt - tgt_c)
    U, _, Vt = np.linalg.svd(H)
    d = np.linalg.det(Vt.T @ U.T)
    D = np.diag([1.0, 1.0, np.sign(d)])
    R = Vt.T @ D @ U.T
    t = tgt_c - R @ src_c
    T = np.eye(4)
    T[:3, :3] = R
    T[:3, 3] = t
    return T
