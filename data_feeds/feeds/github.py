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
    # IDs GitHub sont des strings numeriques croissants : on compare en int
    # (la compare string casse des que le nombre de digits change).
    last_id: int = 0
    async with httpx.AsyncClient(timeout=20.0,
                                 headers={"Accept": "application/vnd.github+json"}) as cli:
        while True:
            try:
                r = await cli.get(url)
                r.raise_for_status()
                for ev in reversed(r.json()):
                    raw = ev.get("id", "")
                    try:
                        eid = int(raw)
                    except (TypeError, ValueError):
                        continue
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
