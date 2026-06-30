"""State carries ARKit topology + 2D validity for the renderer."""
from data_only_viz.state import State


def test_state_has_topology_fields():
    s = State()
    assert s.arkit_joint_names == []
    assert s.arkit_parents == []
    assert s.persons_arkit_2d_valid == {}


def test_topology_tag_constant():
    from data_only_viz.iphone_usb_source import TAG_TOPOLOGY
    assert TAG_TOPOLOGY == 7
