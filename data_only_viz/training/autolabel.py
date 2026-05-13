"""Rule-based labeler for j3d windows.

Outputs one of {"debout", "assise", "danse", None}. None marks
ambiguous windows that should be reviewed manually.

Rules are tuned for SMPL-X joint indexing as used by Multi-HMR.
"""
from __future__ import annotations

import argparse
import logging
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from data_only_viz.action_head import (
    FeatureExtractor,
    HIP_LEFT,
    HIP_RIGHT,
    WINDOW_LEN,
)


@dataclass(frozen=True)
class AutoLabelConfig:
    hip_y_seated_max: float = 0.55
    knee_angle_seated_max: float = 2.0  # rad, ~115°
    speed_static_max: float = 0.03  # m/s mean joint speed
    speed_dance_min: float = 0.033  # m/s mean joint speed
    accel_dance_min: float = 0.001


DEFAULT_CFG = AutoLabelConfig()


def autolabel_window(
    frames: list[np.ndarray], cfg: AutoLabelConfig = DEFAULT_CFG
) -> tuple[str | None, float]:
    """Return (label, confidence). label is None when ambiguous."""
    if len(frames) < WINDOW_LEN // 2:
        return None, 0.0
    cur = frames[-1]
    hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
    knee_angle = FeatureExtractor._mean_knee_angle(cur)
    kin = FeatureExtractor.kinetics(frames)
    speed = float(kin[0])
    accel = float(kin[1])

    if hip_y < cfg.hip_y_seated_max and knee_angle < cfg.knee_angle_seated_max:
        conf = 0.5 + 0.5 * min(1.0, (cfg.hip_y_seated_max - hip_y) / 0.2)
        return "assise", conf
    if speed >= cfg.speed_dance_min or accel >= cfg.accel_dance_min:
        conf = 0.5 + 0.5 * min(1.0, speed / 0.5)
        return "danse", conf
    if speed <= cfg.speed_static_max:
        conf = 0.6
        return "debout", conf
    return None, 0.0


def autolabel_dataset(
    frames_jsonl: Path,
    out_jsonl: Path,
    window_len: int = WINDOW_LEN,
    stride: int = 4,
    keep_none: bool = True,
) -> int:
    """Glue: raw frames jsonl → sliding windows → auto-label → DatasetRow jsonl.

    Returns the number of windows written.
    """
    from data_only_viz.training.dataset import (
        DatasetRow,
        load_frames_jsonl,
        sliding_windows,
        write_dataset_jsonl,
    )

    frames = load_frames_jsonl(frames_jsonl)
    rows = []
    for win in sliding_windows(frames, window_len=window_len, stride=stride):
        frame_list = [win.j3d_stack[t] for t in range(win.j3d_stack.shape[0])]
        label, conf = autolabel_window(frame_list)
        if label is None and not keep_none:
            continue
        rows.append(
            DatasetRow(
                window_id=f"{win.session}_pid{win.pid_local}_t{int(win.first_ts*1000):08d}",
                label=label if label is not None else "debout",
                j3d_stack=win.j3d_stack,
                session=win.session,
                pid_local=win.pid_local,
                auto_label_confidence=conf,
                manually_validated=False,
            )
        )
    out_jsonl.parent.mkdir(parents=True, exist_ok=True)
    write_dataset_jsonl(rows, out_jsonl)
    return len(rows)


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--frames",
        required=True,
        type=Path,
        help="Raw frames jsonl from extract_j3d_offline.py",
    )
    p.add_argument("--out", required=True, type=Path, help="Auto-labeled windowed dataset jsonl")
    p.add_argument("--stride", type=int, default=4)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO)
    n = autolabel_dataset(args.frames, args.out, stride=args.stride)
    print(f"wrote {n} windows to {args.out}")


if __name__ == "__main__":
    _cli()
