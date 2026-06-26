from data_only_viz.pose_bridge import PoseSoundBridge


class FakeClient:
    def __init__(self):
        self.sent = []

    def send_message(self, addr, args):
        self.sent.append((addr, args))


def _bridge():
    b = PoseSoundBridge.__new__(PoseSoundBridge)   # bypass __init__/sockets
    b._client = FakeClient()
    return b


def test_send_hands_both_present():
    b = _bridge()
    feats = {
        "L": {"cx": 0.2, "cy": 0.4, "openness": 0.9, "speed": 0.1},
        "R": {"cx": 0.8, "cy": 0.3, "openness": 0.5, "speed": 0.0},
        "dist": 0.6,
    }
    b.send_hands(feats, t=1.0)
    addr, args = b._client.sent[-1]
    assert addr == "/pose/hands"
    assert args[0] == 0
    assert args[1:5] == [0.2, 0.4, 0.9, 0.1]
    assert args[5:9] == [0.8, 0.3, 0.5, 0.0]
    assert args[9] == 0.6
    assert len(args) == 10


def test_send_hands_left_only_zero_pads_right():
    b = _bridge()
    feats = {"L": {"cx": 0.5, "cy": 0.5, "openness": 0.7, "speed": 0.2},
             "R": None, "dist": 0.0}
    b.send_hands(feats, t=1.0)
    _, args = b._client.sent[-1]
    assert args[5:9] == [0.0, 0.0, 0.0, 0.0]


def test_send_hands_none_emits_all_zero():
    b = _bridge()
    b.send_hands({"L": None, "R": None, "dist": 0.0}, t=1.0)
    _, args = b._client.sent[-1]
    assert args == [0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
