// =====================================================================
//  control/app.js -- surface de controle OSC pour sound_algo
// =====================================================================

// ---------- WebSocket bridge -----------------------------------------
let ws;
const wsStatus = document.getElementById("ws-status");
const wsLabel = document.getElementById("ws-label");

function connect() {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    ws = new WebSocket(`${proto}//${location.host}/ws`);

    ws.addEventListener("open", () => {
        wsStatus.classList.add("online");
        wsStatus.classList.remove("offline");
        wsLabel.textContent = "online";
    });
    ws.addEventListener("close", () => {
        wsStatus.classList.remove("online");
        wsStatus.classList.add("offline");
        wsLabel.textContent = "reconnecting…";
        setTimeout(connect, 1000);
    });
    ws.addEventListener("message", (ev) => {
        try {
            const msg = JSON.parse(ev.data);
            // Reception de feedback SC -> peut etre utilise pour update UI
            // console.log("[ws<-]", msg.address, msg.args);
        } catch {}
    });
}

function send(address, ...args) {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify({ address, args }));
}

connect();

// ---------- Sliders et boutons declaratifs ---------------------------
document.querySelectorAll('input[type="range"][data-osc]').forEach((el) => {
    const out = el.dataset.output && document.querySelector(`output[data-output="${el.dataset.output}"]`);
    const update = () => {
        const v = parseFloat(el.value);
        if (out) out.textContent = v.toFixed(v < 10 ? 2 : 0);
        send(el.dataset.osc, v);
    };
    el.addEventListener("input", update);
    update();
});

document.querySelectorAll('button[data-osc]').forEach((el) => {
    el.addEventListener("click", () => {
        const args = el.dataset.args
            ? el.dataset.args.split(/\s+/).map((a) => {
                const n = parseFloat(a);
                return Number.isNaN(n) ? a : n;
            })
            : [];
        send(el.dataset.osc, ...args);
    });
});

// ---------- Mixer (8 voies) ------------------------------------------
const VOICES = ["kick", "hat", "snare", "clap", "perc", "acid", "melody", "harmony"];
const muted = new Set(), soloed = new Set();
const mixerGrid = document.querySelector(".mixer-grid");

VOICES.forEach((v) => {
    const card = document.createElement("div");
    card.className = "mixer-voice";
    card.innerHTML = `
        <div class="name">${v}</div>
        <input type="range" min="0" max="1.5" step="0.01" value="1" />
        <div class="vol-display">1.00</div>
        <div class="actions">
            <button class="mute" type="button">M</button>
            <button class="solo" type="button">S</button>
        </div>
    `;
    const slider = card.querySelector('input');
    const display = card.querySelector('.vol-display');
    slider.addEventListener("input", () => {
        display.textContent = parseFloat(slider.value).toFixed(2);
        send("/control/setVol", v, parseFloat(slider.value));
    });
    card.querySelector('.mute').addEventListener("click", (e) => {
        const btn = e.currentTarget;
        if (muted.has(v)) {
            muted.delete(v);
            btn.classList.remove("active");
            send("/control/unmute", v);
        } else {
            muted.add(v);
            btn.classList.add("active");
            send("/control/mute", v);
        }
    });
    card.querySelector('.solo').addEventListener("click", (e) => {
        const btn = e.currentTarget;
        if (soloed.has(v)) {
            soloed.delete(v);
            btn.classList.remove("active");
            send("/control/unsolo");
        } else {
            // Reset solo precedent (single solo only)
            mixerGrid.querySelectorAll('.solo.active').forEach(b => b.classList.remove("active"));
            soloed.clear();
            soloed.add(v);
            btn.classList.add("active");
            send("/control/solo", v);
        }
    });
    mixerGrid.appendChild(card);
});

// ---------- Kicks (~kk presets) --------------------------------------
const KICKS = ["techno","gabber","dub","dubstep","trance","hardstyle","amen","dnb","jungle","house","detroit","phonk","afro","garage","triphop","footwork","minimal","electro"];
const kicksChips = document.getElementById("kicks-chips");
KICKS.forEach((k) => {
    const b = document.createElement("button");
    b.className = "chip";
    b.textContent = k;
    b.addEventListener("click", () => {
        kicksChips.querySelectorAll('.chip.active').forEach(c => c.classList.remove("active"));
        b.classList.add("active");
        send("/control/kk", k);
    });
    kicksChips.appendChild(b);
});

// ---------- Patterns (~pKit / ~pGenre) -------------------------------
const PKITS = ["techno","dubstep","dnb","trap","house","hardstyle","jungle","phonk","industrial","hardcore","detroitDeep","lofiHipHop","tribalWorld"];
const PGENRES = ["hardTechno","acidHouse","trance138","psyTrance","liquidDnB","neurofunk","jungle165","futureBass","deepHouse","techHouse","industrialV2","breakcore","footwork","idm","glitchHop"];

const pkitChips = document.getElementById("pkit-chips");
PKITS.forEach((k) => {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = "kit " + k;
    b.addEventListener("click", () => send("/control/pKit", k));
    pkitChips.appendChild(b);
});
const pgenreChips = document.getElementById("pgenre-chips");
PGENRES.forEach((k) => {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = "genre " + k;
    b.addEventListener("click", () => send("/control/pGenre", k));
    pgenreChips.appendChild(b);
});

// ---------- FX preset (~ff) ------------------------------------------
const FF = ["dub","space","trance","dubstep","retro","industrial","dream","cosmic","drone","dry"];
const ffChips = document.getElementById("ff-chips");
FF.forEach((k) => {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = k;
    b.addEventListener("click", () => {
        ffChips.querySelectorAll('.chip.active').forEach(c => c.classList.remove("active"));
        b.classList.add("active");
        send("/control/ff", k);
    });
    ffChips.appendChild(b);
});

// ---------- Step sequencer 8 voies x 16 pas --------------------------
const SEQ_VOICES = ["kick", "hat", "snare", "clap", "perc"];
const seqGrid = document.getElementById("seq-grid");
const seqState = {};
SEQ_VOICES.forEach(v => { seqState[v] = new Array(16).fill(0); });

SEQ_VOICES.forEach((v) => {
    const label = document.createElement("div");
    label.className = "seq-label";
    label.textContent = v;
    seqGrid.appendChild(label);
    for (let i = 0; i < 16; i++) {
        const cell = document.createElement("div");
        cell.className = "seq-cell";
        cell.dataset.voice = v;
        cell.dataset.step = i;
        cell.addEventListener("click", () => {
            seqState[v][i] = seqState[v][i] ? 0 : 1;
            cell.classList.toggle("on", !!seqState[v][i]);
        });
        seqGrid.appendChild(cell);
    }
});

document.querySelectorAll('button[data-action]').forEach((el) => {
    el.addEventListener("click", () => {
        const action = el.dataset.action;
        if (action === "seq-clear") {
            SEQ_VOICES.forEach(v => {
                seqState[v].fill(0);
                seqGrid.querySelectorAll(`.seq-cell[data-voice="${v}"]`)
                    .forEach(c => c.classList.remove("on"));
            });
        }
        if (action === "seq-random") {
            SEQ_VOICES.forEach(v => {
                seqState[v] = Array.from({length:16}, () => Math.random() < 0.35 ? 1 : 0);
                seqGrid.querySelectorAll(`.seq-cell[data-voice="${v}"]`).forEach((c,i) => {
                    c.classList.toggle("on", !!seqState[v][i]);
                });
            });
        }
        if (action === "seq-send") {
            SEQ_VOICES.forEach(v => {
                send(`/control/${v}Steps`, ...seqState[v]);
            });
        }
        if (action === "lfo-on") {
            const target = document.getElementById("lfo-target").value;
            const rate = parseFloat(document.querySelector('[data-output="lfoRate"]').textContent);
            const depth = parseFloat(document.querySelector('[data-output="lfoDepth"]').textContent);
            send("/control/lfoTo", target, rate, depth);
        }
        if (action === "lfo-off") {
            const target = document.getElementById("lfo-target").value;
            send("/control/lfoStop", target);
        }
        if (action === "lfo-stop-all") {
            send("/control/lfoStopAll");
        }
    });
});

// Bind les outputs des sliders LFO
document.querySelectorAll('input[type="range"][data-output]').forEach((el) => {
    if (el.dataset.osc) return; // deja gere
    const out = document.querySelector(`output[data-output="${el.dataset.output}"]`);
    el.addEventListener("input", () => {
        if (out) out.textContent = parseFloat(el.value).toFixed(2);
    });
});

// ---------- FX par voie (cutoff/drive/RQ) ----------------------------
const FX_VOICES = [
    { name: "melody", cutoff: 5000, drive: 1.0, rq: 0.4 },
    { name: "acid",   cutoff: 1500, drive: 2.0, rq: 0.25 },
    { name: "kick",   cutoff: 5000, drive: 1.0, rq: 0.5 },
    { name: "hat",    cutoff: 8000, drive: 1.0, rq: 0.5 },
];
const fxGrid = document.querySelector(".fx-grid");
FX_VOICES.forEach((cfg) => {
    const card = document.createElement("div");
    card.className = "fx-voice";
    card.innerHTML = `
        <div class="name">${cfg.name}</div>
        <label class="control">
            <span>Cutoff <output>${cfg.cutoff}</output></span>
            <input type="range" min="50" max="12000" step="10" value="${cfg.cutoff}" data-fx="cut" data-voice="${cfg.name}" />
        </label>
        <label class="control">
            <span>Drive <output>${cfg.drive.toFixed(1)}</output></span>
            <input type="range" min="0.5" max="5" step="0.05" value="${cfg.drive}" data-fx="drive" data-voice="${cfg.name}" />
        </label>
        <label class="control">
            <span>RQ <output>${cfg.rq.toFixed(2)}</output></span>
            <input type="range" min="0.05" max="1.5" step="0.01" value="${cfg.rq}" data-fx="rq" data-voice="${cfg.name}" />
        </label>
    `;
    card.querySelectorAll('input[type="range"]').forEach((el) => {
        const out = el.parentElement.querySelector('output');
        el.addEventListener("input", () => {
            const v = parseFloat(el.value);
            out.textContent = v < 10 ? v.toFixed(2) : v.toFixed(0);
            send(`/control/fx${el.dataset.fx[0].toUpperCase()}${el.dataset.fx.slice(1)}`,
                 el.dataset.voice, v);
        });
    });
    fxGrid.appendChild(card);
});
