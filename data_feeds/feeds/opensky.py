"""OpenSky Network — ADS-B aircraft states (REST polling, anon ≤ 15 s)."""
from __future__ import annotations

import asyncio
import logging

import httpx

LOG = logging.getLogger("feed.opensky")


async def run(ctx) -> None:
    cfg = ctx.cfg
    base = cfg["url"]
    period = float(cfg.get("poll_seconds", 15))
    bbox = cfg.get("bbox")  # [lamin, lomin, lamax, lomax]
    params = None
    if bbox and len(bbox) == 4:
        params = {
            "lamin": bbox[0], "lomin": bbox[1],
            "lamax": bbox[2], "lomax": bbox[3],
        }

    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                r = await cli.get(base, params=params)
                r.raise_for_status()
                data = r.json()
            except Exception as e:  # noqa: BLE001
                LOG.warning("fetch failed: %s", e)
                await asyncio.sleep(period)
                continue
            states = data.get("states") or []
            ctx.send("count", float(len(states)))
            for s in states:
                # index: 0=icao24, 5=lon, 6=lat, 7=baro_alt, 9=velocity, 10=heading
                try:
                    icao  = (s[0] or "?")[:8]
                    lon   = float(s[5]) if s[5] is not None else 0.0
                    lat   = float(s[6]) if s[6] is not None else 0.0
                    alt   = float(s[7]) if s[7] is not None else 0.0
                    vel   = float(s[9]) if s[9] is not None else 0.0
                    head  = float(s[10]) if s[10] is not None else 0.0
                except (IndexError, TypeError, ValueError):
                    continue
                ctx.send("plane", icao, lon, lat, alt, vel, head)
            await asyncio.sleep(period)
