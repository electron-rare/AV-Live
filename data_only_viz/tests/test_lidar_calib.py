"""Tests for LiDAR <-> webcam extrinsic calibration persistence."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest


def test_extrinsic_default_is_identity() -> None:
    from data_only_viz.lidar_calib import Extrinsic

    e = Extrinsic.identity()
    np.testing.assert_allclose(e.T_arkit_to_cam, np.eye(4))
    assert e.confidence == 0.0
    assert e.captured_at_iso == ""


def test_extrinsic_roundtrip_json(tmp_path: Path) -> None:
    from data_only_viz.lidar_calib import Extrinsic, load_extrinsic, save_extrinsic

    T = np.eye(4)
    T[:3, 3] = [0.1, -0.05, 0.30]
    e = Extrinsic(T_arkit_to_cam=T, confidence=0.95, captured_at_iso="2026-05-14T12:00:00Z")

    path = tmp_path / "extrinsic.json"
    save_extrinsic(e, path)
    loaded = load_extrinsic(path)

    np.testing.assert_allclose(loaded.T_arkit_to_cam, T, atol=1e-10)
    assert loaded.confidence == pytest.approx(0.95)
    assert loaded.captured_at_iso == "2026-05-14T12:00:00Z"


def test_load_extrinsic_missing_path_returns_identity(tmp_path: Path) -> None:
    from data_only_viz.lidar_calib import load_extrinsic

    e = load_extrinsic(tmp_path / "does-not-exist.json")
    np.testing.assert_allclose(e.T_arkit_to_cam, np.eye(4))
    assert e.confidence == 0.0
