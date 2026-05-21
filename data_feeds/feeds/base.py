"""Abstract base class for data feeds."""
from __future__ import annotations

import abc
import logging
import time
import threading
from typing import Any

LOG = logging.getLogger("data_feeds.base")


class Feed(abc.ABC):
    name: str = "feed"
    interval_sec: float = 60.0

    def __init__(self, osc_send, **cfg) -> None:
        self.osc_send = osc_send
        self.cfg = cfg
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.last_t: float = 0.0

    def configure(self, **kwargs) -> None:
        self.cfg.update(kwargs)
        if "interval_sec" in kwargs:
            self.interval_sec = float(kwargs["interval_sec"])

    @abc.abstractmethod
    def fetch(self) -> Any: ...

    @abc.abstractmethod
    def publish(self, payload: Any) -> None: ...

    def tick(self) -> None:
        try:
            payload = self.fetch()
            self.publish(payload)
            self.last_t = time.time()
            self.osc_send(f"/data/{self.name}/heartbeat", [self.last_t])
        except Exception as e:  # noqa: BLE001
            LOG.warning("%s fetch failed: %s", self.name, e)

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run, name=f"feed-{self.name}", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _run(self) -> None:
        while not self._stop.is_set():
            self.tick()
            self._stop.wait(self.interval_sec)
