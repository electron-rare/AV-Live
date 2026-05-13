"""Thread OSC : ecoute UDP :57123 et alimente l'objet State.

Le pont data_feeds (Python) et SC poussent les messages /data/* /sync/*
en parallele. On les agrege dans le State partage avec le renderer
Metal.
"""
from __future__ import annotations

import logging
import threading
import time

from pythonosc import dispatcher, osc_server

from .state import State

LOG = logging.getLogger("osc")


def _build(state: State) -> dispatcher.Dispatcher:
    d = dispatcher.Dispatcher()

    # ---- /sync/* (SC -> visualizer) -----------------------------------
    def _bpm(addr, *args):
        with state.lock(): state.bpm = float(args[0]) if args else state.bpm
    def _beat(addr, *args):
        with state.lock(): state.beat = int(args[0]) if args else state.beat
    def _rms(addr, *args):
        with state.lock(): state.rms = float(args[0]) if args else state.rms
    def _amp(addr, *args):
        if len(args) >= 2:
            with state.lock(): state.amps[str(args[0])] = float(args[1])
    def _album(addr, *args):
        with state.lock(): state.album = str(args[0]) if args else state.album

    d.map("/sync/bpm",   _bpm)
    d.map("/sync/beat",  _beat)
    d.map("/sync/rms",   _rms)
    d.map("/sync/amp",   _amp)
    d.map("/sync/album", _album)

    # ---- /data/* (data_feeds bridge) ----------------------------------
    def _hb(addr, *_):
        with state.lock():
            state.bridge_alive = True
            state.last_heartbeat = time.monotonic()
    d.map("/data/heartbeat", _hb)

    def _kp(addr, *args):
        if args:
            with state.lock(): state.swpc_kp = float(args[0])
    d.map("/data/swpc/kp", _kp)

    def _flare(addr, *args):
        if len(args) >= 3:
            with state.lock(): state.swpc_flare_norm = float(args[2])
    d.map("/data/swpc/xray", _flare)

    def _wind(addr, *args):
        if args:
            with state.lock(): state.swpc_wind_speed = float(args[0])
    d.map("/data/swpc/wind", _wind)

    def _bz(addr, *args):
        if args:
            with state.lock(): state.swpc_bz = float(args[0])
    d.map("/data/swpc/bz", _bz)

    def _netz(addr, *args):
        if args:
            with state.lock(): state.netz_dev = float(args[0])
    d.map("/data/netzfrequenz/dev", _netz)

    def _strike(addr, *args):
        if len(args) >= 3:
            with state.lock():
                state.last_lightning = (float(args[0]), float(args[1]), float(args[2]))
                state.last_lightning_t = time.monotonic()
    d.map("/data/blitzortung/strike", _strike)

    def _lrate(addr, *args):
        if args:
            with state.lock(): state.lightning_rate_min = float(args[0])
    d.map("/data/blitzortung/rate", _lrate)

    def _quake(addr, *args):
        if args:
            with state.lock():
                state.usgs_last_mag = float(args[0])
                state.usgs_last_mag_t = time.monotonic()
    d.map("/data/usgs/event", _quake)

    def _av_count(addr, *args):
        if args:
            with state.lock(): state.aviation_count = int(args[0])
    d.map("/data/opensky/count", _av_count)

    def _social(addr, *args):
        if args:
            with state.lock(): state.social_rate = float(args[0])
    d.map("/data/bluesky/rate", _social)

    def _pose_count(addr, *args):
        if args:
            with state.lock():
                state.pose_count = int(args[0])
                state.pose_last_t = time.monotonic()
    d.map("/data/pose/count", _pose_count)

    # ---- Preset open-data (envoyé par launcher) -----------------
    def _preset(addr, *args):
        if args:
            with state.lock(): state.active_preset = str(args[0])
            LOG.info("preset -> %s", state.active_preset)
    d.map("/control/preset", _preset)

    # ---- Mode visuel (changement live) ---------------------------
    def _viz_mode(addr, *args):
        if not args:
            return
        a = args[0]
        if isinstance(a, str):
            try:
                idx = state.viz_mode_names.index(a)
            except ValueError:
                LOG.warning("viz mode inconnu : %r", a)
                return
        else:
            idx = int(a)
        idx = max(0, min(7, idx))
        with state.lock(): state.viz_mode = idx
        LOG.info("viz mode -> %d (%s)", idx, state.viz_mode_names[idx])
    d.map("/control/vizMode", _viz_mode)

    def _pose_skel(addr, *args):
        # idx, conf_avg, x0 y0 c0 ... x16 y16 c16
        if len(args) < 2 + 17 * 3:
            return
        idx = int(args[0])
        if idx != 0:
            return  # on ne suit que le sujet 0 pour le rendu
        with state.lock():
            for k in range(17):
                off = 2 + k * 3
                kp = state.pose_kp[k]
                kp.x = float(args[off])
                kp.y = float(args[off + 1])
                kp.c = float(args[off + 2])
            state.pose_last_t = time.monotonic()
    d.map("/data/pose/skel", _pose_skel)

    return d


class OscListener:
    def __init__(self, state: State, host: str = "127.0.0.1", port: int = 57123):
        self.state = state
        self.host = host
        self.port = port
        self._server: osc_server.BlockingOSCUDPServer | None = None
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        d = _build(self.state)
        self._server = osc_server.ThreadingOSCUDPServer((self.host, self.port), d)
        self._thread = threading.Thread(
            target=self._server.serve_forever, name="osc", daemon=True)
        self._thread.start()
        LOG.info("listening on %s:%d", self.host, self.port)

    def stop(self) -> None:
        if self._server:
            self._server.shutdown()
            self._server = None
