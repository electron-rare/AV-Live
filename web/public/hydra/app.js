// =====================================================================
//  hydra/app.js -- canvas Hydra synchronise avec sound_algo via WebSocket
//
//  Variables globales injectees par le bridge :
//    window.bpm    : BPM courant (envoye par SC sur /sync/bpm)
//    window.beat   : compteur de beat (incremente sur /sync/beat)
//    window.amp    : { kick, hat, snare, melody, acid }
//                    amplitudes RMS par voie envoyees par SC
//
//  Dans tes patches Hydra, utilise ces globales pour reagir au son.
// =====================================================================

// ---------- WebSocket bridge -----------------------------------------
window.bpm = 128;
window.beat = 0;
window.amp = { kick: 0, hat: 0, snare: 0, melody: 0, acid: 0 };

const wsState = document.getElementById("ws-state");
const bpmDisplay = document.getElementById("bpm");
const beatDisplay = document.getElementById("beat");

function connect() {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(`${proto}//${location.host}/ws`);

    ws.addEventListener("open", () => { wsState.textContent = "online"; wsState.style.color = "#38d977"; });
    ws.addEventListener("close", () => {
        wsState.textContent = "reconnecting…";
        wsState.style.color = "#ff5151";
        setTimeout(connect, 1000);
    });

    ws.addEventListener("message", (ev) => {
        try {
            const msg = JSON.parse(ev.data);
            const [, type] = msg.address.split("/sync/");
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
                    // [voiceName, amp]
                    const [voice, amp] = msg.args;
                    if (voice in window.amp) window.amp[voice] = amp;
                    break;
                }
            }
        } catch {}
    });
}
connect();

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
};

// ---------- Editor + run --------------------------------------------
const editor = document.getElementById("editor");
const codeArea = document.getElementById("code");
const status = document.getElementById("status");
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
        codeArea.value = PRESETS[btn.dataset.preset];
        run();
    });
});

toggleBtn.addEventListener("click", () => editor.classList.toggle("open"));
window.addEventListener("keydown", (e) => {
    if (e.key === "e" && !["TEXTAREA", "INPUT"].includes(document.activeElement.tagName)) {
        editor.classList.toggle("open");
    }
});

// Lance le preset par defaut au demarrage
run();
