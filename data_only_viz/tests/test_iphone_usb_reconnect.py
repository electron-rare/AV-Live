"""The iPhone USB source must keep retrying the initial connect, not give up
when the iPhone app isn't streaming yet. Auto-reconnect must cover a startup
race (app not ready when data_only_viz starts), not only a mid-session drop."""
import time

import data_only_viz.iphone_usb_source as m
from data_only_viz.state import PoseKp, State


def test_start_keeps_retrying_when_no_device(monkeypatch):
    calls = {"n": 0}

    def fake_connect():
        calls["n"] += 1
        return None                      # device never available during the test

    monkeypatch.setattr(m, "connect_device", fake_connect)
    monkeypatch.setattr(m, "iter_frames", lambda s: iter(()))
    src = m.IphoneUSBSource()
    try:
        assert src.start() is True       # does NOT give up on initial connect failure
        time.sleep(0.25)                 # let the read thread attempt a few reconnects
        assert calls["n"] >= 2, (
            "start() should keep retrying; connect_device called %d time(s)" % calls["n"])
    finally:
        src.release()


def test_hands_cleared_on_stream_drop(monkeypatch):
    """After a USB stream drop, persons_hands* lists must be emptied so the
    renderer does not freeze on the last known hand positions."""

    class FakeSock:
        def close(self): pass
        def shutdown(self, *a): pass

    connect_calls = [0]

    def fake_connect():
        connect_calls[0] += 1
        if connect_calls[0] == 1:
            return FakeSock()   # initial connection succeeds
        return None             # reconnect fails; release() will interrupt the wait

    def fake_iter_frames(sock):
        raise OSError("stream dropped")  # simulate immediate disconnect

    state = State()
    dummy_hand = [PoseKp(x=0.5, y=0.5, z=0.0, c=1.0)] * 21
    with state.lock():
        state.persons_hands = [dummy_hand]
        state.persons_hands_iphone = [dummy_hand]
        state.persons_hands_chirality = [1]

    monkeypatch.setattr(m, "connect_device", fake_connect)
    monkeypatch.setattr(m, "iter_frames", fake_iter_frames)

    src = m.IphoneUSBSource(state=state, write_hands=True)
    src.start()
    src.release()   # joins thread; ensures clearing happened before we check

    with state.lock():
        assert state.persons_hands == [], "persons_hands not cleared on drop"
        assert state.persons_hands_iphone == [], "persons_hands_iphone not cleared on drop"
        assert state.persons_hands_chirality == [], "persons_hands_chirality not cleared on drop"
