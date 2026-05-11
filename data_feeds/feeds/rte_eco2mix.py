"""RTE éCO2mix — mix électrique France (OAuth2 client_credentials)."""
from __future__ import annotations

import asyncio
import logging
import time

import httpx

LOG = logging.getLogger("feed.rte_eco2mix")

TOKEN_URL = "https://digital.iservices.rte-france.com/token/oauth/"
API_URL   = "https://digital.iservices.rte-france.com/open_api/actual_generation/v1/actual_generations_per_production_type"


async def _get_token(cli: httpx.AsyncClient, cid: str, csec: str) -> tuple[str, float]:
    r = await cli.post(TOKEN_URL, auth=(cid, csec),
                       data={"grant_type": "client_credentials"})
    r.raise_for_status()
    j = r.json()
    return j["access_token"], time.monotonic() + float(j.get("expires_in", 7200)) - 60


async def run(ctx) -> None:
    cfg = ctx.cfg
    cid, csec = cfg.get("client_id"), cfg.get("client_secret")
    period = float(cfg.get("poll_seconds", 900))
    if not (cid and csec):
        LOG.warning("client_id/client_secret manquants — feed inactif")
        await asyncio.Event().wait()
        return
    token, exp = "", 0.0
    async with httpx.AsyncClient(timeout=30.0) as cli:
        while True:
            try:
                if time.monotonic() > exp:
                    token, exp = await _get_token(cli, cid, csec)
                r = await cli.get(API_URL, headers={"Authorization": f"Bearer {token}"})
                r.raise_for_status()
                j = r.json()
                latest = {}
                for series in (j.get("actual_generations_per_production_type") or []):
                    typ = series.get("production_type", "?")
                    vals = series.get("values") or []
                    if vals:
                        latest[typ] = float(vals[-1].get("value", 0.0))
                # mapping standard RTE → ordre des args
                ctx.send(
                    "mix",
                    latest.get("NUCLEAR", 0.0),
                    latest.get("GAS", 0.0),
                    latest.get("COAL", 0.0),
                    latest.get("OIL", 0.0),
                    latest.get("HYDRO", 0.0),
                    latest.get("WIND", 0.0),
                    latest.get("SOLAR", 0.0),
                    latest.get("BIOENERGY", 0.0),
                )
            except Exception as e:  # noqa: BLE001
                LOG.warning("fetch failed: %s", e)
            await asyncio.sleep(period)
