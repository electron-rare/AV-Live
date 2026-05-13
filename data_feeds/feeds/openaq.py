"""OpenAQ — qualite de l'air locale.

Mesures temps reel PM2.5 / PM10 / NO2 / O3 autour d'un point geo.
API v3 publique sans cle (rate-limited mais souple).

OSC out :
    /data/openaq/now pm25 pm10 no2 o3
"""
from __future__ import annotations

import asyncio
import logging

import httpx

LOG = logging.getLogger("feed.openaq")

URL = ("https://api.openaq.org/v3/locations"
       "?coordinates={lat},{lon}&radius={radius}&limit=20")


def _latest(values: list, param: str) -> float:
    """Cherche la mesure la plus recente pour `param` dans la liste
    de locations OpenAQ v3."""
    best = 0.0
    for loc in values:
        for sensor in loc.get("sensors", []):
            p = sensor.get("parameter", {})
            if p.get("name") == param:
                last = sensor.get("latest", {})
                v = last.get("value")
                if v is not None and v > best:
                    best = float(v)
    return best


async def run(ctx) -> None:
    cfg = ctx.cfg
    lat = float(cfg.get("lat", 48.8566))
    lon = float(cfg.get("lon", 2.3522))
    radius = int(cfg.get("radius_m", 25000))     # 25 km autour
    period = float(cfg.get("poll_seconds", 900.0))   # 15 min
    url = URL.format(lat=lat, lon=lon, radius=radius)
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                locs = r.json().get("results", [])
                pm25 = _latest(locs, "pm25")
                pm10 = _latest(locs, "pm10")
                no2 = _latest(locs, "no2")
                o3 = _latest(locs, "o3")
                ctx.send("now", pm25, pm10, no2, o3)
            except Exception as e:  # noqa: BLE001
                LOG.warning("openaq fetch failed: %s", e)
            await asyncio.sleep(period)
