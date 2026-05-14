"""arkit_pelvis_z_override : if ARKit pelvis z is fresh, replace
the Multi-HMR pred_cam_t.z so the SMPL-X mesh sits at the actual
distance instead of HaMeR's monocular guess.
"""
import time

import numpy as np

from data_only_viz.state import State
from data_only_viz.multi_hmr_worker import arkit_pelvis_z_override


def test_returns_arkit_z_when_fresh():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[1] = (0.0, 0.0, 2.5)   # ARKIT_PELVIS_IDX=1, z=2.5 m
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter()
    z_pred = 5.0   # Multi-HMR ambiguous guess
    z_out = arkit_pelvis_z_override(state, pid=0, z_pred=z_pred)
    assert z_out == 2.5


def test_keeps_pred_when_stale():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[1] = (0.0, 0.0, 2.5)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter() - 5.0
    z_pred = 5.0
    z_out = arkit_pelvis_z_override(state, pid=0, z_pred=z_pred)
    assert z_out == 5.0


def test_keeps_pred_when_pid_missing():
    state = State()
    z_pred = 4.2
    z_out = arkit_pelvis_z_override(state, pid=99, z_pred=z_pred)
    assert z_out == 4.2
