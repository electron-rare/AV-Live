"""Evaluate a trained action-head checkpoint."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

from data_only_viz.action_head import ActionHeadModel, LABELS
from data_only_viz.training.dataset import load_dataset_jsonl, split_by_session
from data_only_viz.training.train_action_head import (
    LABEL_TO_IDX,
    WindowDataset,
)


def confusion_matrix(true: list[int], pred: list[int],
                     num_classes: int = 3) -> np.ndarray:
    cm = np.zeros((num_classes, num_classes), dtype=np.int64)
    for t, p in zip(true, pred):
        cm[t, p] += 1
    return cm


def evaluate(ckpt_path: Path, dataset_path: Path, device: str = "cpu",
             seed: int = 0) -> dict:
    rows = load_dataset_jsonl(dataset_path)
    _train, _val, test_rows = split_by_session(rows, seed=seed)
    if not test_rows:
        test_rows = rows
    ds = WindowDataset(test_rows, augment=False, seed=seed)
    loader = DataLoader(ds, batch_size=64, shuffle=False)
    model = ActionHeadModel().to(device).eval()
    payload = torch.load(ckpt_path, map_location=device, weights_only=True)
    model.load_state_dict(payload["model_state_dict"])
    true: list[int] = []
    pred: list[int] = []
    with torch.no_grad():
        for x, y in loader:
            x = x.to(device); y = y.to(device)
            B, T, _ = x.shape
            h = model.init_hidden(batch=B, device=device)
            logits = None
            for t in range(T):
                logits, h = model(x[:, t, :], h)
            true.extend(y.cpu().tolist())
            pred.extend(logits.argmax(-1).cpu().tolist())
    cm = confusion_matrix(true, pred)
    acc = float(np.trace(cm) / max(1, cm.sum()))
    confusion_db = float((cm[0, 2] + cm[2, 0]) / max(1, cm.sum()))
    feat_dim = ds[0][0].shape[-1]
    bench_x = torch.zeros(1, feat_dim, device=device)
    h = model.init_hidden(batch=1, device=device)
    for _ in range(20):
        _ = model(bench_x, h)
    t0 = time.perf_counter()
    N = 500
    for _ in range(N):
        _, h = model(bench_x, h)
    lat_ms = (time.perf_counter() - t0) * 1000.0 / N
    return {
        "test_acc": acc,
        "confusion_debout_danse": confusion_db,
        "confusion_matrix": cm.tolist(),
        "labels": list(LABELS),
        "step_latency_ms": lat_ms,
        "n_test": int(cm.sum()),
    }


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ckpt", required=True, type=Path)
    p.add_argument("--dataset", required=True, type=Path)
    p.add_argument("--device", default="cpu",
                   choices=["cpu", "mps", "cuda"])
    args = p.parse_args()
    out = evaluate(args.ckpt, args.dataset, device=args.device)
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    _cli()
