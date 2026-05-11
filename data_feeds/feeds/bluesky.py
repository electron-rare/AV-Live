"""Bluesky Jetstream — firehose des posts publics (WebSocket JSON)."""
from __future__ import annotations

import asyncio
import json
import logging
import random
import time

import websockets

from ._util import RateMeter, djb2

LOG = logging.getLogger("feed.bluesky")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["ws_url"]
    sample = float(cfg.get("sample_rate", 0.02))
    rate = RateMeter(window=10.0)
    last_rate_emit = 0.0
    while True:
        try:
            async with websockets.connect(url, ping_interval=20, max_size=2**20) as ws:
                LOG.info("connected jetstream (sample %.0f%%)", sample * 100)
                async for raw in ws:
                    rate.tick()
                    now = time.monotonic()
                    if now - last_rate_emit > 1.0:
                        ctx.send("rate", rate.rate)
                        last_rate_emit = now
                    if random.random() > sample:
                        continue
                    try:
                        d = json.loads(raw)
                    except (json.JSONDecodeError, TypeError):
                        continue
                    commit = d.get("commit") or {}
                    rec = commit.get("record") or {}
                    text = rec.get("text") or ""
                    lang = (rec.get("langs") or ["?"])[0]
                    ctx.send("post", float(len(text)), float(djb2(lang)))
        except Exception as e:  # noqa: BLE001
            LOG.warning("ws disconnected: %s — reconnecting", e)
            await asyncio.sleep(3.0)
