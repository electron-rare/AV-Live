"""ISS position via wheretheiss.at (json).

Renvoie position lat/lon + altitude + velocity. Polling 5s par defaut.
Egalement emet l'event 'pass' (1.0) lorsque la station franchit une
zone d'observation autour de l'observateur (configurable lat/lon/radius).

OSC out :
    /data/iss/pos lat lon alt_km vel_kmh
    /data/iss/pass 1     (transient, quand iss enter dans le radius)
"""
from __future__ import annotations

import asyncio
import logging
import math

import httpx

LOG = logging.getLogger("feed.iss")

URL = "https://api.wheretheiss.at/v1/satellites/25544"


def _great_circle_km(lat1: float, lon1: float,
                     lat2: float, lon2: float) -> float:
    r = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = (math.sin(dp / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2)
    return 2 * r * math.asin(math.sqrt(a))


async def run(ctx) -> None:
    cfg = ctx.cfg
    period = float(cfg.get("poll_seconds", 5.0))
    obs_lat = float(cfg.get("lat", 48.8566))
    obs_lon = float(cfg.get("lon", 2.3522))
    pass_radius = float(cfg.get("pass_radius_km", 1500.0))
    inside_prev = False
    async with httpx.AsyncClient(timeout=10.0) as cli:
        while True:
            try:
                r = await cli.get(URL)
                r.raise_for_status()
                j = r.json()
                lat = float(j.get("latitude", 0.0))
                lon = float(j.get("longitude", 0.0))
                alt = float(j.get("altitude", 0.0))
                vel = float(j.get("velocity", 0.0))
                ctx.send("pos", lat, lon, alt, vel)
                dist = _great_circle_km(obs_lat, obs_lon, lat, lon)
                inside_now = dist < pass_radius
                if inside_now and not inside_prev:
                    ctx.send("pass", 1.0, dist)
                inside_prev = inside_now
            except Exception as e:  # noqa: BLE001
                LOG.warning("iss fetch failed: %s", e)
            await asyncio.sleep(period)
