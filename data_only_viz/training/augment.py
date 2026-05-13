"""On-the-fly augmentations for j3d windows."""
from __future__ import annotations

import numpy as np

# SMPL-X left/right joint mirror map (subset 22 joints used by Multi-HMR).
MIRROR_MAP: tuple[int, ...] = (
    0,
    2, 1,
    3,
    5, 4,
    6,
    8, 7,
    9,
    11, 10,
    12,
    14, 13,
    15,
    17, 16,
    19, 18,
    21, 20,
)


def mirror_x(stack: np.ndarray) -> np.ndarray:
    """Mirror across the YZ plane: flip x and swap left↔right joints."""
    out = stack[:, list(MIRROR_MAP), :].copy()
    out[..., 0] = -out[..., 0]
    return out


def add_noise(stack: np.ndarray, sigma: float, rng: np.random.Generator) -> np.ndarray:
    noise = rng.normal(scale=sigma, size=stack.shape).astype(np.float32)
    return (stack + noise).astype(np.float32, copy=False)


def time_stretch(stack: np.ndarray, factor: float,
                 rng: np.random.Generator | None = None) -> np.ndarray:
    """Resample the time axis with linear interpolation, keep window_len fixed."""
    T = stack.shape[0]
    new_T = int(round(T * factor))
    new_T = max(2, new_T)
    src = np.linspace(0.0, T - 1, num=new_T)
    interp = np.empty((new_T, *stack.shape[1:]), dtype=np.float32)
    lo = np.floor(src).astype(int)
    hi = np.minimum(lo + 1, T - 1)
    frac = (src - lo).astype(np.float32)
    interp = (1 - frac[:, None, None]) * stack[lo] + frac[:, None, None] * stack[hi]
    if new_T >= T:
        start = (new_T - T) // 2
        return interp[start:start + T].astype(np.float32, copy=False)
    pad_before = (T - new_T) // 2
    pad_after = T - new_T - pad_before
    return np.concatenate([
        np.repeat(interp[:1], pad_before, axis=0),
        interp,
        np.repeat(interp[-1:], pad_after, axis=0),
    ]).astype(np.float32, copy=False)


def rotate_y(stack: np.ndarray, angle_rad: float) -> np.ndarray:
    """Rotate around Y (vertical) axis."""
    c, s = np.cos(angle_rad), np.sin(angle_rad)
    R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=np.float32)
    return (stack @ R.T).astype(np.float32, copy=False)


def random_augment(stack: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = stack
    if rng.random() < 0.5:
        out = mirror_x(out)
    if rng.random() < 0.8:
        out = add_noise(out, sigma=0.01, rng=rng)
    if rng.random() < 0.5:
        factor = float(rng.uniform(0.9, 1.1))
        out = time_stretch(out, factor=factor, rng=rng)
    if rng.random() < 0.5:
        angle = float(rng.uniform(-np.deg2rad(15), np.deg2rad(15)))
        out = rotate_y(out, angle_rad=angle)
    return out
