"""Helpers communs aux feeds."""
from __future__ import annotations

import collections
import time
from typing import Iterable


class RateMeter:
    """Compte les événements sur une fenêtre glissante (en secondes)."""

    def __init__(self, window: float = 60.0) -> None:
        self.window = window
        self._events: collections.deque[float] = collections.deque()

    def tick(self) -> int:
        now = time.monotonic()
        self._events.append(now)
        while self._events and now - self._events[0] > self.window:
            self._events.popleft()
        return len(self._events)

    @property
    def rate(self) -> float:
        return len(self._events) / max(self.window, 1e-6)


def djb2(s: str) -> int:
    """Hash stable 0..65535 pour transformer une string en float OSC."""
    h = 5381
    for c in s.encode("utf-8", errors="ignore"):
        h = ((h << 5) + h + c) & 0xFFFF
    return h


def fnorm(x: float, lo: float, hi: float) -> float:
    if hi <= lo:
        return 0.0
    return max(0.0, min(1.0, (x - lo) / (hi - lo)))


def safe_get(d: dict, path: Iterable[str], default=None):
    cur = d
    for k in path:
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return default
    return cur
