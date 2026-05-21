"""Wrapper around python-osc SimpleUDPClient with per-route helpers."""
from __future__ import annotations

import logging
from typing import Any

from pythonosc.udp_client import SimpleUDPClient

LOG = logging.getLogger("data_feeds.osc")


class OscSender:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self._client = SimpleUDPClient(host, port)

    def send(self, addr: str, args: list[Any]) -> None:
        try:
            self._client.send_message(addr, args)
        except OSError as e:
            LOG.warning("send %s failed: %s", addr, e)
