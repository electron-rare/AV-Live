"""LiveATC feeds metadata — pas de pull audio, juste compteur de
streams actifs et indicateur d'activite par hub aeroport.

LiveATC.net expose un endpoint stats JSON simplifie pour quelques
aeroports majeurs (KJFK, KLAX, KSFO, EGLL, LFPG). On polle pour
chacun le nombre d'auditeurs courant (proxy pour 'activite ATC').

OSC out :
    /data/atc/hub icao listeners
    /data/atc/total total_listeners n_hubs
"""
from __future__ import annotations

import asyncio
import logging
import re

import httpx

LOG = logging.getLogger("feed.atc")

# LiveATC publie un page HTML par feed avec "Listeners: N" — on parse
# ca via regex au lieu d'un API officielle (pas disponible).
HUB_URL = "https://www.liveatc.net/search/?icao={icao}"
LISTENERS_RE = re.compile(r"Listeners:\s*<b>(\d+)</b>", re.I)


async def _fetch_hub(cli: httpx.AsyncClient, icao: str
                     ) -> int:
    r = await cli.get(HUB_URL.format(icao=icao),
                      headers={"User-Agent": "av-live-data-feeds/1.0"})
    r.raise_for_status()
    matches = LISTENERS_RE.findall(r.text)
    if not matches:
        return 0
    return sum(int(m) for m in matches)


async def run(ctx) -> None:
    cfg = ctx.cfg
    hubs = cfg.get("hubs",
                   ["KJFK", "KLAX", "KSFO", "KORD", "EGLL", "LFPG"])
    period = float(cfg.get("poll_seconds", 300.0))   # 5 min
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            total = 0
            active = 0
            for icao in hubs:
                try:
                    listeners = await _fetch_hub(cli, icao)
                except Exception as e:  # noqa: BLE001
                    LOG.warning("atc %s failed: %s", icao, e)
                    continue
                ctx.send("hub", icao, float(listeners))
                total += listeners
                if listeners > 0:
                    active += 1
                await asyncio.sleep(0.5)   # polite scrape
            ctx.send("total", float(total), float(active))
            await asyncio.sleep(period)
