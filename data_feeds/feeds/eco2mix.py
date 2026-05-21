"""RTE eco2mix feed — France electricity production mix in MW.

Uses the public OpenDataSoft mirror of RTE eco2mix-national-tr (temps reel,
15-min resolution). Stdlib HTTP only.
"""
from __future__ import annotations

import json
import logging
import urllib.parse
import urllib.request
from typing import Any

from .base import Feed

LOG = logging.getLogger("data_feeds.eco2mix")

# OpenDataSoft public mirror — no key required.
URL = (
    "https://odre.opendatasoft.com/api/records/1.0/search/"
    "?dataset=eco2mix-national-tr&rows=1&sort=-date_heure"
)


class Eco2MixFeed(Feed):
    name = "eco2mix"
    interval_sec = 60.0

    def fetch(self) -> Any:
        req = urllib.request.Request(URL, headers={"User-Agent": "av-live/0.1"})
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
        records = data.get("records") or []
        if not records:
            return None
        return records[0].get("fields") or {}

    def publish(self, payload: Any) -> None:
        if not isinstance(payload, dict):
            return
        # Pick a representative subset (MW). Keys per eco2mix-national-tr.
        keys = [
            "consommation", "nucleaire", "gaz", "charbon", "fioul",
            "eolien", "solaire", "hydraulique", "bioenergies",
            "ech_physiques",
        ]
        count = 0
        for k in keys:
            v = payload.get(k)
            if v is None:
                continue
            try:
                fv = float(v)
            except (TypeError, ValueError):
                continue
            self.osc_send(f"/data/{self.name}/sample", [k, fv])
            count += 1
        self.osc_send(f"/data/{self.name}/count", [count])
