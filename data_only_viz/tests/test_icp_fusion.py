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


def test_partition_lidar_by_pid_two_people() -> None:
    from data_only_viz.icp_fusion import partition_lidar_by_pid

    src_a = _synthetic_smplx_torso(seed=10) + np.array([-0.75, 0.0, 0.0], dtype=np.float32)
    src_b = _synthetic_smplx_torso(seed=11) + np.array([+0.75, 0.0, 0.0], dtype=np.float32)
    pelvis_a = src_a.mean(axis=0)
    pelvis_b = src_b.mean(axis=0)

    lidar = np.concatenate([
        src_a + 0.01 * np.random.RandomState(20).randn(*src_a.shape).astype(np.float32),
        src_b + 0.01 * np.random.RandomState(21).randn(*src_b.shape).astype(np.float32),
        np.array([[10.0, 10.0, 10.0]] * 100, dtype=np.float32),
    ])

    parts = partition_lidar_by_pid(lidar, pelvises={0: pelvis_a, 1: pelvis_b}, max_dist_m=1.0)

    assert set(parts.keys()) == {0, 1}
    assert parts[0].shape[0] > 1000
    assert parts[1].shape[0] > 1000
    assert not np.any(np.linalg.norm(parts[0] - np.array([10, 10, 10]), axis=1) < 0.5)
    assert not np.any(np.linalg.norm(parts[1] - np.array([10, 10, 10]), axis=1) < 0.5)


def test_partition_returns_empty_dict_when_no_pelvises() -> None:
    from data_only_viz.icp_fusion import partition_lidar_by_pid

    out = partition_lidar_by_pid(np.zeros((100, 3), dtype=np.float32), pelvises={}, max_dist_m=1.0)
    assert out == {}


def test_fusion_worker_in_place_update(monkeypatch) -> None:
    from data_only_viz.icp_fusion import FusionWorker, IcpConfig
    from data_only_viz.lidar_calib import Extrinsic
    from data_only_viz.state import SMPLXPerson, State

    src = _synthetic_smplx_torso(seed=30)
    verts = np.zeros((10475, 3), dtype=np.float32)
    verts[: src.shape[0]] = src
    verts[5559] = src.mean(axis=0)

    person = SMPLXPerson(pid=0, vertices_3d=verts.copy())
    state = State()
    state.persons_smplx = [person]

    lidar_pts = src + np.array([0.0, 0.04, 0.0], dtype=np.float32)
    state.lidar_points = lidar_pts
    state.lidar_timestamp_ns = 1

    worker = FusionWorker(
        extrinsic=Extrinsic.identity(),
        config=IcpConfig(),
    )
    metadata = worker.run_once(state)

    assert metadata.applied == {0}
    delta = state.persons_smplx[0].vertices_3d[5559] - verts[5559]
    assert 0.02 <= delta[1] <= 0.06


def test_fusion_worker_skips_when_no_lidar() -> None:
    from data_only_viz.icp_fusion import FusionWorker, IcpConfig
    from data_only_viz.lidar_calib import Extrinsic
    from data_only_viz.state import SMPLXPerson, State

    verts = np.zeros((10475, 3), dtype=np.float32)
    verts[5559] = [0.0, 1.0, 2.0]
    state = State()
    state.persons_smplx = [SMPLXPerson(pid=0, vertices_3d=verts.copy())]
    state.lidar_points = None

    worker = FusionWorker(extrinsic=Extrinsic.identity(), config=IcpConfig())
    metadata = worker.run_once(state)
    assert metadata.applied == set()
    np.testing.assert_array_equal(state.persons_smplx[0].vertices_3d, verts)
