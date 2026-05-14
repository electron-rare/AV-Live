"""Registry of available feed classes (auto-discovery on import)."""
from __future__ import annotations

from .base import Feed
from .eco2mix import Eco2MixFeed
from .gbfs import GBFSFeed
from .hubeau import HubeauFeed
from .velib import VelibFeed
from .ais import AISFeed
from .carburants import CarburantsFeed
from .prim import PRIMFeed
from .sytadin import SytadinFeed
from .teleray import TelerayFeed

REGISTRY: dict[str, type[Feed]] = {
    "eco2mix": Eco2MixFeed,
    "gbfs": GBFSFeed,
    "hubeau": HubeauFeed,
    "velib": VelibFeed,
    "ais": AISFeed,
    "carburants": CarburantsFeed,
    "prim": PRIMFeed,
    "sytadin": SytadinFeed,
    "teleray": TelerayFeed,
}

__all__ = ["Feed", "REGISTRY"]
