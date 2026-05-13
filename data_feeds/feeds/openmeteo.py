"""Open-Meteo — meteo locale (temp / vent / humidite / pression / pluie).

Pas de cle API. Geolocalisation via lat/lon en config.toml.
Update toutes les `poll_seconds` (defaut 600s = 10 min).

OSC out :
    /data/openmeteo/now temp_c humidity wind_mps wind_deg pressure_hpa rain_mmh
"""
from __future__ import annotations

import asyncio
import logging

import httpx

LOG = logging.getLogger("feed.openmeteo")

URL = ("https://api.open-meteo.com/v1/forecast"
       "?latitude={lat}&longitude={lon}"
       "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,"
       "wind_direction_10m,pressure_msl,rain"
       "&wind_speed_unit=ms&timezone=UTC")


async def run(ctx) -> None:
    cfg = ctx.cfg
    lat = float(cfg.get("lat", 48.8566))      # Paris by default
    lon = float(cfg.get("lon", 2.3522))
    period = float(cfg.get("poll_seconds", 600.0))
    url = URL.format(lat=lat, lon=lon)
    async with httpx.AsyncClient(timeout=15.0) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                cur = r.json().get("current", {})
                ctx.send("now",
                         float(cur.get("temperature_2m", 0.0)),
                         float(cur.get("relative_humidity_2m", 0.0)),
                         float(cur.get("wind_speed_10m", 0.0)),
                         float(cur.get("wind_direction_10m", 0.0)),
                         float(cur.get("pressure_msl", 1013.0)),
                         float(cur.get("rain", 0.0)))
            except Exception as e:  # noqa: BLE001
                LOG.warning("openmeteo fetch failed: %s", e)
            await asyncio.sleep(period)
