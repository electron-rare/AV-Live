"""Fréquence du réseau électrique européen — WebSocket Mainsfrequenz.de.

Format payload (texte) : "f=49.987 t=2026-05-11T06:42:00Z" environ.
Le serveur peut changer ; on parse defensively et on extrait `f`.
"""
from __future__ import annotations

import asyncio
import logging
import re
import time

import websockets

LOG = logging.getLogger("feed.netzfrequenz")

_RE_F = re.compile(r"f\s*=\s*([0-9]+\.[0-9]+)")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["ws_url"]
    time_dev = 0.0   # dérive intégrée (secondes)
    last_t = time.monotonic()
    while True:
        try:
            async with websockets.connect(url, ping_interval=20) as ws:
                LOG.info("connected %s", url)
                async for msg in ws:
                    text = msg if isinstance(msg, str) else msg.decode("utf-8", "ignore")
                    m = _RE_F.search(text)
                    if not m:
                        continue
                    try:
                        f = float(m.group(1))
                    except ValueError:
                        continue
                    now = time.monotonic()
                    dt = now - last_t
                    last_t = now
                    delta = f - 50.0
                    # Intégration : 1 s réelle à 49.5 Hz → -0.01 s d'horloge
                    time_dev += (delta / 50.0) * dt
                    ctx.send("freq", f)
                    ctx.send("dev", delta)
                    ctx.send("time_dev", time_dev)
        except Exception as e:  # noqa: BLE001
            LOG.warning("ws disconnected: %s — reconnecting", e)
            await asyncio.sleep(3.0)
