"""IphoneOSCListener writes ARKit joints to state from OSC packets."""
import time

import numpy as np
import pytest
from pythonosc.udp_client import SimpleUDPClient

from data_only_viz.state import State
from data_only_viz.iphone_osc_listener import (
    IphoneOSCListener, IPHONE_OSC_PORT,
)


@pytest.fixture()
def listener():
    state = State()
    listener = IphoneOSCListener(state, port=IPHONE_OSC_PORT + 100)
    listener.start()
    yield state, listener
    listener.stop()


def test_kp_message_updates_state(listener):
    state, lst = listener
    client = SimpleUDPClient("127.0.0.1", lst.port)
    client.send_message("/body3d/kp", [0, 1, 0.1, 0.2, 0.3])
    # Settle
    deadline = time.monotonic() + 1.0
    while time.monotonic() < deadline:
        with state.lock():
            if 0 in state.persons_arkit_joints:
                arr = state.persons_arkit_joints[0]
                if arr[1, 0] != 0.0:
                    break
        time.sleep(0.02)
    with state.lock():
        assert 0 in state.persons_arkit_joints, \
            "OSC /body3d/kp message not received within 1s"
        arr = state.persons_arkit_joints[0]
    assert arr.shape == (91, 3)
    assert np.allclose(arr[1], [0.1, 0.2, 0.3])


def test_gc_drops_stale_pids(listener):
    state, lst = listener
    with state.lock():
        state.persons_arkit_joints[7] = np.zeros((91, 3), dtype=np.float32)
        state.persons_arkit_last_t[7] = time.perf_counter() - 5.0
    lst._gc_stale()
    with state.lock():
        assert 7 not in state.persons_arkit_joints
