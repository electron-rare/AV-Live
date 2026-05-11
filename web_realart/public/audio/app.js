// =====================================================================
//  audio/app.js  --  Portage Web Audio des SynthDef SC.
//
//  Reproduit, dans la mesure du raisonnable cote Web Audio API, les
//  presets cles de sound_algo/examples/16_data_feeds.scd et 17_data_feeds_more.scd :
//
//    cavity (16-A)  : Schumann drone harmonique + grain percussif sur foudre
//    mix    (16-B)  : pad sawtooth + cutoff RLPF pilote par RTE renew_pct
//    geo    (16-C)  : BPF saw + sub-bass declenche par USGS magnitudes
//    aurora (17-D)  : pad additif harmonique pilote par Bz/wind/Kp
//    pulse  (17-E)  : kick au tempo Netzfrequenz + clicks Bluesky + sub USGS
//
//  Architecture commune :
//    - 1 master GainNode + AnalyserNode (oscilloscope)
//    - chaque preset alloue ses noeuds dans une fonction startXxx()
//      et les referme via stopAll() avant de switcher
// =====================================================================

let ctx = null;
let master = null;
let analyser = null;
let active = null;
let activeName = null;

const startBtn = document.getElementById("start");
const presetBtns = [...document.querySelectorAll("[data-preset]")];
const nowEl = document.getElementById("now");
const volSlider = document.getElementById("vol");
const volV = document.getElementById("vol-v");

startBtn.addEventListener("click", () => {
    if (ctx) return;
    ctx = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: "interactive" });
    master = ctx.createGain();
    master.gain.value = parseFloat(volSlider.value);
    analyser = ctx.createAnalyser();
    analyser.fftSize = 1024;
    master.connect(analyser); analyser.connect(ctx.destination);
    presetBtns.forEach(b => b.disabled = false);
    startBtn.disabled = true;
    startBtn.textContent = "running @ " + ctx.sampleRate + " Hz";
    drawScope();
});

volSlider.addEventListener("input", () => {
    const v = parseFloat(volSlider.value);
    if (master) master.gain.linearRampToValueAtTime(v, ctx.currentTime + 0.05);
    volV.textContent = v.toFixed(2);
});

presetBtns.forEach(b => b.addEventListener("click", () => {
    const p = b.dataset.preset;
    stopAll();
    presetBtns.forEach(x => x.classList.remove("active"));
    if (p === "stop") {
        nowEl.innerHTML = "stopped.";
        activeName = null;
        return;
    }
    b.classList.add("active");
    activeName = p;
    nowEl.innerHTML = `<span class="name">${p}</span> running. CC0 source flux : data_feeds (USGS, SWPC, Netzfrequenz, Blitzortung, OpenSky, Bluesky, RTE).`;
    switch (p) {
        case "cavity": active = startCavity(); break;
        case "mix":    active = startMix();    break;
        case "geo":    active = startGeo();    break;
        case "aurora": active = startAurora(); break;
        case "pulse":  active = startPulse();  break;
    }
}));

function stopAll() {
    if (active && typeof active.stop === "function") active.stop();
    active = null;
}

// ---------------------------------------------------------------------
//  helpers feeds (defaut sains si bridge down)
// ---------------------------------------------------------------------
const F = () => window.feeds ?? {
    netz:{freq:50,dev:0}, swpc:{wind_speed:400,bz:0,kp:2,flare_norm:0},
    usgs:{last_mag:0}, light:{}, sky:{}, bsky:{rate_s:0},
    rte:{renew_pct:0.25, total:50000},
};

// ---------------------------------------------------------------------
//  PRESET cavity (16-A) : drone Schumann + grain foudre
// ---------------------------------------------------------------------
function startCavity() {
    const out = ctx.createGain(); out.gain.value = 0.0;
    out.connect(master);
    out.gain.linearRampToValueAtTime(0.22, ctx.currentTime + 2.0);

    // additif harmonique sur 7.83 Hz x [1,2,3,4,5] -- monte d'octave x8
    // (7.83 trop sub pour Web Audio, on fait 7.83 * 8 = 62.6 Hz fondamental)
    const f0 = 7.83 * 8;
    const partials = [1, 2, 3, 4, 5];
    const amps     = [1, 0.5, 0.33, 0.25, 0.2];
    const oscs = partials.map((h, i) => {
        const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = f0 * h;
        const g = ctx.createGain();       g.gain.value = amps[i] * 0.18;
        o.connect(g).connect(out);
        // FM par derive netz_dev (tres petite)
        o.start();
        return { o, g };
    });

    // routine maj FM
    const tickFm = setInterval(() => {
        const dev = F().netz.dev || 0;
        oscs.forEach(({ o }, i) => {
            const target = f0 * partials[i] + dev * 80;
            o.frequency.linearRampToValueAtTime(target, ctx.currentTime + 0.1);
        });
    }, 100);

    // foudre : grain percussif spatialise (filtered noise + sin click)
    const onStrike = (a) => {
        const lat = a[0], lon = a[1], age = a[2], mult = a[3] || 1;
        if (age > 30) return;
        const pan = Math.max(-1, Math.min(1, lon / 180));
        const freq = 200 + (lat + 90) / 180 * 2800;
        const dur  = 0.2 + Math.min(mult, 10) / 10 * 0.6;
        triggerStrike(out, freq, pan, dur, 0.4 + mult / 25);
    };
    window.onFeed("/data/blitzortung/strike", onStrike);

    return { stop: () => {
        clearInterval(tickFm);
        out.gain.cancelScheduledValues(ctx.currentTime);
        out.gain.linearRampToValueAtTime(0, ctx.currentTime + 2);
        oscs.forEach(({ o }) => o.stop(ctx.currentTime + 2.2));
    }};
}

function triggerStrike(dest, freq, pan, dur, amp) {
    const t = ctx.currentTime;
    const noise = ctx.createBufferSource();
    const buf = ctx.createBuffer(1, ctx.sampleRate * dur, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1);
    noise.buffer = buf;
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass"; bp.frequency.value = freq; bp.Q.value = 8;
    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(amp, t + 0.005);
    env.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const panner = ctx.createStereoPanner(); panner.pan.value = pan;
    noise.connect(bp).connect(env).connect(panner).connect(dest);
    noise.start(t); noise.stop(t + dur + 0.05);
    const sin = ctx.createOscillator(); sin.frequency.value = freq;
    const sg = ctx.createGain();
    sg.gain.setValueAtTime(0, t);
    sg.gain.linearRampToValueAtTime(amp * 0.5, t + 0.005);
    sg.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    sin.connect(sg).connect(panner);
    sin.start(t); sin.stop(t + dur + 0.05);
}

// ---------------------------------------------------------------------
//  PRESET mix (16-B) : pad sawtooth + cutoff RLPF par renew_pct
// ---------------------------------------------------------------------
function startMix() {
    const out = ctx.createGain(); out.gain.value = 0; out.connect(master);
    out.gain.linearRampToValueAtTime(0.18, ctx.currentTime + 1.5);

    const f0 = 55;
    const ratios = [1, 1.005, 0.503, 2.01];
    const oscs = ratios.map(r => {
        const o = ctx.createOscillator(); o.type = "sawtooth";
        o.frequency.value = f0 * r;
        return o;
    });
    const sum = ctx.createGain(); sum.gain.value = 1 / ratios.length;
    oscs.forEach(o => o.connect(sum));
    const lpf = ctx.createBiquadFilter();
    lpf.type = "lowpass"; lpf.frequency.value = 800; lpf.Q.value = 3;
    sum.connect(lpf).connect(out);
    oscs.forEach(o => o.start());

    const tick = setInterval(() => {
        const pct = F().rte.renew_pct ?? 0.25;
        // 0..0.5 -> 200..5000 (exp)
        const cut = 200 * Math.pow(5000/200, Math.min(0.5, pct) / 0.5);
        const q   = 0.5 + (1 - Math.min(1, pct * 2)) * 8;
        lpf.frequency.linearRampToValueAtTime(cut, ctx.currentTime + 1.5);
        lpf.Q.linearRampToValueAtTime(q, ctx.currentTime + 1.5);
    }, 1500);

    // OpenSky -> blip melodique
    const onPlane = (a) => {
        const lon = a[1], alt = a[3], vel = a[4];
        const pan = Math.max(-1, Math.min(1, (lon - 4.9) / 0.3));
        const midi = Math.max(24, Math.min(96, 36 + alt / 12000 * 48));
        const freq = 440 * Math.pow(2, (midi - 69) / 12);
        triggerBlip(out, freq, pan, 0.6, Math.min(0.35, 0.1 + vel / 1500));
    };
    window.onFeed("/data/opensky/plane", onPlane);

    return { stop: () => {
        clearInterval(tick);
        out.gain.cancelScheduledValues(ctx.currentTime);
        out.gain.linearRampToValueAtTime(0, ctx.currentTime + 2);
        oscs.forEach(o => o.stop(ctx.currentTime + 2.2));
    }};
}

function triggerBlip(dest, freq, pan, dur, amp) {
    const t = ctx.currentTime;
    const o1 = ctx.createOscillator(); o1.type = "sine"; o1.frequency.value = freq;
    const o2 = ctx.createOscillator(); o2.type = "sine"; o2.frequency.value = freq * 2.01;
    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(amp, t + 0.01);
    env.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const pann = ctx.createStereoPanner(); pann.pan.value = pan;
    o1.connect(env); o2.connect(env); env.connect(pann).connect(dest);
    o1.start(t); o2.start(t); o1.stop(t + dur + 0.05); o2.stop(t + dur + 0.05);
}

// ---------------------------------------------------------------------
//  PRESET geo (16-C) : BPF + sub-bass quake + flare boost
// ---------------------------------------------------------------------
function startGeo() {
    const out = ctx.createGain(); out.gain.value = 0; out.connect(master);
    out.gain.linearRampToValueAtTime(0.25, ctx.currentTime + 2.0);

    const oscs = [55, 110, 165].map(f => {
        const o = ctx.createOscillator(); o.type = "sawtooth"; o.frequency.value = f;
        return o;
    });
    const sum = ctx.createGain(); sum.gain.value = 0.33;
    oscs.forEach(o => o.connect(sum));
    const bpf = ctx.createBiquadFilter();
    bpf.type = "bandpass"; bpf.frequency.value = 400; bpf.Q.value = 2;
    sum.connect(bpf).connect(out);
    oscs.forEach(o => o.start());

    const tick = setInterval(() => {
        const kp = F().swpc.kp ?? 2;
        // 0..9 -> 200..3000 (exp)
        const f = 200 * Math.pow(15, Math.min(9, kp) / 9);
        const q = 1 + (1 - Math.min(1, kp/9)) * 18;
        bpf.frequency.linearRampToValueAtTime(f, ctx.currentTime + 4);
        bpf.Q.linearRampToValueAtTime(q, ctx.currentTime + 4);
    }, 4000);

    const onQuake = (mag) => triggerQuakeSub(out, mag);
    const wrap = (a) => onQuake(a[0]);
    window.onFeed("/data/usgs/event", wrap);

    const onFlare = (a) => {
        if ((a[2] || 0) > 0.5) {
            out.gain.cancelScheduledValues(ctx.currentTime);
            out.gain.linearRampToValueAtTime(0.55, ctx.currentTime + 0.05);
            out.gain.linearRampToValueAtTime(0.25, ctx.currentTime + 3);
        }
    };
    window.onFeed("/data/swpc/xray", onFlare);

    return { stop: () => {
        clearInterval(tick);
        out.gain.cancelScheduledValues(ctx.currentTime);
        out.gain.linearRampToValueAtTime(0, ctx.currentTime + 2);
        oscs.forEach(o => o.stop(ctx.currentTime + 2.2));
    }};
}

function triggerQuakeSub(dest, mag) {
    const t = ctx.currentTime;
    const m = Math.max(2, Math.min(8, mag));
    const f = 30 * Math.pow(4, (m - 2) / 6);
    const dur = 1 + (m - 2) * 0.7;
    const amp = 0.4 + (m - 2) / 6 * 0.5;
    const o1 = ctx.createOscillator(); o1.type = "sine";     o1.frequency.value = f;
    const o2 = ctx.createOscillator(); o2.type = "triangle"; o2.frequency.value = f * 0.5;
    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(amp, t + 0.05);
    env.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o1.connect(env); o2.connect(env); env.connect(dest);
    o1.start(t); o2.start(t); o1.stop(t + dur + 0.05); o2.stop(t + dur + 0.05);
}

// ---------------------------------------------------------------------
//  PRESET aurora (17-D) : additif Bz/wind/Kp
// ---------------------------------------------------------------------
function startAurora() {
    const out = ctx.createGain(); out.gain.value = 0; out.connect(master);
    out.gain.linearRampToValueAtTime(0.22, ctx.currentTime + 3.0);

    const f0 = 55;
    const harm = [1, 1.0, 2, 2.01, 3, 3.02, 5];
    const ratio = 1; // ajuste par routine
    const amps = [1, 0.7, 0.5, 0.4, 0.3, 0.25, 0.15];
    const oscs = harm.map((h, i) => {
        const o = ctx.createOscillator(); o.type = "sine";
        const g = ctx.createGain(); g.gain.value = amps[i] * 0.12;
        o.connect(g);
        return { o, g, h };
    });
    const lpf = ctx.createBiquadFilter();
    lpf.type = "lowpass"; lpf.frequency.value = 2000; lpf.Q.value = 0.7;
    oscs.forEach(({ g }) => g.connect(lpf));
    lpf.connect(out);
    oscs.forEach(({ o }) => o.start());

    const tick = setInterval(() => {
        const fe = F();
        const bz   = fe.swpc.bz ?? 0;
        const wind = fe.swpc.wind_speed ?? 400;
        const kp   = fe.swpc.kp ?? 2;
        const a    = fe.swpc.a  ?? 5;
        // shift de freq par Bz : -20 nT -> *0.5, +20 -> *1.4
        const fmul = 0.5 * Math.pow(2.8, Math.max(-20, Math.min(20, bz + 20)) / 40);
        // detune par vent (250..900 -> 0.002..0.025)
        const det = 0.002 + Math.max(0, Math.min(650, wind - 250)) / 650 * 0.023;
        oscs.forEach(({ o, h }) => {
            const target = f0 * fmul * h * (1 + (Math.random() - 0.5) * det);
            o.frequency.linearRampToValueAtTime(target, ctx.currentTime + 2.0);
        });
        // kp -> brillance (600..8000 exp)
        const cut = 600 * Math.pow(8000/600, Math.min(9, kp) / 9);
        lpf.frequency.linearRampToValueAtTime(cut, ctx.currentTime + 2.0);
        // a-index -> amp 0.18..0.32
        const amp = 0.18 + Math.min(50, a) / 50 * 0.14;
        out.gain.linearRampToValueAtTime(amp, ctx.currentTime + 2.0);
    }, 2000);

    return { stop: () => {
        clearInterval(tick);
        out.gain.cancelScheduledValues(ctx.currentTime);
        out.gain.linearRampToValueAtTime(0, ctx.currentTime + 4);
        oscs.forEach(({ o }) => o.stop(ctx.currentTime + 4.2));
    }};
}

// ---------------------------------------------------------------------
//  PRESET pulse (17-E) : kick netz + clicks bsky + sub usgs
// ---------------------------------------------------------------------
function startPulse() {
    const out = ctx.createGain(); out.gain.value = 0.6; out.connect(master);
    let stopped = false;
    let timer = null;

    function tick() {
        if (stopped) return;
        const fe = F();
        const hz  = fe.netz.freq || 50.0;
        const dev = fe.netz.dev || 0;
        const bpm = hz * 2.5;
        const beat = 60 / bpm;
        // kick
        const t = ctx.currentTime;
        const fK = 50 + dev * 30;
        const o = ctx.createOscillator(); o.type = "sine";
        o.frequency.setValueAtTime(fK * 5, t);
        o.frequency.exponentialRampToValueAtTime(fK, t + 0.12);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0, t);
        g.gain.linearRampToValueAtTime(0.7, t + 0.005);
        g.gain.exponentialRampToValueAtTime(0.0001, t + 0.4);
        const sat = ctx.createWaveShaper(); sat.curve = makeTanhCurve(2);
        o.connect(g).connect(sat).connect(out);
        o.start(t); o.stop(t + 0.45);
        // hat off-beat si grille stable
        if (Math.abs(dev) < 0.02) {
            timer = setTimeout(() => triggerHat(out), beat * 500);
            setTimeout(tick, beat * 1000);
        } else {
            setTimeout(tick, beat * 1000);
        }
    }
    tick();

    const onBskyRate = (a) => {
        const n = Math.min(30, Math.floor(a[0] || 0));
        for (let i = 0; i < n; i++) {
            setTimeout(() => triggerClick(out), i * 30 + Math.random() * 1000);
        }
    };
    window.onFeed("/data/bluesky/rate", onBskyRate);

    const onQuake = (a) => triggerQuakeSub(out, a[0]);
    window.onFeed("/data/usgs/event", onQuake);

    return { stop: () => {
        stopped = true;
        if (timer) clearTimeout(timer);
        out.gain.cancelScheduledValues(ctx.currentTime);
        out.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.5);
    }};
}

function triggerHat(dest) {
    const t = ctx.currentTime;
    const buf = ctx.createBuffer(1, ctx.sampleRate * 0.04, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource(); src.buffer = buf;
    const hp = ctx.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 8000;
    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(0.18, t + 0.001);
    env.gain.exponentialRampToValueAtTime(0.0001, t + 0.04);
    const pan = ctx.createStereoPanner(); pan.pan.value = 0.3;
    src.connect(hp).connect(env).connect(pan).connect(dest);
    src.start(t); src.stop(t + 0.05);
}

function triggerClick(dest) {
    const t = ctx.currentTime;
    const f = 800 * Math.pow(10, Math.random());
    const o = ctx.createOscillator(); o.type = "sine"; o.frequency.value = f;
    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(0.06 + Math.random() * 0.1, t + 0.0005);
    env.gain.exponentialRampToValueAtTime(0.0001, t + 0.02);
    const pan = ctx.createStereoPanner(); pan.pan.value = Math.random() * 2 - 1;
    o.connect(env).connect(pan).connect(dest);
    o.start(t); o.stop(t + 0.025);
}

function makeTanhCurve(k) {
    const n = 1024, c = new Float32Array(n);
    for (let i = 0; i < n; i++) {
        const x = (i / (n - 1)) * 2 - 1;
        c[i] = Math.tanh(x * k);
    }
    return c;
}

// ---------------------------------------------------------------------
//  HUD + scope
// ---------------------------------------------------------------------
const aliveEl = document.getElementById("alive");
const kpEl = document.getElementById("kp");
const bzEl = document.getElementById("bz");
const windEl = document.getElementById("wind");
const netzEl = document.getElementById("netz");
const flareEl = document.getElementById("flare");
setInterval(() => {
    const a = window.feeds?.alive;
    aliveEl.textContent = a ? "ALIVE" : "DOWN";
    aliveEl.className   = a ? "alive" : "dead";
    kpEl.textContent    = (window.feeds?.swpc.kp ?? 0).toFixed(1);
    bzEl.textContent    = (window.feeds?.swpc.bz ?? 0).toFixed(1);
    windEl.textContent  = (window.feeds?.swpc.wind_speed ?? 0).toFixed(0);
    netzEl.textContent  = (window.feeds?.netz.freq ?? 0).toFixed(3);
    flareEl.textContent = (window.feeds?.swpc.flare_norm ?? 0).toFixed(2);
}, 250);

const scope = document.getElementById("scope");
const sctx = scope.getContext("2d");
function drawScope() {
    if (!analyser) return;
    requestAnimationFrame(drawScope);
    const W = scope.width = scope.clientWidth;
    const H = scope.height = scope.clientHeight;
    const buf = new Uint8Array(analyser.fftSize);
    analyser.getByteTimeDomainData(buf);
    sctx.fillStyle = "#0a0a12"; sctx.fillRect(0, 0, W, H);
    sctx.strokeStyle = "#5b8bff"; sctx.lineWidth = 1.2; sctx.beginPath();
    for (let i = 0; i < buf.length; i++) {
        const x = i / buf.length * W;
        const y = H/2 + (buf[i] / 128.0 - 1) * H/2 * 0.9;
        if (i === 0) sctx.moveTo(x, y); else sctx.lineTo(x, y);
    }
    sctx.stroke();
}
