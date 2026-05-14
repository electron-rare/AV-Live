"""Prix carburants feed — STUB.

TODO: needs prix-carburants.gouv.fr GeoJSON cache + station selection.
"""
from __future__ import annotations

import logging

from .base import Feed

LOG = logging.getLogger("data_feeds.carburants")


class CarburantsFeed(Feed):
    name = "carburants"
    interval_sec = 3600.0

    def fetch(self):
        return None

    def publish(self, payload) -> None:
        LOG.info("stub")
