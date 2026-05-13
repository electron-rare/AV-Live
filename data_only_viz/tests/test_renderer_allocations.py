# data_only_viz/tests/test_renderer_allocations.py
"""Renderer must reuse a preallocated CPU staging buffer for the skeleton."""

import numpy as np

from data_only_viz.renderer import MetalRenderer, SKEL_MAX_SEGS, MESH_MAX_VERTS
from data_only_viz.state import State


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
