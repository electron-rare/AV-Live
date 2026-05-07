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
            } else if (addr === "/hydra/param") {
                const [name, val] = msg.args;
                if (name in window.hydraParams) {
                    window.hydraParams[name] = val;
                }
            }
        } catch {}
    });
}

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
