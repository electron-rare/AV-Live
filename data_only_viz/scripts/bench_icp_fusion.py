"""Latency / convergence bench for the ICP fusion worker.

Usage:

    cd data_only_viz
    uv run --extra lidar python -m data_only_viz.scripts.bench_icp_fusion \
        --n-frames 200 --n-people 2 --seed 0
"""
from __future__ import annotations

import argparse
import json
import time

import numpy as np

from data_only_viz.icp_fusion import FusionWorker, IcpConfig
from data_only_viz.lidar_calib import Extrinsic
from data_only_viz.state import SMPLXPerson, State


def _synth_person(seed: int, offset_x: float) -> SMPLXPerson:
    rng = np.random.RandomState(seed)
    verts = np.zeros((10475, 3), dtype=np.float32)
    pts = rng.randn(2000, 3).astype(np.float32) * 0.1
    verts[: pts.shape[0]] = pts + np.array([offset_x, 0, 1.5], dtype=np.float32)
    verts[5559] = pts.mean(axis=0) + np.array([offset_x, 0, 1.5], dtype=np.float32)
    return SMPLXPerson(pid=seed, vertices_3d=verts)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-frames", type=int, default=200)
    p.add_argument("--n-people", type=int, default=2)
    p.add_argument("--seed", type=int, default=0)
    args = p.parse_args(argv)

    rng = np.random.RandomState(args.seed)
    persons = [_synth_person(i, offset_x=-0.6 + 1.2 * i) for i in range(args.n_people)]
    state = State()
    state.persons_smplx = persons

    worker = FusionWorker(extrinsic=Extrinsic.identity(), config=IcpConfig())

    latencies_ms: list[float] = []
    accepted = 0
    pelvis_delta_m: list[float] = []
    for _ in range(args.n_frames):
        all_pts = np.concatenate([
            pers.vertices_3d[: 2000] + np.array([0, 0.05, 0], dtype=np.float32) +
            0.02 * rng.randn(2000, 3).astype(np.float32)
            for pers in persons
        ])
        state.lidar_points = all_pts
        before = np.stack([p.vertices_3d[5559].copy() for p in state.persons_smplx])
        t0 = time.perf_counter()
        meta = worker.run_once(state)
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)
        accepted += len(meta.applied)
        after = np.stack([p.vertices_3d[5559] for p in state.persons_smplx])
        pelvis_delta_m.extend(np.linalg.norm(after - before, axis=1).tolist())

    report = {
        "n_frames": args.n_frames,
        "n_people": args.n_people,
        "latency_ms_p50": float(np.percentile(latencies_ms, 50)),
        "latency_ms_p95": float(np.percentile(latencies_ms, 95)),
        "acceptance_rate": accepted / (args.n_frames * args.n_people),
        "pelvis_delta_m_mean": float(np.mean(pelvis_delta_m)),
        "pelvis_delta_m_max": float(np.max(pelvis_delta_m)),
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
