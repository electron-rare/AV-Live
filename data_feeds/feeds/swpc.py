"""NOAA SWPC — vent solaire, IMF Bz, indice Kp, X-ray flux GOES."""
from __future__ import annotations

import asyncio
import logging
import math

import httpx

LOG = logging.getLogger("feed.swpc")


def _last_row(data) -> list | None:
    if not data or len(data) < 2:
        return None
    return data[-1]


def _flare_class_norm(long_wm2: float) -> float:
    """Mappe le X-ray long band en classe normalisée 0..1.
    A=1e-8, B=1e-7, C=1e-6, M=1e-5, X=1e-4. log10 → [0..1] sur A→X.
    """
    if long_wm2 <= 0:
        return 0.0
    return max(0.0, min(1.0, (math.log10(long_wm2) + 8.0) / 4.0))


async def _fetch_json(cli: httpx.AsyncClient, url: str):
    r = await cli.get(url)
    r.raise_for_status()
    return r.json()


async def run(ctx) -> None:
    cfg = ctx.cfg
    period = float(cfg.get("poll_seconds", 60))
    urls = {
        "plasma": cfg.get("url_plasma"),
        "mag":    cfg.get("url_mag"),
        "kp":     cfg.get("url_kp"),
        "xray":   cfg.get("url_xray"),
    }
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                if urls["plasma"]:
                    j = await _fetch_json(cli, urls["plasma"])
                    row = _last_row(j)
                    if row:
                        # ["time_tag","density","speed","temperature"]
                        try:
                            density = float(row[1])
                            speed   = float(row[2])
                            temp    = float(row[3])
                            ctx.send("wind", speed, density, temp)
                        except (TypeError, ValueError):
                            pass
                if urls["mag"]:
                    j = await _fetch_json(cli, urls["mag"])
                    row = _last_row(j)
                    if row:
                        # ["time_tag","bx_gsm","by_gsm","bz_gsm","lon_gsm","lat_gsm","bt"]
                        try:
                            bz = float(row[3])
                            bt = float(row[6])
                            ctx.send("bz", bz, bt)
                        except (TypeError, ValueError):
                            pass
                if urls["kp"]:
                    j = await _fetch_json(cli, urls["kp"])
                    # NOAA renvoie maintenant une liste de dicts pour Kp
                    # ({"time_tag":..., "Kp":..., "a_running":...}) au lieu
                    # de la liste-de-listes historique. On supporte les deux.
                    if j:
                        last = j[-1]
                        try:
                            if isinstance(last, dict):
                                kp = float(last.get("Kp", 0.0))
                                a  = float(last.get("a_running", 0.0))
                            else:
                                kp = float(last[1])
                                a  = float(last[2])
                            ctx.send("kp", kp, a)
                        except (TypeError, ValueError, KeyError, IndexError):
                            pass
                if urls["xray"]:
                    j = await _fetch_json(cli, urls["xray"])
                    # split short/long bands
                    short = next((d for d in reversed(j) if d.get("energy") == "0.05-0.4nm"), None)
                    long_ = next((d for d in reversed(j) if d.get("energy") == "0.1-0.8nm"), None)
                    s = float(short.get("flux", 0.0)) if short else 0.0
                    l = float(long_.get("flux", 0.0)) if long_ else 0.0
                    ctx.send("xray", s, l, _flare_class_norm(l))
            except Exception as e:  # noqa: BLE001
                LOG.warning("fetch failed: %s: %s", type(e).__name__, e)
            await asyncio.sleep(period)
