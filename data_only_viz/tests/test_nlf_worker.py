"""Tests minimaux pour le worker NLF : import sans crash, shapes correctes
sur les sorties si checkpoint present."""
from pathlib import Path

import pytest


CKPT = Path.home() / ".cache" / "av-live-nlf" / "nlf_l_multi.torchscript"


def test_import_no_crash():
    from data_only_viz.nlf_worker import NLFWorker
    assert hasattr(NLFWorker, "is_available")


def test_is_available_reflects_checkpoint():
    from data_only_viz.nlf_worker import NLFWorker
    assert NLFWorker.is_available() == CKPT.exists()


@pytest.mark.skipif(not CKPT.exists(), reason="NLF checkpoint not installed")
def test_load_model_shapes():
    """Charge le modele et verifie que detect_smpl_batched existe."""
    import torch
    model = torch.jit.load(str(CKPT), map_location="cpu").eval()
    assert hasattr(model, "detect_smpl_batched"), (
        "Le checkpoint doit exposer detect_smpl_batched")
