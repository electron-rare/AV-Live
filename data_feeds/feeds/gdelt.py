"""GDELT Project — feed des evenements 'world' 15-min.

Source : GDELT 2.0 Events CSV ; updates toutes les 15 min.
On compte les evenements + extrait les top countries / themes du
dernier batch.

OSC out :
    /data/gdelt/batch n_events n_countries avg_tone
    /data/gdelt/event lat lon tone country_code root_event_id
"""
from __future__ import annotations

import asyncio
import collections
import logging
import time
import zipfile
from io import BytesIO

import httpx

LOG = logging.getLogger("feed.gdelt")

# GDELT v2 master file list ; on prend juste le dernier .export.CSV.zip
MASTER = "http://data.gdeltproject.org/gdeltv2/lastupdate.txt"


async def _fetch_latest_csv(cli: httpx.AsyncClient) -> list[list[str]]:
    r = await cli.get(MASTER)
    r.raise_for_status()
    # 3 lignes : events, mentions, gkg ; on prend events (premiere ligne)
    first = (r.text.strip().splitlines() or [""])[0].split(" ")
    if len(first) < 3:
        return []
    url = first[2]
    rz = await cli.get(url, follow_redirects=True)
    rz.raise_for_status()
    with zipfile.ZipFile(BytesIO(rz.content)) as zf:
        name = zf.namelist()[0]
        text = zf.read(name).decode("utf-8", errors="ignore")
    return [line.split("\t") for line in text.splitlines() if line]


async def run(ctx) -> None:
    cfg = ctx.cfg
    period = float(cfg.get("poll_seconds", 900.0))   # 15 min
    seen: collections.OrderedDict[str, None] = collections.OrderedDict()
    SEEN_MAX = 8192
    async with httpx.AsyncClient(timeout=60.0) as cli:
        while True:
            try:
                rows = await _fetch_latest_csv(cli)
                if not rows:
                    LOG.warning("gdelt: empty batch")
                    await asyncio.sleep(period)
                    continue
                count = 0
                tones = []
                countries: collections.Counter[str] = collections.Counter()
                # GDELT 2.0 events CSV : 61 colonnes.
                # idx 0 = GLOBALEVENTID, 7 = Actor1CountryCode,
                # 34 = AvgTone, 39 = ActionGeo_Lat, 40 = ActionGeo_Long
                for row in rows:
                    if len(row) < 41:
                        continue
                    eid = row[0]
                    if not eid or eid in seen:
                        continue
                    seen[eid] = None
                    if len(seen) > SEEN_MAX:
                        seen.popitem(last=False)
                    count += 1
                    try:
                        tone = float(row[34] or "0")
                    except ValueError:
                        tone = 0.0
                    tones.append(tone)
                    cc = row[7].strip()[:3]
                    if cc:
                        countries[cc] += 1
                    try:
                        lat = float(row[39] or "0")
                        lon = float(row[40] or "0")
                    except ValueError:
                        lat = lon = 0.0
                    if lat or lon:
                        ctx.send("event", lat, lon, tone, cc, eid)
                avg_tone = (sum(tones) / len(tones)) if tones else 0.0
                ctx.send("batch", float(count),
                         float(len(countries)), float(avg_tone))
            except Exception as e:  # noqa: BLE001
                LOG.warning("gdelt fetch failed: %s", e)
            await asyncio.sleep(period)
