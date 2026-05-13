"""SMPLXPerson fields are numpy float32 arrays after Plan 1 Tasks 5 & 6."""

import numpy as np

from data_only_viz.state import SMPLXPerson


def test_smplxperson_accepts_ndarrays():
    p = SMPLXPerson(
        pid=0,
        confidence=1.0,
        translation=np.zeros(3, dtype=np.float32),
        betas=np.zeros(10, dtype=np.float32),
        expression=np.zeros(10, dtype=np.float32),
        vertices_3d=np.zeros((10475, 3), dtype=np.float32),
    )
    assert isinstance(p.vertices_3d, np.ndarray)
    assert p.vertices_3d.dtype == np.float32
    assert p.vertices_3d.shape == (10475, 3)
    assert isinstance(p.translation, np.ndarray)
    assert isinstance(p.betas, np.ndarray)
    assert isinstance(p.expression, np.ndarray)


def test_smplxperson_does_not_have_joints_3d():
    """Plan 1 Task 6 removed the joints_3d field."""
    p = SMPLXPerson(
        pid=0,
        confidence=1.0,
        translation=np.zeros(3, dtype=np.float32),
        betas=np.zeros(10, dtype=np.float32),
        expression=np.zeros(10, dtype=np.float32),
        vertices_3d=np.zeros((10475, 3), dtype=np.float32),
    )
    assert not hasattr(p, "joints_3d"), "joints_3d was removed in Plan 1 Task 6"
