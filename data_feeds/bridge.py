#!/usr/bin/env python3
"""Orchestrateur du pont data_feeds → OSC.

Charge `config.toml`, lance un worker async par flux activé, et diffuse
en broadcast vers tous les `osc.targets`. Chaque worker doit exposer
une coroutine `run(ctx)` qui prend un `Context` et émet via `ctx.send(...)`.
"""

from __future__ import annotations

import argparse
import asyncio
import importlib
import logging
import re
import signal
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Whitelist des noms de feed : empeche l'injection de modules arbitraires
# via un config.toml malveillant (importlib resolve sur du . ou .. ferait
# remonter dans l'arborescence).
_FEED_NAME_RE = re.compile(r"^[a-z][a-z0-9_]{0,30}$")

try:
    import tomllib  # py311+
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

from pythonosc.udp_client import SimpleUDPClient

LOG = logging.getLogger("bridge")


@dataclass
class Context:
    cfg: dict[str, Any]
    prefix: str
    clients: list[SimpleUDPClient]
    feed_name: str

    def send(self, sub: str, *args: Any) -> None:
        path = f"{self.prefix}/{self.feed_name}/{sub}"
        for c in self.clients:
            try:
                c.send_message(path, list(args))
            except OSError as e:
                LOG.warning("OSC send failed %s: %s", path, e)


def load_config(path: Path) -> dict[str, Any]:
    with path.open("rb") as f:
        return tomllib.load(f)


async def run_feed(name: str, cfg: dict[str, Any], ctx: Context) -> None:
    """Charge `data_feeds.feeds.<name>` et appelle `run(ctx)`."""
    if not _FEED_NAME_RE.match(name):
        LOG.error("invalid feed name %r — must match %s",
                  name, _FEED_NAME_RE.pattern)
        return
    try:
        mod = importlib.import_module(f"data_feeds.feeds.{name}")
    except ModuleNotFoundError:
        # Fallback : exécution depuis le dossier data_feeds/
        mod = importlib.import_module(f"feeds.{name}")
    LOG.info("starting feed: %s", name)
    backoff = 1.0
    while True:
        try:
            await mod.run(ctx)
            # Retour propre : on reset le backoff et on rejoue en boucle.
            backoff = 1.0
            await asyncio.sleep(2.0)
        except asyncio.CancelledError:
            raise
        except Exception as e:  # noqa: BLE001
            LOG.error("feed %s crashed: %s — retry in %.1fs", name, e, backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60.0)


async def heartbeat(clients: list[SimpleUDPClient], prefix: str) -> None:
    t0 = time.monotonic()
    while True:
        for c in clients:
            c.send_message(f"{prefix}/heartbeat", [time.monotonic() - t0])
        await asyncio.sleep(5.0)


async def main_async(cfg: dict[str, Any]) -> None:
    osc_cfg = cfg.get("osc", {})
    prefix = osc_cfg.get("prefix", "/data")
    clients = [
        SimpleUDPClient(t["host"], t["port"])
        for t in osc_cfg.get("targets", [{"host": "127.0.0.1", "port": 57121}])
    ]
    LOG.info(
        "OSC targets: %s",
        ", ".join(f"{c._address}:{c._port}" for c in clients),  # noqa: SLF001
    )

    tasks: list[asyncio.Task[None]] = []
    for name, fcfg in cfg.get("feeds", {}).items():
        if not fcfg.get("enabled", False):
            LOG.info("feed disabled: %s", name)
            continue
        ctx = Context(cfg=fcfg, prefix=prefix, clients=clients, feed_name=name)
        tasks.append(asyncio.create_task(run_feed(name, fcfg, ctx), name=name))

    if not tasks:
        LOG.warning("no feed enabled — exiting")
        return

    tasks.append(asyncio.create_task(heartbeat(clients, prefix), name="heartbeat"))

    loop = asyncio.get_running_loop()
    stop = loop.create_future()
    sig_count = 0

    def _on_signal() -> None:
        nonlocal sig_count
        sig_count += 1
        if sig_count > 1:
            LOG.warning("second signal received — forcing exit")
            sys.exit(1)
        if not stop.done():
            stop.cancel()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, _on_signal)
    try:
        await stop
    except asyncio.CancelledError:
        pass
    finally:
        for t in tasks:
            t.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        LOG.info("bridge stopped")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("-c", "--config", type=Path, default=Path(__file__).parent / "config.toml")
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s — %(message)s",
        datefmt="%H:%M:%S",
    )
    cfg = load_config(args.config)
    try:
        asyncio.run(main_async(cfg))
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
