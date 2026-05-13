"""USGS earthquakes — GeoJSON polling (1 min)."""
from __future__ import annotations

import asyncio
import collections
import logging
import time

import httpx

from ._util import RateMeter

LOG = logging.getLogger("feed.usgs")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["url"]
    period = float(cfg.get("poll_seconds", 60))
    # OrderedDict avec eviction LRU : conserve les 4096 derniers IDs vus
    # dans l'ORDRE d'arrivee. set() perdait l'ordre au pruning, ce qui
    # pouvait re-emettre un evenement deja vu.
    seen: "collections.OrderedDict[str, None]" = collections.OrderedDict()
    SEEN_MAX = 4096
    rate = RateMeter(window=3600.0)
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                data = r.json()
            except Exception as e:  # noqa: BLE001
                LOG.warning("fetch failed: %s", e)
                await asyncio.sleep(period)
                continue

            now_ms = time.time() * 1000.0
            for feat in data.get("features", []):
                fid = feat.get("id")
                if not fid or fid in seen:
                    continue
                seen[fid] = None
                props = feat.get("properties") or {}
                coords = (feat.get("geometry") or {}).get("coordinates") or [0, 0, 0]
                mag = float(props.get("mag") or 0.0)
                t_ms = float(props.get("time") or now_ms)
                age = max(0.0, (now_ms - t_ms) / 1000.0)
                ctx.send("event", mag, float(coords[0]), float(coords[1]),
                         float(coords[2]), age)
                rate.tick()
            ctx.send("rate", rate.rate * 3600.0)

            # garde la mémoire bornée — evict les plus anciens en preservant
            # l'ordre d'insertion (LRU front, head most-recent).
            while len(seen) > SEEN_MAX:
                seen.popitem(last=False)
            await asyncio.sleep(period)
