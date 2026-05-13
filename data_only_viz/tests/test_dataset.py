"""Tests for dataset jsonl IO + sliding windows + split."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest


def _make_session_jsonl(path: Path, n_frames: int = 64) -> None:
    rng = np.random.default_rng(0)
    with path.open("w") as f:
        for t in range(n_frames):
            row = {"ts": t / 30.0,
                   "session": "sess01",
                   "pid": 1,
                   "j3d": rng.normal(size=(32, 3)).tolist()}
            f.write(json.dumps(row) + "\n")


def test_load_frames_jsonl(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import load_frames_jsonl
    p = tmp_path / "raw.jsonl"
    _make_session_jsonl(p)
    frames = load_frames_jsonl(p)
    assert len(frames) == 64
    assert frames[0].j3d.shape == (32, 3)
    assert frames[0].pid == 1
    assert frames[0].session == "sess01"


def test_sliding_windows(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import (
        load_frames_jsonl,
        sliding_windows,
    )
    p = tmp_path / "raw.jsonl"
    _make_session_jsonl(p, n_frames=64)
    frames = load_frames_jsonl(p)
    windows = list(sliding_windows(frames, window_len=16, stride=4))
    assert len(windows) == 13
    assert windows[0].j3d_stack.shape == (16, 32, 3)
    assert windows[0].session == "sess01"


def test_write_and_load_dataset_jsonl(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import (
        DatasetRow,
        load_dataset_jsonl,
        write_dataset_jsonl,
    )
    rng = np.random.default_rng(0)
    rows = [
        DatasetRow(
            window_id=f"sess01_pid1_w{i:04d}",
            label="debout" if i % 2 == 0 else "danse",
            j3d_stack=rng.normal(size=(16, 32, 3)).astype(np.float32),
            session="sess01",
            pid_local=1,
            auto_label_confidence=0.8,
            manually_validated=False,
        )
        for i in range(5)
    ]
    out = tmp_path / "ds.jsonl"
    write_dataset_jsonl(rows, out)
    loaded = load_dataset_jsonl(out)
    assert len(loaded) == 5
    assert loaded[0].label == "debout"
    assert loaded[0].j3d_stack.shape == (16, 32, 3)
    assert np.allclose(loaded[0].j3d_stack, rows[0].j3d_stack, atol=1e-6)


def test_split_by_session(tmp_path: Path) -> None:
    from data_only_viz.training.dataset import DatasetRow, split_by_session
    rng = np.random.default_rng(0)
    rows = []
    for sess in ("s01", "s02", "s03", "s04", "s05", "s06", "s07"):
        rows.append(DatasetRow(
            window_id=f"{sess}_w0", label="debout",
            j3d_stack=rng.normal(size=(16, 32, 3)).astype(np.float32),
            session=sess, pid_local=1, auto_label_confidence=0.7,
            manually_validated=False,
        ))
    train, val, test = split_by_session(rows, ratios=(0.7, 0.15, 0.15), seed=0)
    all_sessions = {r.session for r in train + val + test}
    assert all_sessions == {"s01","s02","s03","s04","s05","s06","s07"}
    train_s = {r.session for r in train}
    val_s = {r.session for r in val}
    test_s = {r.session for r in test}
    assert train_s.isdisjoint(val_s)
    assert train_s.isdisjoint(test_s)
    assert val_s.isdisjoint(test_s)
