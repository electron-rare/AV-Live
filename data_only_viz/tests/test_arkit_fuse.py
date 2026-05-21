"""ArkitFuse stage overrides 14 body slots with ARKit data when fresh."""
import time

import numpy as np

from data_only_viz.state import Kp3D, State
from data_only_viz.pose_filter import PoseFilterChain


def _mp33_zero_body():
    return [Kp3D(x=0.0, y=0.0, z=0.0, c=1.0) for _ in range(33)]


def test_arkit_fuse_overrides_shoulder():
    state = State()
    # ARKit publishes joint 50 (left shoulder) with (1.0, 2.0, 3.0)
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[50] = (1.0, 2.0, 3.0)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter()
    chain = PoseFilterChain(state=state, enabled_stages=("arkit_fuse",))
    bodies = [_mp33_zero_body()]
    out = chain.apply(bodies, ids=[0], t_now=time.perf_counter())
    # Slot 11 = L_SHOULDER (from ARKIT91_TO_MP33).
    assert out[0][11].x == 1.0
    assert out[0][11].y == 2.0
    assert out[0][11].z == 3.0


def test_arkit_fuse_skips_stale():
    state = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    arr[50] = (9.0, 9.0, 9.0)
    with state.lock():
        state.persons_arkit_joints[0] = arr
        state.persons_arkit_last_t[0] = time.perf_counter() - 5.0
    chain = PoseFilterChain(state=state, enabled_stages=("arkit_fuse",))
    bodies = [_mp33_zero_body()]
    out = chain.apply(bodies, ids=[0], t_now=time.perf_counter())
    # Stale -> not applied, MediaPipe zero left intact.
    assert out[0][11].x == 0.0
