"""Wikipedia recent changes — Wikimedia EventStreams SSE.

Firehose des modifications Wikipedia toutes langues confondues.
Tres bavard (~10-30 events/s) — on echantillonne et on emet une
fraction + des compteurs.

OSC out :
    /data/wikimedia/edit lang title bot   (sample)
    /data/wikimedia/rate per_second
"""
from __future__ import annotations

import asyncio
import json
import logging
import random
import time

import httpx

LOG = logging.getLogger("feed.wikimedia")

URL = "https://stream.wikimedia.org/v2/stream/recentchange"


async def run(ctx) -> None:
    cfg = ctx.cfg
    sample = float(cfg.get("sample_rate", 0.05))   # emit 5% des edits
    window = float(cfg.get("rate_window_s", 5.0))
    while True:
        try:
            async with httpx.AsyncClient(timeout=None) as cli:
                async with cli.stream("GET", URL,
                                       headers={"Accept": "text/event-stream"}
                                       ) as r:
                    r.raise_for_status()
                    bucket = 0
                    bucket_start = time.monotonic()
                    async for line in r.aiter_lines():
                        if not line.startswith("data:"):
                            continue
                        try:
                            ev = json.loads(line[5:].strip())
                        except json.JSONDecodeError:
                            continue
                        bucket += 1
                        # Sample emit
                        if random.random() < sample:
                            lang = (ev.get("wiki") or "").replace("wiki", "")
                            title = str(ev.get("title", ""))[:64]
                            bot = 1.0 if ev.get("bot") else 0.0
                            ctx.send("edit", lang, title, bot)
                        # Periodic rate
                        now = time.monotonic()
                        if now - bucket_start >= window:
                            per_s = bucket / (now - bucket_start)
                            ctx.send("rate", float(per_s))
                            bucket = 0
                            bucket_start = now
        except Exception as e:  # noqa: BLE001
            LOG.warning("wikimedia stream error: %s — reconnect 5s", e)
            await asyncio.sleep(5.0)
