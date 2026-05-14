"""Smoke test for the Open3D dependency used by ICP fusion."""
from __future__ import annotations

import numpy as np
import pytest

open3d = pytest.importorskip("open3d")


def test_open3d_pointcloud_roundtrip() -> None:
    pts = np.random.RandomState(0).randn(100, 3).astype(np.float32)
    pcd = open3d.geometry.PointCloud()
    pcd.points = open3d.utility.Vector3dVector(pts)
    out = np.asarray(pcd.points)
    assert out.shape == (100, 3)
    np.testing.assert_allclose(out, pts, atol=1e-5)


def test_open3d_icp_converges_on_translated_copy() -> None:
    rng = np.random.RandomState(1)
    src = rng.randn(500, 3).astype(np.float64)
    translation = np.array([0.10, -0.05, 0.20])
    tgt = src + translation

    src_pcd = open3d.geometry.PointCloud()
    src_pcd.points = open3d.utility.Vector3dVector(src)
    tgt_pcd = open3d.geometry.PointCloud()
    tgt_pcd.points = open3d.utility.Vector3dVector(tgt)

    result = open3d.pipelines.registration.registration_icp(
        src_pcd, tgt_pcd, max_correspondence_distance=0.5,
        init=np.eye(4),
        estimation_method=open3d.pipelines.registration.TransformationEstimationPointToPoint(),
    )
    np.testing.assert_allclose(result.transformation[:3, 3], translation, atol=1e-3)
