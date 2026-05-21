"""Sytadin Paris traffic feed — STUB.

TODO: needs sytadin.fr scraping / cumulative km of congestion.
"""
from __future__ import annotations

import logging

from .base import Feed

LOG = logging.getLogger("data_feeds.sytadin")


class SytadinFeed(Feed):
    name = "sytadin"
    interval_sec = 300.0

    def fetch(self):
        return None

    def publish(self, payload) -> None:
        LOG.info("stub")
