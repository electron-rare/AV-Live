"""mempool.space — Bitcoin txs and blocks (WebSocket)."""
from __future__ import annotations

import asyncio
import json
import logging

import websockets

LOG = logging.getLogger("feed.mempool")


async def run(ctx) -> None:
    cfg = ctx.cfg
    url = cfg["ws_url"]
    while True:
        try:
            async with websockets.connect(url, ping_interval=20, max_size=2**21) as ws:
                await ws.send(json.dumps({"action": "want", "data": ["mempool-blocks", "blocks", "live-2h-chart"]}))
                LOG.info("connected mempool.space")
                async for raw in ws:
                    try:
                        d = json.loads(raw)
                    except (json.JSONDecodeError, TypeError):
                        continue
                    if "block" in d:
                        b = d["block"] or {}
                        ctx.send(
                            "block",
                            float(b.get("height", 0)),
                            float(b.get("tx_count", 0)),
                            float(b.get("extras", {}).get("reward", 0) or 0) / 1e8,
                        )
                    if "transactions" in d:
                        for tx in (d["transactions"] or [])[:5]:
                            ctx.send(
                                "tx",
                                float(tx.get("value", 0)) / 1e8,
                                float(tx.get("fee", 0)) / max(1.0, float(tx.get("vsize", 1))),
                            )
        except Exception as e:  # noqa: BLE001
            LOG.warning("ws disconnected: %s — reconnecting", e)
            await asyncio.sleep(5.0)
