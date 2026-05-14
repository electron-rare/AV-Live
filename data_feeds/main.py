"""Run all enabled feeds, publish OSC to AVLiveBody."""
from __future__ import annotations

import argparse
import logging
import sys
import time
import tomllib
from pathlib import Path

from .feeds import REGISTRY
from .osc_sender import OscSender


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="data_feeds/config.avlivedata.toml")
    p.add_argument("--osc-host")
    p.add_argument("--osc-port", type=int)
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s %(message)s")
    cfg = tomllib.loads(Path(args.config).read_text())
    osc_cfg = cfg.get("osc", {})
    host = args.osc_host or osc_cfg.get("host", "127.0.0.1")
    port = args.osc_port or osc_cfg.get("port", 57127)
    sender = OscSender(host, port)
    feeds = []
    for name, kwargs in (cfg.get("feeds") or {}).items():
        if not kwargs.get("enabled", False):
            continue
        cls = REGISTRY.get(name)
        if cls is None:
            logging.warning("Unknown feed: %s", name)
            continue
        f = cls(sender.send)
        f.configure(**kwargs)
        f.start()
        feeds.append(f)
        logging.info("started feed %s (interval %.0fs)", name, f.interval_sec)
    if not feeds:
        logging.warning("No feeds enabled. Exiting.")
        return 1
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        return 0
    finally:
        for f in feeds:
            f.stop()


if __name__ == "__main__":
    sys.exit(main())
