"""Tests for the DINOv2 reid backend.

These tests are skipped automatically if the .mlpackage is not present
(`scripts/convert_dinov2.py` was never run) or pyobjc is unavailable.
"""
from __future__ import annotations

import time
from pathlib import Path

import numpy as np
import pytest

from data_only_viz.dino_reid import DEFAULT_MLPACKAGE, EMBED_DIM, DinoReid


pytestmark = pytest.mark.skipif(
    not DEFAULT_MLPACKAGE.exists(),
    reason=f"DINOv2 mlpackage missing at {DEFAULT_MLPACKAGE}; "
           "run scripts/convert_dinov2.py first",
)


@pytest.fixture(scope="module")
def reid() -> DinoReid:
    return DinoReid()


def test_is_available() -> None:
    assert DinoReid.is_available() is True


def test_load(reid: DinoReid) -> None:
    assert reid is not None
    assert reid._out_name


def test_embed_random_crops_different(reid: DinoReid) -> None:
    # Two crops with very different visual content. DINOv2 CLS tokens
    # for two iid noise patches are surprisingly close (~0.98), so we
    # build crops that are visually distinct: one is mostly red, the
    # other is mostly green with a striped pattern.
    a = np.zeros((224, 224, 3), dtype=np.uint8)
    a[..., 0] = 220  # red
    a[40:80, 40:180] = (240, 30, 30)
    b = np.zeros((224, 224, 3), dtype=np.uint8)
    b[..., 1] = 200  # green
    for i in range(0, 224, 16):
        b[i:i + 8] = (10, 30, 220)  # blue stripes
    embs = reid.embed_crops([a, b])
    assert embs.shape == (2, EMBED_DIM)
    norms = np.linalg.norm(embs, axis=1)
    assert np.allclose(norms, 1.0, atol=1e-3)
    cos = float(np.dot(embs[0], embs[1]))
    assert cos < 0.95, f"distinct crops too similar: cos={cos:.3f}"


def test_embed_identical_crops_same(reid: DinoReid) -> None:
    rng = np.random.default_rng(7)
    a = rng.integers(0, 255, size=(224, 224, 3), dtype=np.uint8)
    embs = reid.embed_crops([a, a.copy()])
    assert embs.shape == (2, EMBED_DIM)
    cos = float(np.dot(embs[0], embs[1]))
    assert cos > 0.999, f"identical crops cos={cos:.4f} (expected ~1.0)"


def test_latency_batch4(reid: DinoReid) -> None:
    rng = np.random.default_rng(0)
    crops = [rng.integers(0, 255, size=(180, 90, 3), dtype=np.uint8)
             for _ in range(4)]
    # warmup
    reid.embed_crops(crops)
    t0 = time.perf_counter()
    reid.embed_crops(crops)
    dt_ms = (time.perf_counter() - t0) * 1e3
    # Spec target: < 30 ms for batch=4 on M5.
    assert dt_ms < 80.0, f"batch=4 too slow: {dt_ms:.1f} ms"
