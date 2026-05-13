"""Tests for ActionHead model (forward, step, checkpoint roundtrip)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

torch = pytest.importorskip("torch")


def _rand_j3d(seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.normal(size=(32, 3)).astype(np.float32)


def test_model_forward_shape() -> None:
    from data_only_viz.action_head import ActionHeadModel, FEATURE_DIM, NUM_CLASSES
    model = ActionHeadModel()
    x = torch.zeros(1, FEATURE_DIM)
    h = model.init_hidden(batch=1)
    logits, h_new = model(x, h)
    assert logits.shape == (1, NUM_CLASSES)
    assert h_new.shape == h.shape


def test_model_param_count_under_80k() -> None:
    from data_only_viz.action_head import ActionHeadModel
    model = ActionHeadModel()
    n = sum(p.numel() for p in model.parameters())
    assert n < 80_000, f"too many params: {n}"


def test_action_head_step_warmup_returns_debout() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)
    label, probs, kin = head.step(pid=1, j3d=_rand_j3d(0))
    assert label == LABELS[0]
    assert probs.shape == (3,)
    assert pytest.approx(float(probs[0]), abs=1e-6) == 1.0
    assert kin.shape == (3,)
    assert float(kin[0]) == 0.0


def test_action_head_step_after_warmup_returns_some_label() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)
    for i in range(5):
        label, probs, kin = head.step(pid=1, j3d=_rand_j3d(i))
    assert label in LABELS
    assert abs(float(probs.sum()) - 1.0) < 1e-5


def test_action_head_forget_resets_hidden_state(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead
    head = ActionHead(ckpt_path=None)
    for i in range(5):
        head.step(pid=1, j3d=_rand_j3d(i))
    assert 1 in head._hidden
    head.forget(1)
    assert 1 not in head._hidden
    assert head._buffers.frames_for(1) == []


def test_action_head_checkpoint_roundtrip(tmp_path: Path) -> None:
    from data_only_viz.action_head import ActionHead, ActionHeadModel
    model = ActionHeadModel()
    ckpt = tmp_path / "ah.pt"
    torch.save({"model_state_dict": model.state_dict(),
                "version": 1}, ckpt)
    head = ActionHead(ckpt_path=ckpt)
    for k, v in head._model.state_dict().items():
        assert torch.allclose(v, model.state_dict()[k])


def test_action_head_step_handles_nan() -> None:
    from data_only_viz.action_head import ActionHead, LABELS
    head = ActionHead(ckpt_path=None)
    j = _rand_j3d(0)
    j[5, 1] = float("nan")
    label, probs, _kin = head.step(pid=1, j3d=j)
    assert label in LABELS
    assert not np.isnan(probs).any()
