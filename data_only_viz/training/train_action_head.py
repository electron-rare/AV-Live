"""Train ActionHead on the windowed dataset.

Usage:
    uv run python -m data_only_viz.training.train_action_head \
        --dataset ~/.cache/av-live-action/dataset/dataset.jsonl \
        --ckpt-out ~/.cache/av-live-action/checkpoints/action_head.pt \
        --device mps --epochs 50 --batch-size 128
"""
from __future__ import annotations

import argparse
import json
import logging
from collections import Counter
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

from data_only_viz.action_head import (
    ActionHeadModel,
    EXPR_DIM,
    FeatureExtractor,
    HIP_LEFT,
    HIP_RIGHT,
    LABELS,
)
from data_only_viz.training.augment import random_augment
from data_only_viz.training.dataset import (
    DatasetRow,
    load_dataset_jsonl,
    split_by_session,
)

LOG = logging.getLogger("train_action_head")
LABEL_TO_IDX = {l: i for i, l in enumerate(LABELS)}


class WindowDataset(Dataset[tuple[torch.Tensor, int]]):
    def __init__(self, rows: list[DatasetRow],
                 augment: bool = False, seed: int = 0) -> None:
        self._rows = rows
        self._augment = augment
        self._rng = np.random.default_rng(seed)

    def __len__(self) -> int:
        return len(self._rows)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, int]:
        row = self._rows[idx]
        stack = row.j3d_stack
        if self._augment:
            stack = random_augment(stack, self._rng)
        T = stack.shape[0]
        # expression and mouth_open stacks (zeros if absent / legacy)
        if row.expr_stack is not None:
            expr_s = row.expr_stack.astype(np.float32)
        else:
            expr_s = np.zeros((T, EXPR_DIM), dtype=np.float32)
        if row.mouth_open_stack is not None:
            mouth_s = row.mouth_open_stack.astype(np.float32)
        else:
            mouth_s = np.zeros(T, dtype=np.float32)
        feats = []
        prev = stack[0]
        prev_vel = np.zeros_like(prev)
        for t in range(T):
            cur = stack[t]
            vel = cur - prev
            accel = vel - prev_vel
            hip_y = float((cur[HIP_LEFT, 1] + cur[HIP_RIGHT, 1]) * 0.5)
            knee_angle = FeatureExtractor._mean_knee_angle(cur)
            sym = FeatureExtractor._symmetry_score(vel)
            expr_t = expr_s[t] if t < len(expr_s) else np.zeros(EXPR_DIM, dtype=np.float32)
            expr_vec = np.zeros(EXPR_DIM, dtype=np.float32)
            n = min(EXPR_DIM, len(expr_t))
            expr_vec[:n] = expr_t[:n]
            mouth_t = float(mouth_s[t]) if t < len(mouth_s) else 0.0
            feat = np.concatenate([
                cur.reshape(-1), vel.reshape(-1), accel.reshape(-1),
                expr_vec,
                np.array([hip_y, knee_angle, sym, mouth_t], dtype=np.float32),
            ]).astype(np.float32, copy=False)
            feats.append(feat)
            prev_vel = vel
            prev = cur
        x = torch.from_numpy(np.stack(feats))
        y = LABEL_TO_IDX[row.label]
        return x, y


def _class_weights(rows: list[DatasetRow]) -> torch.Tensor:
    counts = Counter(r.label for r in rows)
    total = sum(counts.values())
    weights = torch.tensor([
        total / (len(LABELS) * counts.get(l, 1)) for l in LABELS
    ], dtype=torch.float32)
    return weights


def _run_epoch(model: nn.Module, loader: DataLoader, loss_fn: nn.Module,
               optim: torch.optim.Optimizer | None,
               device: str) -> tuple[float, float]:
    train_mode = optim is not None
    model.train(train_mode)
    total_loss = 0.0
    correct = 0
    seen = 0
    for x, y in loader:
        x = x.to(device)
        y = y.to(device)
        B, T, _ = x.shape
        h = model.init_hidden(batch=B, device=device)
        logits_last: torch.Tensor | None = None
        for t in range(T):
            logits, h = model(x[:, t, :], h)
            logits_last = logits
        assert logits_last is not None
        loss = loss_fn(logits_last, y)
        if train_mode:
            optim.zero_grad()
            loss.backward()
            optim.step()
        total_loss += float(loss) * B
        correct += int((logits_last.argmax(-1) == y).sum())
        seen += B
    return total_loss / max(1, seen), correct / max(1, seen)


def train(*,
          dataset_path: Path,
          ckpt_out: Path,
          epochs: int = 50,
          batch_size: int = 128,
          lr: float = 1e-3,
          device: str = "cpu",
          seed: int = 0,
          log_every: int = 1,
          ) -> dict[str, list[float]]:
    torch.manual_seed(seed)
    rows = load_dataset_jsonl(dataset_path)
    train_rows, val_rows, _test_rows = split_by_session(rows, seed=seed)
    LOG.info("train=%d val=%d", len(train_rows), len(val_rows))
    train_ds = WindowDataset(train_rows, augment=True, seed=seed)
    val_ds = WindowDataset(val_rows, augment=False, seed=seed)
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False)
    model = ActionHeadModel().to(device)
    weights = _class_weights(train_rows).to(device)
    loss_fn = nn.CrossEntropyLoss(weight=weights)
    optim = torch.optim.AdamW(model.parameters(), lr=lr)
    history: dict[str, list[float]] = {
        "train_loss": [], "train_acc": [], "val_loss": [], "val_acc": [],
    }
    best_val_acc = -1.0
    ckpt_out.parent.mkdir(parents=True, exist_ok=True)
    for ep in range(epochs):
        tl, ta = _run_epoch(model, train_loader, loss_fn, optim, device)
        with torch.no_grad():
            vl, va = _run_epoch(model, val_loader, loss_fn, None, device)
        history["train_loss"].append(tl)
        history["train_acc"].append(ta)
        history["val_loss"].append(vl)
        history["val_acc"].append(va)
        if ep % log_every == 0 or ep == epochs - 1:
            LOG.info("ep=%d train_loss=%.4f train_acc=%.3f val_loss=%.4f val_acc=%.3f",
                     ep, tl, ta, vl, va)
        if va > best_val_acc:
            best_val_acc = va
            torch.save({"model_state_dict": model.state_dict(),
                        "version": 1, "val_acc": va}, ckpt_out)
    return history


def _cli() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", required=True, type=Path)
    p.add_argument("--ckpt-out", required=True, type=Path)
    p.add_argument("--epochs", type=int, default=50)
    p.add_argument("--batch-size", type=int, default=128)
    p.add_argument("--lr", type=float, default=1e-3)
    p.add_argument("--device", default="cpu",
                   choices=["cpu", "mps", "cuda"])
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s [%(name)s] %(message)s")
    hist = train(dataset_path=args.dataset, ckpt_out=args.ckpt_out,
                 epochs=args.epochs, batch_size=args.batch_size,
                 lr=args.lr, device=args.device, seed=args.seed)
    print(json.dumps({"final": {k: v[-1] for k, v in hist.items()}}))


if __name__ == "__main__":
    _cli()
