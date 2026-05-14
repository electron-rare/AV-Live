"""Generic GBFS (General Bikeshare Feed Specification) reader.

Reads a `station_status.json` URL and publishes aggregate counters.
"""
from __future__ import annotations

import json
import logging
import urllib.request
from typing import Any

from .base import Feed

LOG = logging.getLogger("data_feeds.gbfs")


class GBFSFeed(Feed):
    name = "gbfs"
    interval_sec = 120.0

    def fetch(self) -> Any:
        url = self.cfg.get("url")
        if not url:
            LOG.info("gbfs disabled: no url configured")
            return None
        req = urllib.request.Request(url, headers={"User-Agent": "av-live/0.1"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode("utf-8"))

    def publish(self, payload: Any) -> None:
        if not isinstance(payload, dict):
            return
        stations = (payload.get("data") or {}).get("stations") or []
        if not stations:
            return
        codes = set(self.cfg.get("station_codes") or [])
        bikes = 0
        docks = 0
        operative = 0
        sampled = 0
        for s in stations:
            sid = str(s.get("station_id", ""))
            if codes and sid not in codes:
                continue
            bikes += int(s.get("num_bikes_available") or 0)
            docks += int(s.get("num_docks_available") or 0)
            if s.get("is_renting") or s.get("is_installed"):
                operative += 1
            sampled += 1
        self.osc_send(f"/data/{self.name}/sample", ["bikes_available", float(bikes)])
        self.osc_send(f"/data/{self.name}/sample", ["docks_available", float(docks)])
        self.osc_send(f"/data/{self.name}/sample", ["stations_active", float(operative)])
        self.osc_send(f"/data/{self.name}/count", [sampled])
