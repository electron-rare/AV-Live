"""Blitzortung / LightningMaps — impacts de foudre temps réel.

Protocole : à la connexion, envoyer `{"a":111}` (handshake LightningMaps).
Chaque message JSON contient { time, lat, lon, mds (multiplicity)... }.
"""
from __future__ import annotations

import asyncio
import json
import logging
import time

import websockets

from ._util import RateMeter

LOG = logging.getLogger("feed.blitzortung")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["ws_url"]
    rate = RateMeter(window=60.0)
    while True:
        try:
            async with websockets.connect(url, ping_interval=20, max_size=2**20) as ws:
                await ws.send(json.dumps({"a": 111}))
                LOG.info("connected %s", url)
                async for raw in ws:
                    try:
                        d = json.loads(raw)
                    except (json.JSONDecodeError, TypeError):
                        continue
                    lat = float(d.get("lat", 0.0))
                    lon = float(d.get("lon", 0.0))
                    # time est en ns Unix ; on calcule un age en secondes
                    t_ns = d.get("time", 0)
                    age = 0.0
                    if isinstance(t_ns, (int, float)) and t_ns > 0:
                        age = max(0.0, time.time() - t_ns / 1e9)
                    mult = int(d.get("mds") or 1)
                    ctx.send("strike", lat, lon, age, mult)
                    rate.tick()
                    if rate._events:  # noqa: SLF001
                        ctx.send("rate", rate.rate * 60.0)
        except Exception as e:  # noqa: BLE001
            LOG.warning("ws disconnected: %s — reconnecting", e)
            await asyncio.sleep(5.0)
