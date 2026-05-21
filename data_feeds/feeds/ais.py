"""AIS vessel positions feed — STUB.

TODO: needs aisstream.io API key + websocket subscription.
"""
from __future__ import annotations

import logging

from .base import Feed

LOG = logging.getLogger("data_feeds.ais")


class AISFeed(Feed):
    name = "ais"
    interval_sec = 60.0

    def fetch(self):
        return None

    def publish(self, payload) -> None:
        LOG.info("stub")
