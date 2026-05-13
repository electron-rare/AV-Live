# data_only_viz/tests/test_renderer_allocations.py
"""Renderer must reuse a preallocated CPU staging buffer for the skeleton."""

import time
import types
import unittest.mock as mock

import numpy as np
import pytest

from data_only_viz.renderer import MetalRenderer, SKEL_MAX_SEGS, MESH_MAX_VERTS
from data_only_viz.state import PoseKp, State


def test_skeleton_cpu_buffer_is_preallocated_and_reused():
    r = MetalRenderer.__new__(MetalRenderer)  # bypass __init__ side effects (Metal)
    r._init_skel_cpu_buffer()
    buf = r._skel_cpu_buf
    assert isinstance(buf, np.ndarray)
    assert buf.dtype == np.float32
    assert buf.size == SKEL_MAX_SEGS * 10
    # A second call must return the same object (no realloc):
    r._init_skel_cpu_buffer()
    assert r._skel_cpu_buf is buf


def test_update_skeleton_fills_existing_buffer():
    r = MetalRenderer.__new__(MetalRenderer)
    r._init_skel_cpu_buffer()
    r._mp_bones = None  # force COCO fallback path
    s = State()
    # No persons → returns 0
    n = r._update_skeleton(s)
    assert n == 0


def test_mesh_cpu_buffer_is_preallocated_and_reused():
    r = MetalRenderer.__new__(MetalRenderer)
    r._init_mesh_cpu_buffer()
    buf = r._mesh_cpu_buf
    assert isinstance(buf, np.ndarray)
    assert buf.dtype == np.float32
    assert buf.size == MESH_MAX_VERTS * 5
    r._init_mesh_cpu_buffer()
    assert r._mesh_cpu_buf is buf


def test_mesh_buffer_overflow_guard():
    """push_tri must stop writing before exceeding MESH_MAX_VERTS.

    Strategy: build a State with enough face-person entries that the old
    MESH_MAX_TRIS-only guard would allow n_verts > MESH_MAX_VERTS (old cap
    was MESH_MAX_TRIS*3 = 24576), whereas the new guard caps at MESH_MAX_VERTS
    (10475).  FACE_TRIANGLES has 36 tris → 108 verts per person.
    200 persons × 108 = 21600 verts > 10475, so the vertex guard fires first.

    _update_mesh calls self._mesh_buf.contents().as_buffer() — we stub that
    out since no GPU is available in unit tests.
    """
    from data_only_viz.renderer import MESH_MAX_VERTS

    r = MetalRenderer.__new__(MetalRenderer)
    r._init_mesh_cpu_buffer()

    # Stub _mesh_buf so the GPU upload path does not crash.
    fake_mv = bytearray(MESH_MAX_VERTS * 5 * 4)  # max possible bytes

    class FakeBuf:
        def contents(self):
            return self

        def as_buffer(self, n):
            return memoryview(fake_mv)[:n]

    r._mesh_buf = FakeBuf()

    # Build a State with 200 face persons, each with 478 keypoints at conf=1.0.
    # With FACE_TRIANGLES (36 tris = 108 verts/person), 200 persons would write
    # 21600 verts — well past MESH_MAX_VERTS — if the guard were absent.
    s = State()
    s.pose_last_t = time.monotonic()  # make pose_alive() return True
    visible_kp = [PoseKp(x=0.5, y=0.5, z=0.0, c=1.0) for _ in range(478)]
    s.persons_face = [list(visible_kp) for _ in range(200)]

    n_tris = r._update_mesh(s)
    n_verts = n_tris * 3

    assert n_verts <= MESH_MAX_VERTS, (
        f"Buffer overflow: _update_mesh wrote {n_verts} verts, "
        f"but MESH_MAX_VERTS={MESH_MAX_VERTS}"
    )
