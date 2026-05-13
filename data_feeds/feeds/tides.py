"""NOAA tides (station configurable) + phase lunaire calculee.

NOAA CO-OPS API : observed water level + predicted, station codee
(defaut Boston). Phase lunaire algorithme Conway approx (sans dep).

OSC out :
    /data/tides/level water_level_m predicted_m residual_m
    /data/tides/moon phase_0_1 illum_0_1
"""
from __future__ import annotations

import asyncio
import logging
import math
import time

import httpx

LOG = logging.getLogger("feed.tides")

NOAA_URL = ("https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
            "?product={product}&application=AV-Live&format=json"
            "&time_zone=gmt&datum=MLLW&units=metric"
            "&date=latest&station={station}")


def _moon_phase(t: float) -> tuple[float, float]:
    """t epoch -> (phase 0..1 ou 0 = new, 0.5 = full ; illum 0..1).
    Approx Conway, +-1 jour de precision suffisant."""
    # Reference : 2000-01-06 18:14 UTC ~ new moon
    new = 946755300.0
    cycle = 29.530588853 * 86400.0
    phase = ((t - new) % cycle) / cycle
    illum = (1.0 - math.cos(2 * math.pi * phase)) / 2.0
    return phase, illum


async def _fetch_level(cli: httpx.AsyncClient, station: str
                       ) -> tuple[float, float]:
    obs_url = NOAA_URL.format(product="water_level", station=station)
    pred_url = NOAA_URL.format(product="predictions", station=station)
    obs = await cli.get(obs_url)
    pred = await cli.get(pred_url)
    obs.raise_for_status()
    pred.raise_for_status()
    o = obs.json().get("data", [{}])[0]
    p = pred.json().get("predictions", [{}])[0]
    return float(o.get("v") or 0.0), float(p.get("v") or 0.0)


async def run(ctx) -> None:
    cfg = ctx.cfg
    station = str(cfg.get("station", "8443970"))   # Boston by default
    period = float(cfg.get("poll_seconds", 360.0))   # 6 min
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                obs, pred = await _fetch_level(cli, station)
                ctx.send("level", obs, pred, obs - pred)
            except Exception as e:  # noqa: BLE001
                LOG.warning("tides fetch failed: %s", e)
            phase, illum = _moon_phase(time.time())
            ctx.send("moon", float(phase), float(illum))
            await asyncio.sleep(period)
