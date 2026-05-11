// =====================================================================
//  feeds_client.js  --  WebSocket client partage par les 3 modules
//  (WebGL, Audio, Hydra). Expose window.feeds + window.f helpers.
//
//  Reconnexion auto, dedup, snapshot "feeds._lastByAddr".
//  Les modules s'abonnent via window.onFeed("/data/usgs/event", fn).
// =====================================================================
(() => {
    if (window.__feedsClientLoaded) return;
    window.__feedsClientLoaded = true;

    window.feeds = window.feeds ?? {
        netz:  { freq: 50, dev: 0, time_dev: 0 },
        swpc:  { wind_speed: 400, wind_dens: 5, bz: 0, bt: 5, kp: 2, a: 5, flare_norm: 0 },
        usgs:  { last_mag: 0, last_lon: 0, last_lat: 0, last_age: 9999, rate_h: 0 },
        light: { rate_min: 0, last_lat: 0, last_lon: 0, last_age: 9999 },
        sky:   { count: 0, last_lon: 0, last_lat: 0, last_alt: 0, last_vel: 0,
                 last_head: 0, last_pan: 0 },
        bsky:  { rate_s: 0 },
        rte:   { renew_pct: 0.25, total: 50000 },
        pose:  { count: 0, persons: [], skels: [] },
        events: [],   // ring de derniers evenements ponctuels (visualizers)
        tick: 0,
        alive: false,
        _lastHb: 0,
    };

    const listeners = new Map();
    window.onFeed = (addr, fn) => {
        if (!listeners.has(addr)) listeners.set(addr, []);
        listeners.get(addr).push(fn);
    };
    function notify(addr, args) {
        const arr = listeners.get(addr);
        if (arr) for (const fn of arr) try { fn(args); } catch(e) { console.error(e); }
    }

    function pushEvent(kind, data) {
        window.feeds.events.push({ kind, data, t: performance.now() });
        if (window.feeds.events.length > 256) window.feeds.events.splice(0, 64);
    }

    function ingest(addr, args) {
        window.feeds.tick++;
        const a = args || [];
        switch (addr) {
            case "/data/heartbeat":
                window.feeds._lastHb = Date.now();
                window.feeds.alive = true; return;
            case "/data/netzfrequenz/freq": window.feeds.netz.freq = a[0]; break;
            case "/data/netzfrequenz/dev":  window.feeds.netz.dev = a[0]; break;
            case "/data/netzfrequenz/time_dev": window.feeds.netz.time_dev = a[0]; break;
            case "/data/swpc/wind":
                window.feeds.swpc.wind_speed = a[0];
                window.feeds.swpc.wind_dens = a[1]; break;
            case "/data/swpc/bz":
                window.feeds.swpc.bz = a[0]; window.feeds.swpc.bt = a[1]; break;
            case "/data/swpc/kp":
                window.feeds.swpc.kp = a[0]; window.feeds.swpc.a = a[1]; break;
            case "/data/swpc/xray":
                window.feeds.swpc.flare_norm = a[2];
                if (a[2] > 0.5) pushEvent("flare", { norm: a[2] });
                break;
            case "/data/usgs/event":
                window.feeds.usgs.last_mag = a[0];
                window.feeds.usgs.last_lon = a[1];
                window.feeds.usgs.last_lat = a[2];
                window.feeds.usgs.last_age = a[4];
                pushEvent("quake", { mag: a[0], lon: a[1], lat: a[2], depth: a[3] });
                break;
            case "/data/usgs/rate": window.feeds.usgs.rate_h = a[0]; break;
            case "/data/blitzortung/strike":
                window.feeds.light.last_lat = a[0];
                window.feeds.light.last_lon = a[1];
                window.feeds.light.last_age = a[2];
                pushEvent("strike", { lat: a[0], lon: a[1], mult: a[3] });
                break;
            case "/data/blitzortung/rate": window.feeds.light.rate_min = a[0]; break;
            case "/data/opensky/count": window.feeds.sky.count = a[0]; break;
            case "/data/opensky/plane":
                window.feeds.sky.last_lon  = a[1];
                window.feeds.sky.last_lat  = a[2];
                window.feeds.sky.last_alt  = a[3];
                window.feeds.sky.last_vel  = a[4];
                window.feeds.sky.last_head = a[5];
                window.feeds.sky.last_pan  = (a[1] - 4.9) / 0.6;
                pushEvent("plane", { lon: a[1], lat: a[2], alt: a[3], vel: a[4], head: a[5] });
                break;
            case "/data/bluesky/rate": window.feeds.bsky.rate_s = a[0]; break;
            case "/data/pose/count":
                window.feeds.pose.count = a[0];
                if (a[0] === 0) { window.feeds.pose.persons = []; window.feeds.pose.skels = []; }
                break;
            case "/data/pose/person": {
                const idx = a[0]|0;
                window.feeds.pose.persons[idx] = {
                    cx: a[1], cy: a[2], w: a[3], h: a[4], conf: a[5],
                };
                break;
            }
            case "/data/pose/skel": {
                const idx = a[0]|0;
                window.feeds.pose.skels[idx] = { conf: a[1], kp: a.slice(2) };
                break;
            }
            case "/data/rte_eco2mix/mix": {
                const total = a.reduce((s, x) => s + (x||0), 0);
                const renew = (a[4]||0)+(a[5]||0)+(a[6]||0)+(a[7]||0);
                window.feeds.rte.total = total;
                window.feeds.rte.renew_pct = total > 0 ? renew / total : 0.25;
                break;
            }
        }
        notify(addr, a);
    }

    // helpers compactes pour Hydra et shaders
    window.f = {
        quakePulse: () => {
            const ev = [...window.feeds.events].reverse().find(e => e.kind === "quake");
            if (!ev) return 0;
            const age = (performance.now() - ev.t) / 1000;
            return Math.max(0, 1 - age / 2);
        },
        strikePulse: () => {
            const ev = [...window.feeds.events].reverse().find(e => e.kind === "strike");
            if (!ev) return 0;
            const age = (performance.now() - ev.t) / 1000;
            return Math.max(0, 1 - age / 1.2);
        },
        flarePulse: () => Math.min(1, (window.feeds.swpc.flare_norm||0) * 2),
        netzDev: () => window.feeds.netz.dev || 0,
        bz: () => window.feeds.swpc.bz || 0,
        kp01: () => Math.min(1, (window.feeds.swpc.kp||0) / 9),
        wind01: () => Math.min(1, ((window.feeds.swpc.wind_speed||400) - 250) / 650),
        renew: () => window.feeds.rte.renew_pct || 0.25,
        skyCount01: () => Math.min(1, (window.feeds.sky.count||0) / 50),
        bskyDensity: () => Math.min(1, (window.feeds.bsky.rate_s||0) / 30),
        lightRate01: () => Math.min(1, (window.feeds.light.rate_min||0) / 60),
    };

    let ws = null;
    function connect() {
        const proto = location.protocol === "https:" ? "wss:" : "ws:";
        ws = new WebSocket(`${proto}//${location.host}/ws`);
        ws.addEventListener("open", () => {
            window.feeds.alive = true;
            console.log("[feeds] WS open");
        });
        ws.addEventListener("close", () => {
            window.feeds.alive = false;
            setTimeout(connect, 1000);
        });
        ws.addEventListener("message", (ev) => {
            try {
                const m = JSON.parse(ev.data);
                if (typeof m.address === "string") ingest(m.address, m.args);
            } catch {}
        });
    }
    connect();

    setInterval(() => {
        if (window.feeds._lastHb && Date.now() - window.feeds._lastHb > 15000) {
            window.feeds.alive = false;
        }
    }, 5000);
})();
