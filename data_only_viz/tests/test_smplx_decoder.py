"""Test minimal : le decoder doit produire (10475, 3) vertices depuis
les params canoniques (T-pose, shape neutre)."""
from pathlib import Path

import pytest
import numpy as np

SMPLX = (Path.home() / ".cache" / "av-live-multihmr"
         / "models" / "smplx" / "SMPLX_NEUTRAL.npz")


@pytest.mark.skipif(not SMPLX.exists(), reason="SMPL-X model not installed")
def test_decode_neutral_tpose():
    from data_only_viz.smplx_decoder import SMPLXDecoder
    dec = SMPLXDecoder(str(SMPLX), device="cpu")
    verts, joints = dec.decode_neutral()
    assert verts.shape == (10475, 3)
    assert joints.shape[1] == 3
    # SMPL-X NEUTRAL T-pose : pelvis ~0.35m sous le bary mesh, mesh plein
    # taille (1.5-2m sur y, et x comparable car bras tendus).
    assert np.linalg.norm(joints[0]) < 1.0
    assert 1.3 < verts[:, 1].ptp() < 2.5, "y extent suspect"
    assert 1.3 < verts[:, 0].ptp() < 2.5, "x extent (bras tendus) suspect"
