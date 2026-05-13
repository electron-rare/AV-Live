"""One Euro filter — lissage adaptatif de keypoints en temps reel.

Reference : Casiez, Roussel, Vogel (CHI 2012) "1€ Filter: A Simple
Speed-based Low-pass Filter for Noisy Input in Interactive Systems".

Compromis cle : faible latence quand le signal est rapide (cut-off
haut), fort lissage quand stable (cut-off bas). Pilote la coupure par
la vitesse instantanee.

Un filtre par scalaire (x, y, z separes). API :
    f = OneEuroFilter(min_cutoff=1.0, beta=0.05)
    smooth = f(value, timestamp)
"""
from __future__ import annotations

import math
import time
from dataclasses import dataclass, field


@dataclass
class OneEuroFilter:
    min_cutoff: float = 1.0    # Hz : coupure quand stable (plus bas = plus lisse)
    beta: float = 0.05         # gain sur vitesse (plus haut = plus reactif)
    d_cutoff: float = 1.0      # coupure du derivee
    _x_prev: float | None = field(default=None, init=False, repr=False)
    _dx_prev: float = field(default=0.0, init=False, repr=False)
    _t_prev: float | None = field(default=None, init=False, repr=False)

    def __call__(self, x: float, t: float | None = None) -> float:
        if t is None:
            t = time.monotonic()
        if self._t_prev is None:
            self._t_prev = t
            self._x_prev = x
            return x
        dt = max(1e-6, t - self._t_prev)
        # Derivee (estimee) -> filtree -> calcul cut-off adaptatif
        dx = (x - self._x_prev) / dt
        a_d = _alpha(self.d_cutoff, dt)
        dx_hat = a_d * dx + (1 - a_d) * self._dx_prev
        cutoff = self.min_cutoff + self.beta * abs(dx_hat)
        a = _alpha(cutoff, dt)
        x_hat = a * x + (1 - a) * self._x_prev
        # State
        self._x_prev = x_hat
        self._dx_prev = dx_hat
        self._t_prev = t
        return x_hat

    def reset(self) -> None:
        self._x_prev = None
        self._t_prev = None
        self._dx_prev = 0.0


def _alpha(cutoff: float, dt: float) -> float:
    tau = 1.0 / (2.0 * math.pi * cutoff)
    return 1.0 / (1.0 + tau / dt)


class KpFilter:
    """Bundle (x, y, z) pour un keypoint."""

    def __init__(self, min_cutoff: float = 1.0, beta: float = 0.05) -> None:
        self.fx = OneEuroFilter(min_cutoff, beta)
        self.fy = OneEuroFilter(min_cutoff, beta)
        self.fz = OneEuroFilter(min_cutoff, beta)

    def __call__(self, x: float, y: float, z: float, t: float) -> tuple[float, float, float]:
        return self.fx(x, t), self.fy(y, t), self.fz(z, t)

    def reset(self) -> None:
        self.fx.reset(); self.fy.reset(); self.fz.reset()


class SkeletonFilter:
    """N keypoints x M personnes. Crée des KpFilter à la demande, indexé
    par (person_id, kp_index)."""

    def __init__(self, min_cutoff: float = 1.2, beta: float = 0.08) -> None:
        self._min_cutoff = min_cutoff
        self._beta = beta
        self._table: dict[tuple[int, int], KpFilter] = {}

    def smooth(self, person_id: int, kp_index: int,
               x: float, y: float, z: float, t: float) -> tuple[float, float, float]:
        key = (person_id, kp_index)
        f = self._table.get(key)
        if f is None:
            f = KpFilter(self._min_cutoff, self._beta)
            self._table[key] = f
        return f(x, y, z, t)

    def forget(self, person_id: int) -> None:
        """Supprime tous les filtres d'une personne (sortie de track)."""
        self._table = {k: v for k, v in self._table.items() if k[0] != person_id}

    def reset_all(self) -> None:
        self._table.clear()
