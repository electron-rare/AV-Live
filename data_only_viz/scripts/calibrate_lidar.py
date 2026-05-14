"""Interactive one-shot extrinsic calibration between iPhone LiDAR and webcam.

Usage:

    cd data_only_viz
    uv run --extra lidar python -m data_only_viz.scripts.calibrate_lidar \
        --lidar-host 192.168.0.42 --lidar-port 5500 --webcam-index 0

The script prompts the user to assume 4 stances (front, left, right, back),
captures paired pelvis points (webcam: Multi-HMR vertex 5559; LiDAR: centroid
of the largest mesh anchor), solves Kabsch, and writes the result to
ICP_LIDAR_EXTRINSIC or the default path.

Multi-HMR worker is launched in-process for this script (single-shot mode).
"""
from __future__ import annotations

import argparse
import datetime as dt
import logging
import sys
import time

import numpy as np

from data_only_viz.lidar_calib import Extrinsic, kabsch_rigid, save_extrinsic
from data_only_viz.lidar_receiver import LidarTCPReader

_LOG = logging.getLogger("calibrate_lidar")
_PELVIS_VERT_INDEX = 5559  # SMPL-X canonical pelvis vertex


def _wait_for_lidar(reader: LidarTCPReader, timeout_s: float = 5.0):
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        latest = reader.latest()
        if latest is not None and latest.points.shape[0] > 50:
            return latest
        time.sleep(0.05)
    raise RuntimeError("LiDAR frame never arrived")


def _capture_one_pair(reader: LidarTCPReader, get_smplx_pelvis_cam) -> tuple[np.ndarray, np.ndarray]:
    input("Hold still, then press ENTER to capture...")
    lidar = _wait_for_lidar(reader)
    pelvis_cam = get_smplx_pelvis_cam()
    pelvis_arkit = lidar.points.mean(axis=0)
    _LOG.info("captured: cam=%s  arkit=%s", pelvis_cam, pelvis_arkit)
    return pelvis_cam, pelvis_arkit


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--lidar-host", required=True)
    p.add_argument("--lidar-port", type=int, default=5500)
    p.add_argument("--webcam-index", type=int, default=0)
    p.add_argument("--stances", type=int, default=4)
    args = p.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")

    reader = LidarTCPReader(host=args.lidar_host, port=args.lidar_port)
    reader.start()

    # NB: the actual Multi-HMR getter is wired in Task 9 when the main pipeline
    # exposes a single-shot predictor. For now this script is the *scaffolding*
    # — Task 9 plugs in `multi_hmr_worker.predict_once()`.
    def _placeholder_pelvis_cam() -> np.ndarray:
        raise SystemExit("calibrate_lidar requires Task 9 to be complete (predict_once API)")

    pairs_cam, pairs_arkit = [], []
    try:
        for i in range(args.stances):
            _LOG.info("stance %d/%d", i + 1, args.stances)
            cam, arkit = _capture_one_pair(reader, _placeholder_pelvis_cam)
            pairs_cam.append(cam)
            pairs_arkit.append(arkit)
    finally:
        reader.stop()

    T = kabsch_rigid(np.asarray(pairs_arkit), np.asarray(pairs_cam))
    path = save_extrinsic(Extrinsic(
        T_arkit_to_cam=T,
        confidence=1.0,
        captured_at_iso=dt.datetime.now(dt.timezone.utc).isoformat(),
    ))
    _LOG.info("extrinsic saved to %s", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
