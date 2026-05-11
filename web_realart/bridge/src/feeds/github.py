"""GitHub public events — firehose dev mondial (polling REST anonyme)."""
from __future__ import annotations

import asyncio
import logging

import httpx

from ._util import djb2

LOG = logging.getLogger("feed.github")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["url"]
    period = float(cfg.get("poll_seconds", 30))
    last_id = ""
    async with httpx.AsyncClient(timeout=20.0,
                                 headers={"Accept": "application/vnd.github+json"}) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                for ev in reversed(r.json()):
                    eid = ev.get("id", "")
                    if eid <= last_id:
                        continue
                    ctx.send(
                        "event",
                        float(djb2(ev.get("type", "?"))),
                        float(djb2(((ev.get("repo") or {}).get("name") or "?"))),
                    )
                    last_id = eid
            except Exception as e:  # noqa: BLE001
                LOG.warning("fetch failed: %s", e)
            await asyncio.sleep(period)
