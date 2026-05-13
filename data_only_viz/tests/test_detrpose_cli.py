"""DETRPose model size flows from CLI through to the worker."""

import pytest

from data_only_viz.detrpose import DETRPoseWorker, DEFAULT_MODEL_SIZE


def test_default_model_size_unchanged():
    assert DEFAULT_MODEL_SIZE == "n"


def test_worker_accepts_model_size_kwarg():
    # Should not raise; we don't load the model (that requires the extra)
    worker = DETRPoseWorker.__new__(DETRPoseWorker)
    worker.model_size = None
    worker._configure_model_size("s")
    assert worker.model_size == "s"


def test_worker_rejects_invalid_model_size():
    worker = DETRPoseWorker.__new__(DETRPoseWorker)
    worker.model_size = None
    with pytest.raises(ValueError):
        worker._configure_model_size("xxxl")
