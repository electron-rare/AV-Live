"""The iPhone USB source must keep retrying the initial connect, not give up
when the iPhone app isn't streaming yet. Auto-reconnect must cover a startup
race (app not ready when data_only_viz starts), not only a mid-session drop."""
import time

import data_only_viz.iphone_usb_source as m


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
