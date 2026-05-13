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
    # Backoff exponentiel cap a 5 minutes pour ne pas spammer un host
    # mort (mainsfrequenz.de NXDOMAIN depuis 2026-05). On log la
    # premiere et chaque dixieme reconnect uniquement.
    backoff = 3.0
    attempt = 0
    while True:
        try:
            async with websockets.connect(url, ping_interval=20) as ws:
                LOG.info("connected %s", url)
                backoff = 3.0   # reset on success
                attempt = 0
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
            attempt += 1
            if attempt == 1 or attempt % 10 == 0:
                LOG.warning("ws disconnected (attempt %d, backoff %ds): %s",
                            attempt, int(backoff), e)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 1.6, 300.0)
