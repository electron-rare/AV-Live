"""GCN Classic over Kafka — alertes astrophysiques (GRB, GW, neutrinos).

Nécessite des credentials Kafka. Voir https://gcn.nasa.gov/quickstart.
Cette implémentation est volontairement minimale : on extrait ra/dec/error.
"""
from __future__ import annotations

import asyncio
import logging

LOG = logging.getLogger("feed.gcn")


async def run(ctx) -> None:
    cfg = ctx.cfg
    cid, csec = cfg.get("client_id"), cfg.get("client_secret")
    if not (cid and csec):
        LOG.warning("GCN credentials manquants — feed inactif (voir gcn.nasa.gov/quickstart)")
        await asyncio.Event().wait()
        return
    try:
        from gcn_kafka import Consumer  # type: ignore
    except ModuleNotFoundError:
        LOG.error("`gcn-kafka` non installé. uv add gcn-kafka")
        await asyncio.Event().wait()
        return

    from ._util import djb2

    cons = Consumer(client_id=cid, client_secret=csec)
    cons.subscribe([
        "gcn.classic.text.SWIFT_BAT_GRB_POS_ACK",
        "gcn.classic.text.FERMI_GBM_FLT_POS",
        "gcn.classic.text.LVC_INITIAL",
        "gcn.classic.text.ICECUBE_ASTROTRACK_GOLD",
    ])
    LOG.info("subscribed GCN classic streams")
    loop = asyncio.get_running_loop()

    def _poll():
        return cons.consume(num_messages=10, timeout=1.0)

    while True:
        msgs = await loop.run_in_executor(None, _poll)
        for m in msgs or []:
            if m.error():
                continue
            txt = m.value().decode("utf-8", "ignore")
            ra, dec, err = _parse(txt)
            ctx.send("alert", float(djb2(m.topic())), ra, dec, err)


def _parse(txt: str) -> tuple[float, float, float]:
    ra = dec = err = 0.0
    for line in txt.splitlines():
        l = line.lower()
        try:
            if "ra:" in l and ra == 0.0:
                ra = float(line.split(":", 1)[1].split()[0])
            elif "dec:" in l and dec == 0.0:
                dec = float(line.split(":", 1)[1].split()[0])
            elif "error" in l and "arcmin" in l and err == 0.0:
                err = float(line.split(":", 1)[1].split()[0])
        except (ValueError, IndexError):
            continue
    return ra, dec, err
