"""NLFWorker must bail out after FAIL_THRESHOLD consecutive inference failures."""

import sys
import threading
from unittest.mock import MagicMock

import pytest

from data_only_viz.nlf_worker import NLFWorker, FAIL_THRESHOLD
from data_only_viz.state import State


def _make_fake_torch(raises: bool = True):
    """Return a MagicMock that quacks like torch for _run()."""
    fake_model = MagicMock()
    if raises:
        fake_model.detect_smpl_batched.side_effect = NotImplementedError("CUDA only")
    else:
        pred = MagicMock()
        pred.get.return_value = None  # verts_all is None → continues normally
        fake_model.detect_smpl_batched.return_value = pred
    fake_model.eval.return_value = fake_model

    mock_torch = MagicMock()
    mock_torch.jit.load.return_value = fake_model
    mock_torch.backends.mps.is_available.return_value = False
    tensor = MagicMock()
    mock_torch.from_numpy.return_value = tensor
    tensor.permute.return_value = tensor
    tensor.unsqueeze.return_value = tensor
    tensor.to.return_value = tensor

    # inference_mode() used as context manager
    ctx = MagicMock()
    ctx.__enter__ = MagicMock(return_value=None)
    ctx.__exit__ = MagicMock(return_value=False)
    mock_torch.inference_mode.return_value = ctx

    return mock_torch


def _make_fake_cv2():
    mock_cv2 = MagicMock()
    cap = MagicMock()
    cap.isOpened.return_value = True
    cap.read.return_value = (True, MagicMock())
    mock_cv2.VideoCapture.return_value = cap
    mock_cv2.cvtColor.return_value = MagicMock()
    mock_cv2.CAP_PROP_FRAME_WIDTH = 3
    mock_cv2.CAP_PROP_FRAME_HEIGHT = 4
    mock_cv2.COLOR_BGR2RGB = 4
    return mock_cv2


def test_bailout_after_threshold_failures(tmp_path):
    # Inject fake torch and cv2 into sys.modules before _run() does its imports
    fake_torch = _make_fake_torch(raises=True)
    fake_cv2 = _make_fake_cv2()

    # Patch ckpt_path to a fake existing file so the worker doesn't abort early
    fake_ckpt = tmp_path / "fake.torchscript"
    fake_ckpt.write_bytes(b"")

    original_torch = sys.modules.get("torch")
    original_cv2 = sys.modules.get("cv2")
    sys.modules["torch"] = fake_torch
    sys.modules["cv2"] = fake_cv2
    try:
        state = State()
        worker = NLFWorker(state, num_persons=1, target_fps=1000.0, device="cpu")
        worker.ckpt_path = fake_ckpt

        t = threading.Thread(target=worker._run, daemon=True)
        t.start()
        t.join(timeout=4.0)
    finally:
        if original_torch is None:
            sys.modules.pop("torch", None)
        else:
            sys.modules["torch"] = original_torch
        if original_cv2 is None:
            sys.modules.pop("cv2", None)
        else:
            sys.modules["cv2"] = original_cv2

    assert not t.is_alive(), "worker should exit after threshold failures"
    assert worker.failure_count >= FAIL_THRESHOLD


def test_failure_counter_resets_on_success():
    state = State()
    worker = NLFWorker(state, num_persons=1, target_fps=10.0, device="cpu")
    worker.failure_count = FAIL_THRESHOLD - 1
    worker._record_success()
    assert worker.failure_count == 0
