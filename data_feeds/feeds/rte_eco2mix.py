"""RTE éCO2mix — mix électrique France (OAuth2 client_credentials)."""
from __future__ import annotations

import asyncio
import logging
import time

import httpx

LOG = logging.getLogger("feed.rte_eco2mix")

TOKEN_URL = "https://digital.iservices.rte-france.com/token/oauth/"
API_URL   = "https://digital.iservices.rte-france.com/open_api/actual_generation/v1/actual_generations_per_production_type"

# Mapping des `production_type` RTE (verbose) vers nos categories courtes.
# L'API agrege HYDRO_* et WIND_* pour le contexte musical : on additionne.
_RTE_MAP = {
    "NUCLEAR":                       "NUCLEAR",
    "FOSSIL_GAS":                    "GAS",
    "FOSSIL_HARD_COAL":              "COAL",
    "FOSSIL_OIL":                    "OIL",
    "HYDRO_WATER_RESERVOIR":         "HYDRO",
    "HYDRO_RUN_OF_RIVER_AND_POUNDAGE":"HYDRO",
    "HYDRO_PUMPED_STORAGE":          "HYDRO",
    "WIND_ONSHORE":                  "WIND",
    "WIND_OFFSHORE":                 "WIND",
    "SOLAR":                         "SOLAR",
    "BIOMASS":                       "BIOENERGY",
    "WASTE":                         "BIOENERGY",
}


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
                latest: dict[str, float] = {}
                for series in (j.get("actual_generations_per_production_type") or []):
                    raw = series.get("production_type", "?")
                    typ = _RTE_MAP.get(raw)
                    if typ is None:
                        continue   # type non-mappe, ignore
                    vals = series.get("values") or []
                    if vals:
                        # Aggregation : on additionne les sous-categories
                        # (ex: WIND_ONSHORE + WIND_OFFSHORE -> WIND).
                        latest[typ] = latest.get(typ, 0.0) \
                            + float(vals[-1].get("value", 0.0))
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
