"""Tests for ICP registration of SMPL-X verts onto LiDAR point clouds."""
from __future__ import annotations

import numpy as np
import pytest

pytest.importorskip("open3d")


def _synthetic_smplx_torso(n: int = 1500, seed: int = 0) -> np.ndarray:
    """Generate a coarse capsule-like point cloud standing in for SMPL-X verts."""
    rng = np.random.RandomState(seed)
    z = rng.uniform(0.0, 1.7, size=n)
    r = 0.12 + 0.02 * rng.randn(n)
    theta = rng.uniform(0, 2 * np.pi, size=n)
    x = r * np.cos(theta)
    y = r * np.sin(theta)
    return np.stack([x, y, z], axis=1).astype(np.float32)


def test_icp_recovers_small_translation() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=1)
    translation = np.array([0.05, 0.02, 0.10], dtype=np.float32)
    tgt = src + translation + 0.005 * np.random.RandomState(2).randn(*src.shape).astype(np.float32)

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())

    assert out.accepted, f"ICP should accept, got fitness={out.fitness:.3f}"
    truth = src + translation
    err_before = np.linalg.norm(src - truth, axis=1).mean()
    err_after = np.linalg.norm(out.vertices_registered - truth, axis=1).mean()
    assert err_after < err_before * 0.5, f"err before={err_before:.4f} after={err_after:.4f}"


def test_icp_rejects_when_lidar_too_sparse() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=3)
    tgt = src[:5]

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert not out.accepted
    np.testing.assert_array_equal(out.vertices_registered, src)


def test_icp_rejects_on_nan_input() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=4)
    src[10, 1] = np.nan
    tgt = src.copy()
    tgt = np.nan_to_num(tgt, nan=0.0)

    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert not out.accepted
    np.testing.assert_array_equal(out.vertices_registered, src)


def test_icp_preserves_dtype_and_shape() -> None:
    from data_only_viz.icp_fusion import IcpConfig, register_mesh_to_lidar

    src = _synthetic_smplx_torso(seed=5)
    tgt = src + np.array([0.0, 0.0, 0.02], dtype=np.float32)
    out = register_mesh_to_lidar(src, tgt, config=IcpConfig())
    assert out.vertices_registered.shape == src.shape
    assert out.vertices_registered.dtype == np.float32
