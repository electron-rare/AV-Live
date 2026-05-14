"""ICP fusion between Multi-HMR SMPL-X meshes and iPhone LiDAR point clouds.

All operations happen in the **webcam camera frame** (meters, OpenCV
convention: +X right, +Y down, +Z forward). LiDAR points must be
pre-transformed via `Extrinsic.T_arkit_to_cam`.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

import numpy as np

try:
    import open3d as o3d
except ImportError:  # pragma: no cover - exercised via skipif at import sites
    o3d = None  # type: ignore[assignment]

_LOG = logging.getLogger(__name__)

MIN_LIDAR_POINTS = 200
MIN_FITNESS = 0.30
MAX_RMSE_M = 0.05
CROP_MARGIN_M = 0.30


@dataclass
class IcpConfig:
    voxel_size_m: float = 0.02
    max_correspondence_m: float = 0.05
    max_iterations: int = 30


@dataclass
class IcpResult:
    vertices_registered: np.ndarray
    accepted: bool
    fitness: float
    rmse_m: float
    iterations: int


def register_mesh_to_lidar(
    smplx_verts_cam: np.ndarray,
    lidar_points_cam: np.ndarray,
    config: IcpConfig | None = None,
) -> IcpResult:
    """Register SMPL-X verts onto a cropped LiDAR neighborhood."""
    if o3d is None:
        raise RuntimeError("open3d not installed — install with `uv sync --extra lidar`")

    cfg = config or IcpConfig()
    src = np.ascontiguousarray(smplx_verts_cam, dtype=np.float32)

    if not np.isfinite(src).all():
        _LOG.debug("ICP rejected: NaN/Inf in SMPL-X verts")
        return IcpResult(src, False, 0.0, float("inf"), 0)

    lidar = _crop_to_bbox(lidar_points_cam, src, margin_m=CROP_MARGIN_M)
    if lidar.shape[0] < MIN_LIDAR_POINTS or not np.isfinite(lidar).all():
        _LOG.debug("ICP rejected: insufficient LiDAR points (%d)", lidar.shape[0])
        return IcpResult(src, False, 0.0, float("inf"), 0)

    src_pcd = _to_pcd(src, cfg.voxel_size_m, estimate_normals=True)
    tgt_pcd = _to_pcd(lidar, cfg.voxel_size_m, estimate_normals=True)

    if len(src_pcd.points) < 10 or len(tgt_pcd.points) < 10:
        return IcpResult(src, False, 0.0, float("inf"), 0)

    criteria = o3d.pipelines.registration.ICPConvergenceCriteria(
        max_iteration=cfg.max_iterations,
        relative_fitness=1e-6,
        relative_rmse=1e-6,
    )
    # Coarse-to-fine: a wide first pass handles translations larger than the
    # final correspondence threshold, then the strict pass refines and gates.
    coarse = o3d.pipelines.registration.registration_icp(
        src_pcd, tgt_pcd, max(cfg.max_correspondence_m * 5.0, 0.20),
        np.eye(4),
        o3d.pipelines.registration.TransformationEstimationPointToPlane(),
        criteria,
    )
    result = o3d.pipelines.registration.registration_icp(
        src_pcd, tgt_pcd, cfg.max_correspondence_m,
        coarse.transformation,
        o3d.pipelines.registration.TransformationEstimationPointToPlane(),
        criteria,
    )

    accepted = (result.fitness >= MIN_FITNESS) and (result.inlier_rmse <= MAX_RMSE_M)
    if not accepted:
        _LOG.debug("ICP rejected: fitness=%.3f rmse=%.4f", result.fitness, result.inlier_rmse)
        return IcpResult(src, False, float(result.fitness), float(result.inlier_rmse), 0)

    T = np.asarray(result.transformation, dtype=np.float32)
    homog = np.concatenate([src, np.ones((src.shape[0], 1), dtype=np.float32)], axis=1)
    fused = (homog @ T.T)[:, :3]
    if not np.isfinite(fused).all():
        return IcpResult(src, False, float(result.fitness), float(result.inlier_rmse), 0)

    return IcpResult(
        vertices_registered=np.ascontiguousarray(fused, dtype=np.float32),
        accepted=True,
        fitness=float(result.fitness),
        rmse_m=float(result.inlier_rmse),
        iterations=cfg.max_iterations,
    )


def _crop_to_bbox(points: np.ndarray, anchor: np.ndarray, margin_m: float) -> np.ndarray:
    if points.size == 0:
        return points.astype(np.float32, copy=False)
    lo = anchor.min(axis=0) - margin_m
    hi = anchor.max(axis=0) + margin_m
    mask = np.all((points >= lo) & (points <= hi), axis=1)
    return points[mask].astype(np.float32, copy=False)


def _to_pcd(points: np.ndarray, voxel_size_m: float, estimate_normals: bool):
    pcd = o3d.geometry.PointCloud()
    pcd.points = o3d.utility.Vector3dVector(points.astype(np.float64, copy=False))
    if voxel_size_m > 0:
        pcd = pcd.voxel_down_sample(voxel_size_m)
    if estimate_normals:
        pcd.estimate_normals(
            search_param=o3d.geometry.KDTreeSearchParamHybrid(radius=voxel_size_m * 2, max_nn=30),
        )
    return pcd
