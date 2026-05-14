"""State must expose persons_arkit_joints + persons_arkit_last_t."""
import numpy as np

from data_only_viz.state import State


def test_state_has_arkit_joint_fields():
    s = State()
    assert hasattr(s, "persons_arkit_joints")
    assert hasattr(s, "persons_arkit_last_t")
    assert isinstance(s.persons_arkit_joints, dict)
    assert isinstance(s.persons_arkit_last_t, dict)


def test_state_arkit_joints_writable_under_lock():
    s = State()
    arr = np.zeros((91, 3), dtype=np.float32)
    with s.lock():
        s.persons_arkit_joints[0] = arr
        s.persons_arkit_last_t[0] = 1.5
    assert 0 in s.persons_arkit_joints
    assert s.persons_arkit_last_t[0] == 1.5
