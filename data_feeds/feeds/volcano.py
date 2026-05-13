"""Volcans actifs — Smithsonian GVP weekly reports + USGS volcano hazards.

Source primaire : USGS volcano feed (RSS / GeoJSON), couvre les volcans
US actifs. Pour les volcans monde, on parse les CSV publics Smithsonian
si configures. Polling 1h.

OSC out :
    /data/volcano/active count
    /data/volcano/eruption lat lon vei region   (nouvelle eruption depuis last poll)
"""
from __future__ import annotations

import asyncio
import collections
import logging

import httpx

LOG = logging.getLogger("feed.volcano")

USGS_URL = ("https://volcanoes.usgs.gov/hans2/api/volcano/getEvents"
            "?starttime={start}&endtime={end}")


async def run(ctx) -> None:
    cfg = ctx.cfg
    period = float(cfg.get("poll_seconds", 3600.0))
    url = cfg.get("url",
                  "https://volcano.si.edu/feeds/eruptions7days.json")
    seen: collections.OrderedDict[str, None] = collections.OrderedDict()
    SEEN_MAX = 512
    async with httpx.AsyncClient(timeout=30.0) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                ct = r.headers.get("content-type", "")
                items = []
                if "json" in ct:
                    data = r.json()
                    items = data.get("features", data.get("items", []))
                count = 0
                for it in items:
                    props = it.get("properties", it)
                    eid = str(props.get("id") or props.get("eventid")
                              or props.get("volcanoNumber") or "")
                    if not eid:
                        continue
                    count += 1
                    if eid in seen:
                        continue
                    seen[eid] = None
                    if len(seen) > SEEN_MAX:
                        seen.popitem(last=False)
                    geom = it.get("geometry") or {}
                    coords = geom.get("coordinates") or [0, 0]
                    lon, lat = float(coords[0]), float(coords[1])
                    vei = float(props.get("vei", 0) or 0)
                    region = str(props.get("country")
                                 or props.get("region", ""))[:32]
                    ctx.send("eruption", lat, lon, vei, region)
                ctx.send("active", float(count))
            except Exception as e:  # noqa: BLE001
                LOG.warning("volcano fetch failed: %s", e)
            await asyncio.sleep(period)
