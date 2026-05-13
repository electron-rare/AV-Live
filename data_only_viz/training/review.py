"""Manual label review TUI.

Reads an auto-labeled jsonl dataset, presents each window with:
  - ASCII skeleton (front view) of last frame
  - speed/accel/sym kinetics
  - proposed label + confidence
Keys:
  1 = debout, 2 = assise, 3 = danse
  ENTER = accept proposed label
  S = skip (label = None, will not be saved)
  Q = quit and write what we have so far

Usage:
    uv run python -m data_only_viz.training.review \\
        --in ~/.cache/av-live-action/dataset/auto.jsonl \\
        --out ~/.cache/av-live-action/dataset/reviewed.jsonl
"""
from __future__ import annotations

import argparse
import sys
import termios
import tty
from pathlib import Path

import numpy as np

from data_only_viz.action_head import LABELS
from data_only_viz.training.autolabel import autolabel_window
from data_only_viz.training.dataset import (
    DatasetRow,
    load_dataset_jsonl,
    write_dataset_jsonl,
)


def _ascii_skeleton(j3d: np.ndarray, width: int = 40, height: int = 16) -> str:
    pts = j3d[:, [0, 1]]  # x, y
    mn = pts.min(axis=0)
    mx = pts.max(axis=0)
    rng = np.maximum(mx - mn, 1e-3)
    norm = (pts - mn) / rng
    grid = [[" "] * width for _ in range(height)]
    for x, y in norm:
        col = int(x * (width - 1))
        row = int((1 - y) * (height - 1))
        grid[row][col] = "*"
    return "\n".join("".join(row) for row in grid)


def _getch() -> str:
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        return sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def review(in_path: Path, out_path: Path,
           sample_validated_fraction: float = 0.2,
           seed: int = 0) -> None:
    from data_only_viz.action_head import FeatureExtractor

    rows = load_dataset_jsonl(in_path)
    rng = np.random.default_rng(seed)
    kept: list[DatasetRow] = []
    for i, r in enumerate(rows):
        proposed, conf = autolabel_window(list(r.j3d_stack))
        is_none = proposed is None
        sampled = rng.random() < sample_validated_fraction
        if not is_none and not sampled and r.manually_validated:
            kept.append(r)
            continue
        print("\033[2J\033[H")  # clear
        print(f"[{i + 1}/{len(rows)}] {r.window_id}  proposed={proposed} conf={conf:.2f}")
        print(_ascii_skeleton(r.j3d_stack[-1]))
        kin = FeatureExtractor.kinetics(list(r.j3d_stack))
        print(f"speed={kin[0]:.3f}  accel={kin[1]:.3f}  sym={kin[2]:+.3f}")
        print("keys: 1=debout 2=assise 3=danse ENTER=accept S=skip Q=quit")
        k = _getch().lower()
        if k == "q":
            break
        if k == "s":
            continue
        if k == "\r":
            chosen = proposed
        elif k in ("1", "2", "3"):
            chosen = LABELS[int(k) - 1]
        else:
            continue
        if chosen is None:
            continue
        kept.append(DatasetRow(
            window_id=r.window_id, label=chosen, j3d_stack=r.j3d_stack,
            session=r.session, pid_local=r.pid_local,
            auto_label_confidence=conf, manually_validated=True,
        ))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    write_dataset_jsonl(kept, out_path)
    print(f"\nwrote {len(kept)} rows to {out_path}")


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="in_path", required=True, type=Path)
    p.add_argument("--out", dest="out_path", required=True, type=Path)
    p.add_argument("--sample-fraction", type=float, default=0.2)
    args = p.parse_args()
    review(args.in_path, args.out_path,
           sample_validated_fraction=args.sample_fraction)


if __name__ == "__main__":
    _cli()
