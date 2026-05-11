// =====================================================================
//  hydra/app.js -- canvas Hydra synchronise avec sound_algo via WebSocket
//
//  Variables globales injectees par le bridge :
//    window.bpm    : BPM courant (envoye par SC sur /sync/bpm)
//    window.beat   : compteur de beat (incremente sur /sync/beat)
//    window.amp    : { kick, hat, snare, clap, perc, melody, acid, harmony }
//                    parametres de volume du mixer (statiques)
//    window.rms    : { master } -- vrai RMS audio mesure cote SC
//    window.hydraParams : { intensity, hueShift, speed, density, feedback }
//                          sliders globaux pilotables depuis /control/
//
//  Messages WS recus :
//    /sync/bpm <bpm>             -- mise a jour tempo
//    /sync/beat <bpm>            -- tick de beat
//    /sync/amp <voice> <amp>     -- volume mixer par voie
//    /sync/rms <bus> <amp>       -- RMS audio reel (master)
//    /hydra/preset <name>        -- changer de preset
//    /hydra/code <code>          -- evaluer du code Hydra arbitraire
//    /hydra/param <name> <val>   -- mise a jour de window.hydraParams
// =====================================================================

window.bpm  = 128;
window.beat = 0;
window.amp  = { kick: 0, hat: 0, snare: 0, clap: 0, perc: 0,
                melody: 0, acid: 0, harmony: 0 };
window.rms  = { master: 0 };
window.hydraParams = { intensity: 1, hueShift: 0, speed: 1, density: 1, feedback: 0.5 };

// ---------------------------------------------------------------------
//  Flux temps reel externes -- alimente par /data/<source>/<sub> via WS
//  (server.js DATA_PORT_IN <- bridge.py)
//
//  Cles agregees pour faciliter l'usage Hydra :
//    feeds.netz   = { freq, dev, time_dev }
//    feeds.swpc   = { wind_speed, wind_dens, bz, bt, kp, a, flare_norm }
//    feeds.usgs   = { last_mag, last_age, rate_h }
//    feeds.light  = { rate_min, last_lat, last_lon, last_age }
//    feeds.sky    = { count, last_alt, last_vel, last_pan }
//    feeds.bsky   = { rate_s }
//    feeds.rte    = { renew_pct, total }
//    feeds.tick   = compteur incremente a chaque /data/<...>
//    feeds.alive  = bool (heartbeat < 15s)
// ---------------------------------------------------------------------
window.feeds = {
    netz:  { freq: 50, dev: 0, time_dev: 0 },
    swpc:  { wind_speed: 400, wind_dens: 5, bz: 0, bt: 5, kp: 2, a: 5, flare_norm: 0 },
    usgs:  { last_mag: 0, last_age: 9999, rate_h: 0 },
    light: { rate_min: 0, last_lat: 0, last_lon: 0, last_age: 9999 },
    sky:   { count: 0, last_alt: 0, last_vel: 0, last_pan: 0 },
    bsky:  { rate_s: 0 },
    rte:   { renew_pct: 0.25, total: 50000 },
    tick:  0,
    alive: false,
    _lastHb: 0,
};

const wsState    = document.getElementById("ws-state");
const bpmDisplay = document.getElementById("bpm");
const beatDisplay = document.getElementById("beat");

let ws = null;

function connect() {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    ws = new WebSocket(`${proto}//${location.host}/ws`);

    ws.addEventListener("open", () => {
        wsState.textContent = "online";
        wsState.style.color = "#38d977";
    });
    ws.addEventListener("close", () => {
        wsState.textContent = "reconnecting…";
        wsState.style.color = "#ff5151";
        setTimeout(connect, 1000);
    });

    ws.addEventListener("message", (ev) => {
        try {
            const msg = JSON.parse(ev.data);
            const addr = msg.address || "";
            if (addr.startsWith("/sync/")) {
                const type = addr.slice(6);
                switch (type) {
                    case "bpm":
                        window.bpm = msg.args[0];
                        bpmDisplay.textContent = window.bpm;
                        break;
                    case "beat":
                        window.beat++;
                        beatDisplay.textContent = window.beat;
                        break;
                    case "amp": {
                        const [voice, amp] = msg.args;
                        if (voice in window.amp) window.amp[voice] = amp;
                        break;
                    }
                    case "rms": {
                        const [bus, amp] = msg.args;
                        if (bus in window.rms) window.rms[bus] = amp;
                        break;
                    }
                }
            } else if (addr === "/hydra/preset") {
                const name = msg.args[0];
                if (PRESETS[name]) {
                    codeArea.value = PRESETS[name];
                    run();
                }
            } else if (addr === "/hydra/code") {
                const code = msg.args[0];
                if (typeof code === "string" && code.length > 0) {
                    codeArea.value = code;
                    run();
                }
            } else if (addr.startsWith("/data/")) {
                ingestDataFeed(addr, msg.args);
            } else if (addr === "/hydra/param") {
                const [name, val] = msg.args;
                if (name in window.hydraParams) {
                    window.hydraParams[name] = val;
                }
            }
        } catch {}
    });
}

// ---------- ingestion data_feeds -------------------------------------
function ingestDataFeed(addr, args) {
    window.feeds.tick++;
    const a = args || [];
    switch (addr) {
        case "/data/heartbeat":
            window.feeds._lastHb = Date.now();
            window.feeds.alive = true;
            return;
        case "/data/netzfrequenz/freq":   window.feeds.netz.freq = a[0]; break;
        case "/data/netzfrequenz/dev":    window.feeds.netz.dev = a[0]; break;
        case "/data/netzfrequenz/time_dev": window.feeds.netz.time_dev = a[0]; break;
        case "/data/swpc/wind":
            window.feeds.swpc.wind_speed = a[0];
            window.feeds.swpc.wind_dens = a[1];
            break;
        case "/data/swpc/bz":
            window.feeds.swpc.bz = a[0];
            window.feeds.swpc.bt = a[1];
            break;
        case "/data/swpc/kp":
            window.feeds.swpc.kp = a[0];
            window.feeds.swpc.a = a[1];
            break;
        case "/data/swpc/xray":
            window.feeds.swpc.flare_norm = a[2];
            break;
        case "/data/usgs/event":
            window.feeds.usgs.last_mag = a[0];
            window.feeds.usgs.last_age = a[4];
            // marqueur visuel : pulse pendant 2 s via window.feeds._quakeHit
            window.feeds._quakeHit = Date.now();
            break;
        case "/data/usgs/rate":
            window.feeds.usgs.rate_h = a[0];
            break;
        case "/data/blitzortung/strike":
            window.feeds.light.last_lat = a[0];
            window.feeds.light.last_lon = a[1];
            window.feeds.light.last_age = a[2];
            window.feeds._strikeHit = Date.now();
            break;
        case "/data/blitzortung/rate":
            window.feeds.light.rate_min = a[0];
            break;
        case "/data/opensky/count":
            window.feeds.sky.count = a[0];
            break;
        case "/data/opensky/plane":
            window.feeds.sky.last_alt = a[3];
            window.feeds.sky.last_vel = a[4];
            window.feeds.sky.last_pan = (a[1] - 4.9) / 0.6; // bbox-relative
            break;
        case "/data/bluesky/rate":
            window.feeds.bsky.rate_s = a[0];
            break;
        case "/data/rte_eco2mix/mix": {
            const total = (a[0]||0)+(a[1]||0)+(a[2]||0)+(a[3]||0)+
                          (a[4]||0)+(a[5]||0)+(a[6]||0)+(a[7]||0);
            const renew = (a[4]||0)+(a[5]||0)+(a[6]||0)+(a[7]||0);
            window.feeds.rte.total = total;
            window.feeds.rte.renew_pct = total > 0 ? renew / total : 0.25;
            break;
        }
    }
}

// helpers exposes pour les patches Hydra (acces concis)
window.f = {
    quakePulse: () => {
        const t = window.feeds._quakeHit;
        if (!t) return 0;
        const age = (Date.now() - t) / 1000;
        return Math.max(0, 1 - age / 2);
    },
    strikePulse: () => {
        const t = window.feeds._strikeHit;
        if (!t) return 0;
        const age = (Date.now() - t) / 1000;
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

// heartbeat watchdog
setInterval(() => {
    if (window.feeds._lastHb && Date.now() - window.feeds._lastHb > 15000) {
        window.feeds.alive = false;
    }
}, 5000);

// ---------- Hydra setup ----------------------------------------------
const canvas = document.getElementById("hydra-canvas");
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
window.addEventListener("resize", () => {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
});

const hydra = new Hydra({ canvas, detectAudio: false, makeGlobal: true });

// ---------- Patches presets (Hydra DSL) ------------------------------
//   Chaque preset utilise window.bpm/beat/amp.*/rms.master/hydraParams.*
const PRESETS = {
    default: `
// Default : visualisation reactive a kick + melody
osc(20, 0.1, 1.5)
  .modulate(noise(3, 0.1).scrollX(() => window.beat * 0.001))
  .color(() => 0.5 + window.amp.kick * 2,
         0.3 + window.amp.melody * 1.5,
         0.7 + window.amp.acid)
  .scale(() => 1 + window.amp.kick * 0.3)
  .out()
`.trim(),

    osc: `
// Osc wobble synchro BPM
osc(() => 30 + Math.sin(window.beat * 0.1) * 20, 0.1, 2)
  .rotate(() => window.beat * 0.02)
  .kaleid(() => 3 + Math.floor(window.amp.kick * 6))
  .modulateScale(osc(2).scrollX(() => window.beat * 0.005), 0.4)
  .out()
`.trim(),

    kaleido: `
// Kaleidoscope qui s'ouvre sur kick
osc(15, 0.05, 0.8)
  .kaleid(() => 4 + Math.floor(window.amp.kick * 8))
  .scale(() => 0.8 + window.amp.melody * 0.5)
  .colorama(() => 0.5 + window.amp.acid * 0.3)
  .modulate(noise(2, 0.05))
  .out()
`.trim(),

    grid: `
// Grid pulse : grille rythmique synchro hat
shape(4, 0.3, 0.01)
  .repeat(() => 8, () => 8)
  .scrollY(() => window.beat * 0.005)
  .modulateScrollX(osc(1).rotate(() => window.beat * 0.01))
  .color(() => window.amp.hat * 3, 0.5, 1)
  .out()
`.trim(),

    warp: `
// Warp organique
voronoi(8, 0.2, 0.3)
  .modulate(osc(2, 0.1).rotate(() => window.beat * 0.01), 0.3)
  .scale(() => 1.5 + window.amp.kick * 0.8)
  .color(() => 0.4 + window.amp.melody, 0.2, 0.6)
  .out()
`.trim(),

    pixel: `
// Pixel sort glitchy
osc(40, 0.1, 1.5)
  .pixelate(() => 50 + window.amp.kick * 200,
            () => 50 + window.amp.kick * 200)
  .modulate(noise(2, 0.1))
  .color(2, 0.5, () => window.amp.acid * 3)
  .out()
`.trim(),

    feedback: `
// Feedback loop : la sortie module la frame suivante
osc(10, 0.1, 1.2)
  .color(0.8, 0.2, () => window.amp.melody * 2)
  .modulate(src(o0).scale(0.99), () => 0.3 + window.hydraParams.feedback * 0.5)
  .blend(src(o0), () => 0.4 + window.amp.kick * 0.3)
  .out()
`.trim(),

    vortex: `
// Vortex : rotation acceleree par BPM + zoom kick
osc(25, 0.05, 1)
  .rotate(() => window.beat * 0.05 * window.hydraParams.speed)
  .scale(() => 0.5 + window.amp.kick * 1.5)
  .kaleid(6)
  .colorama(() => window.beat * 0.001)
  .out()
`.trim(),

    liquid: `
// Liquid : voronoi modulé acid
voronoi(() => 5 + window.amp.acid * 15, 0.3, 0.1)
  .modulate(osc(2).rotate(() => window.beat * 0.02))
  .color(() => 0.2 + window.amp.harmony, 0.5, () => 0.8 + window.amp.melody)
  .scale(() => 1 + window.rms.master * 0.5)
  .out()
`.trim(),

    tunnel: `
// Tunnel : kaleido + scrollY constant
osc(30, 0.1, 0.8)
  .kaleid(() => 8 + Math.floor(window.amp.snare * 8))
  .scrollY(() => window.beat * 0.01)
  .scale(() => 0.4 + window.amp.kick * 0.6)
  .color(() => window.amp.melody * 2, 0.3, () => window.amp.acid * 2)
  .out()
`.trim(),

    spectrum: `
// Spectrum : barres verticales par voie (kick/hat/snare/melody)
shape(4, 0.05, 0.01)
  .repeat(8, 1)
  .scale(() => 0.5 + window.amp.kick + window.amp.snare,
         () => 0.3 + window.amp.melody + window.amp.acid)
  .color(() => window.amp.kick * 3,
         () => window.amp.snare * 3,
         () => window.amp.melody * 3)
  .out()
`.trim(),

    cellular: `
// Cellular : automaton-like via shape repeat
shape(() => 3 + Math.floor(window.amp.hat * 6), 0.4, 0.02)
  .repeat(() => 12 + Math.floor(window.amp.kick * 8),
          () => 12 + Math.floor(window.amp.kick * 8))
  .modulateScale(osc(1).rotate(() => window.beat * 0.005), 0.1)
  .color(() => 0.5 + window.amp.acid, 0.4, 0.9)
  .out()
`.trim(),

    glitch: `
// Glitch : modulateRotate + pixelate sur kick
osc(60, 0.2, 2)
  .modulateRotate(noise(3, 0.5), () => window.amp.kick * 2)
  .pixelate(() => 20 + window.amp.kick * 300, () => 20 + window.amp.snare * 300)
  .color(() => 1 + window.amp.acid, 0.2, () => 1 + window.amp.melody)
  .out()
`.trim(),

    neon: `
// Neon : couleurs HSV cyclique saturees
osc(8, 0.05, 2)
  .modulate(noise(4, 0.2))
  .colorama(() => 0.1 + window.beat * 0.002 + window.hydraParams.hueShift)
  .saturate(() => 1.5 + window.amp.melody * 2)
  .scale(() => 1 + window.rms.master * 0.4)
  .out()
`.trim(),

    wireframe: `
// Wireframe : threshold sur osc luma
osc(12, 0.05, 1.5)
  .luma(() => 0.4 + window.amp.kick * 0.3, 0.05)
  .diff(osc(13, 0.05, 1.5).rotate(() => window.beat * 0.01))
  .color(() => window.amp.hat * 4, () => window.amp.snare * 2, 1)
  .out()
`.trim(),

    noise_storm: `
// Noise storm : turbulence + colorama
noise(() => 4 + window.amp.kick * 8, () => 0.1 + window.amp.snare * 0.5)
  .modulate(osc(2).rotate(() => window.beat * 0.03))
  .colorama(() => 0.3 + window.amp.acid * 0.5)
  .contrast(() => 1.2 + window.rms.master * 1.5)
  .out()
`.trim(),

    mandala: `
// Mandala : kaleid 12+ + modulateScale acid
osc(20, 0.05, 1)
  .kaleid(() => 12 + Math.floor(window.amp.acid * 12))
  .modulateScale(osc(3).rotate(() => window.beat * 0.02),
                 () => 0.2 + window.amp.melody * 0.5)
  .color(() => 0.6 + window.amp.harmony, 0.4, () => 0.8 + window.amp.kick)
  .out()
`.trim(),

    ripple: `
// Ripple : noise depth controlled by snare
osc(15, 0.1, 1)
  .modulate(noise(() => 2 + window.amp.snare * 10, 0.2),
            () => 0.1 + window.amp.snare * 0.6)
  .scale(() => 1 + window.rms.master * 0.3)
  .color(() => window.amp.melody * 2, 0.5, () => window.amp.acid * 2)
  .out()
`.trim(),

    strobe: `
// Strobe : invert sur kick (ATTENTION epilepsie)
//   threshold haut : ne flash que si amp.kick > 0.7
osc(20, 0.05, 1)
  .invert(() => window.amp.kick > 0.7 ? 1 : 0)
  .color(() => 1 + window.amp.snare, 1, 1)
  .out()
`.trim(),

    mountains: `
// Mountains : voronoi scrolling
voronoi(20, 0.1, 0.5)
  .scrollY(() => window.beat * 0.003)
  .modulate(osc(1, 0.05).rotate(0.1))
  .color(() => 0.3 + window.amp.harmony, () => 0.4 + window.amp.melody, 0.7)
  .contrast(1.4)
  .out()
`.trim(),

    // ============ DATA FEEDS PRESETS ============
    // Tous utilisent window.feeds (alimente par /data/* via WS).
    // Lance d'abord : cd data_feeds && uv run python bridge.py

    feeds_aurora: `
// Aurora : Bz IMF + vent solaire + Kp -> drape de lumiere
osc(() => 6 + window.f.wind01() * 18, 0.05, () => 1 + window.f.kp01())
  .modulate(noise(() => 2 + window.f.kp01() * 6, 0.1).scrollY(() => window.beat * 0.002))
  .rotate(() => window.f.bz() * 0.03)
  .color(() => 0.2 + window.f.kp01() * 0.4,
         () => 0.6 + window.f.wind01() * 0.4,
         () => 0.4 + window.f.flarePulse())
  .scale(() => 1 + window.f.flarePulse() * 0.6)
  .out()
`.trim(),

    feeds_quake: `
// Quake : USGS magnitude -> onde de choc radiale
shape(() => 4 + Math.floor(window.feeds.usgs.last_mag), 0.05, 0.02)
  .repeat(8, 8)
  .scale(() => 0.5 + window.f.quakePulse() * 2.5)
  .modulateRotate(noise(2, 0.2), () => window.f.quakePulse() * 3)
  .color(() => 0.8 + window.f.quakePulse(),
         () => 0.2 - window.f.quakePulse() * 0.2,
         0.1)
  .add(osc(20, 0.05, 1).pixelate(8, 8), () => window.f.quakePulse() * 0.4)
  .out()
`.trim(),

    feeds_lightning: `
// Lightning : foudre Blitzortung -> flash blanc + voronoi rapide
voronoi(() => 8 + window.f.lightRate01() * 30, 0.3, 0.1)
  .modulate(noise(6, 0.3))
  .invert(() => window.f.strikePulse() > 0.6 ? 1 : 0)
  .add(solid(1, 1, 1, () => window.f.strikePulse() * 0.6))
  .color(0.7, 0.7, () => 0.9 + window.f.strikePulse())
  .out()
`.trim(),

    feeds_flightmap: `
// Flightmap : OpenSky count + altitude + cap
osc(() => 10 + window.feeds.sky.count, 0.05, 1)
  .kaleid(() => 4 + Math.floor(window.f.skyCount01() * 8))
  .modulate(osc(2).scrollX(() => window.feeds.sky.last_pan * 0.1)
                   .scrollY(() => window.feeds.sky.last_alt / 50000))
  .rotate(() => window.feeds.sky.last_pan * 0.5)
  .color(() => 0.3 + window.f.skyCount01() * 0.5,
         () => 0.5 + window.feeds.sky.last_vel / 500,
         () => 0.6 + window.feeds.sky.last_alt / 20000)
  .out()
`.trim(),

    feeds_gridpulse: `
// Gridpulse : derivation Netzfrequenz -> tremblement micro
osc(() => 30 + window.feeds.netz.freq * 0.5, 0.05, 1.5)
  .modulateScale(osc(8).rotate(() => window.beat * 0.01),
                 () => 0.05 + Math.abs(window.f.netzDev()) * 4)
  .scale(() => 1 + window.f.netzDev() * 8)
  .color(() => 0.5 - window.f.netzDev() * 5,
         () => 0.5 + window.f.netzDev() * 5,
         () => 0.5 + window.f.renew() * 0.5)
  .contrast(() => 1.2 + Math.abs(window.f.netzDev()) * 8)
  .out()
`.trim(),

    feeds_solarwind: `
// Solar wind : vent + densite + flare X-ray
noise(() => 2 + window.f.wind01() * 8, () => 0.05 + window.f.flarePulse() * 0.3)
  .modulate(osc(() => 5 + window.f.wind01() * 10, 0.05).rotate(() => window.beat * 0.02))
  .colorama(() => 0.05 + window.f.kp01() * 0.4)
  .add(solid(1, 0.6, 0.2, () => window.f.flarePulse() * 0.5))
  .scale(() => 0.8 + window.f.wind01() * 0.5)
  .saturate(() => 1.3 + window.f.flarePulse() * 2)
  .out()
`.trim(),

    feeds_bskyrain: `
// Bskyrain : pluie de pixels proportionnelle au firehose Bluesky
shape(4, 0.005, 0.001)
  .repeat(() => 40 + window.f.bskyDensity() * 80,
          () => 40 + window.f.bskyDensity() * 80)
  .scrollY(() => time * (0.05 + window.f.bskyDensity() * 0.3))
  .scrollX(() => Math.sin(time * 0.3) * 0.02)
  .color(() => 0.4 + window.f.bskyDensity() * 0.4,
         () => 0.7 + window.f.kp01() * 0.3,
         1)
  .modulate(noise(2, 0.2), 0.05)
  .out()
`.trim(),

    cosmos: `
// Cosmos : multi-osc layered + rotate
osc(5, 0.05, 1)
  .rotate(() => window.beat * 0.005)
  .add(osc(15, 0.1, 1).rotate(() => -window.beat * 0.01), 0.5)
  .add(osc(35, 0.2, 1).kaleid(8), () => 0.3 + window.amp.kick * 0.4)
  .color(() => 0.5 + window.amp.melody, 0.3, () => 0.7 + window.amp.acid)
  .out()
`.trim(),
};

// ---------- Editor + run --------------------------------------------
const editor   = document.getElementById("editor");
const codeArea = document.getElementById("code");
const status   = document.getElementById("status");
const toggleBtn = document.getElementById("editor-toggle");

codeArea.value = PRESETS.default;

function run() {
    try {
        eval(codeArea.value);
        status.textContent = "[OK] " + new Date().toLocaleTimeString();
        status.style.color = "#38d977";
    } catch (err) {
        status.textContent = "[ERR] " + err.message;
        status.style.color = "#ff5151";
    }
}

document.getElementById("run").addEventListener("click", run);
codeArea.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        run();
    }
});

document.querySelectorAll('[data-preset]').forEach((btn) => {
    btn.addEventListener("click", () => {
        if (PRESETS[btn.dataset.preset]) {
            codeArea.value = PRESETS[btn.dataset.preset];
            run();
        }
    });
});

toggleBtn.addEventListener("click", () => editor.classList.toggle("open"));
window.addEventListener("keydown", (e) => {
    if (e.key === "e" && !["TEXTAREA", "INPUT"].includes(document.activeElement.tagName)) {
        editor.classList.toggle("open");
    }
});

// Expose la liste des presets pour debug + integration externe
window.HYDRA_PRESETS = Object.keys(PRESETS);

// Lance le preset par defaut au demarrage et ouvre la WS
connect();
run();
