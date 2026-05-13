"""Smoke test for action-head training (2 epochs, tiny dataset, CPU)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

torch = pytest.importorskip("torch")


def _make_tiny_dataset(tmp_path: Path) -> Path:
    from data_only_viz.training.dataset import DatasetRow, write_dataset_jsonl
    rng = np.random.default_rng(0)
    rows = []
    for sess_i, sess in enumerate(("s01", "s02", "s03")):
        for w in range(30):
            label = ("debout", "assise", "danse")[w % 3]
            rows.append(DatasetRow(
                window_id=f"{sess}_w{w:03d}",
                label=label,
                j3d_stack=rng.normal(size=(16, 32, 3)).astype(np.float32),
                session=sess, pid_local=1,
                auto_label_confidence=0.8,
                manually_validated=True,
                expr_stack=np.zeros((16, 10), dtype=np.float32),
                mouth_open_stack=np.zeros(16, dtype=np.float32),
            ))
    out = tmp_path / "tiny.jsonl"
    write_dataset_jsonl(rows, out)
    return out


def test_train_2_epochs_no_crash(tmp_path: Path) -> None:
    from data_only_viz.training.train_action_head import train
    ds = _make_tiny_dataset(tmp_path)
    ckpt = tmp_path / "ckpt.pt"
    history = train(
        dataset_path=ds,
        ckpt_out=ckpt,
        epochs=2,
        batch_size=8,
        lr=1e-3,
        device="cpu",
        seed=0,
        log_every=10_000,
    )
    assert ckpt.exists()
    assert len(history["train_loss"]) == 2
    assert all(np.isfinite(history["train_loss"]))


def test_trained_checkpoint_loadable(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead
    from data_only_viz.training.train_action_head import train
    ds = _make_tiny_dataset(tmp_path)
    ckpt = tmp_path / "ckpt.pt"
    train(dataset_path=ds, ckpt_out=ckpt, epochs=1, batch_size=8,
          lr=1e-3, device="cpu", seed=0, log_every=10_000)
    head = ActionHead(ckpt_path=ckpt)
    for i in range(5):
        label, probs, _ = head.step(pid=1, j3d=np.zeros((32, 3), dtype=np.float32))
    assert abs(float(probs.sum()) - 1.0) < 1e-5
