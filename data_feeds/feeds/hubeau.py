"""Hub'Eau hydrometrie feed — water level and flow rate for French rivers.

API: https://hubeau.eaufrance.fr/api/v1/hydrometrie/observations_tr
Open, no API key required.
"""
from __future__ import annotations

import json
import logging
import urllib.parse
import urllib.request
from typing import Any

from .base import Feed

LOG = logging.getLogger("data_feeds.hubeau")

BASE = "https://hubeau.eaufrance.fr/api/v1/hydrometrie/observations_tr"


class HubeauFeed(Feed):
    name = "hubeau"
    interval_sec = 300.0

    def fetch(self) -> Any:
        codes = self.cfg.get("codes") or ["F050001001"]
        out: dict[str, dict[str, float]] = {}
        for code in codes:
            params = {
                "code_entite": code,
                "size": 1,
                "sort": "desc",
                "fields": "code_station,grandeur_hydro,resultat_obs,date_obs",
            }
            url = BASE + "?" + urllib.parse.urlencode(params)
            try:
                req = urllib.request.Request(
                    url, headers={"User-Agent": "av-live/0.1"})
                with urllib.request.urlopen(req, timeout=10) as r:
                    data = json.loads(r.read().decode("utf-8"))
            except Exception as e:  # noqa: BLE001
                LOG.warning("hubeau %s failed: %s", code, e)
                continue
            for obs in data.get("data") or []:
                station = obs.get("code_station") or code
                gr = obs.get("grandeur_hydro") or "X"
                v = obs.get("resultat_obs")
                if v is None:
                    continue
                try:
                    fv = float(v)
                except (TypeError, ValueError):
                    continue
                out.setdefault(station, {})[gr] = fv
        return out

    def publish(self, payload: Any) -> None:
        if not isinstance(payload, dict) or not payload:
            return
        count = 0
        for station, vals in payload.items():
            for gr, v in vals.items():
                key = f"{station}_{gr}"
                self.osc_send(f"/data/{self.name}/sample", [key, float(v)])
                count += 1
        self.osc_send(f"/data/{self.name}/count", [count])
