"""IRSN Teleray radiation feed — STUB.

TODO: needs https://teleray.irsn.fr/data endpoint research.
"""
from __future__ import annotations

import logging

from .base import Feed

LOG = logging.getLogger("data_feeds.teleray")


class TelerayFeed(Feed):
    name = "teleray"
    interval_sec = 600.0

    def fetch(self):
        return None

    def publish(self, payload) -> None:
        LOG.info("stub")
