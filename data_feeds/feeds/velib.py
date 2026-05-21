"""Velib Metropole feed — specialization of GBFS against the Paris URL."""
from __future__ import annotations

import logging

from .gbfs import GBFSFeed

LOG = logging.getLogger("data_feeds.velib")

VELIB_URL = (
    "https://velib-metropole-opendata.smoove.pro/opendata/"
    "Velib_Metropole/station_status.json"
)


class VelibFeed(GBFSFeed):
    name = "velib"
    interval_sec = 120.0

    def configure(self, **kwargs) -> None:
        # Force the URL if caller did not provide one.
        kwargs.setdefault("url", VELIB_URL)
        super().configure(**kwargs)
        if not self.cfg.get("url"):
            self.cfg["url"] = VELIB_URL
