"""PRIM Ile-de-France Mobilites feed — STUB.

TODO: needs API key (https://prim.iledefrance-mobilites.fr/).
"""
from __future__ import annotations

import logging

from .base import Feed

LOG = logging.getLogger("data_feeds.prim")


class PRIMFeed(Feed):
    name = "prim"
    interval_sec = 60.0

    def fetch(self):
        return None

    def publish(self, payload) -> None:
        LOG.info("stub")
