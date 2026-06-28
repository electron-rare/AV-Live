const ws = new WebSocket(`ws://${location.host}/ws`);
const dot = () => document.getElementById("status");
ws.addEventListener("open", () => dot().className = "on");
ws.addEventListener("close", () => dot().className = "off");
function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
const armed = new Set();
const clipState = new Map(); // name -> last-known state int: 0 off, 1 playing, 2 queued-launch, 3 queued-stop
function togglePad(el, name) {
  // Use last-known state for toggle direction; fall back to armed Set
  const st = clipState.has(name) ? clipState.get(name) : (armed.has(name) ? 1 : 0);
  // launch (1) when off or queued-stop; stop (0) when playing or queued-launch
  const launch = (st === 0 || st === 3);
  // optimistic feedback — authoritative update comes from /armed feedback
  el.classList.add("queued");
  if (launch) el.classList.add("armed");
  send("/launch", name, launch ? 1 : 0);
}

// --- Feedback: engine -> browser ---
let suppressEmit = false;
let beatFlashTimer = null;

ws.addEventListener("message", (ev) => {
  let msg;
  try { msg = JSON.parse(ev.data); } catch (_e) { return; }
  if (!msg || typeof msg.address !== "string") return;
  const { address, args } = msg;

  // /armed/<name> — engine is source of truth; args[0] is a state int 0-3
  // 0 = off, 1 = playing (solid), 2 = queued-launch (blink), 3 = queued-stop (blink)
  if (address.startsWith("/armed/")) {
    const name = address.slice(7); // strip "/armed/"
    const st = Number(args[0]);
    clipState.set(name, st);
    if (st >= 1) armed.add(name); else armed.delete(name);
    document.querySelectorAll(`[data-pad="${name}"]`).forEach((btn) => {
      btn.classList.toggle("armed", st >= 1);
      btn.classList.toggle("queued", st === 2 || st === 3);
    });
    return;
  }

  // /sync/beat — flash beat dot for 80 ms; cancel any pending clear first
  if (address === "/sync/beat") {
    const beatDot = document.getElementById("beat-dot");
    if (!beatDot) return;
    if (beatFlashTimer !== null) { clearTimeout(beatFlashTimer); beatFlashTimer = null; }
    beatDot.classList.add("flash");
    beatFlashTimer = setTimeout(() => {
      beatDot.classList.remove("flash");
      beatFlashTimer = null;
    }, 80);
    return;
  }

  // /sync/rms — drive master VU meter width
  if (address === "/sync/rms") {
    const raw = Number(args[0]);
    const rms = Number.isFinite(raw) ? Math.max(0, Math.min(1, raw)) : 0;
    const bar = document.getElementById("vu-bar");
    if (bar) bar.style.width = `${rms * 100}%`;
    return;
  }

  // /seq/rhythm/state [idx, k, s, h, name]
  if (address === "/seq/rhythm/state") {
    if (!state) return;
    const i = Math.round(Number(args[0]));
    if (!Number.isFinite(i) || i < 0 || i >= state.rhythms.length) return;
    if (typeof args[1] === "string") state.rhythms[i].k = args[1];
    if (typeof args[2] === "string") state.rhythms[i].s = args[2];
    if (typeof args[3] === "string") state.rhythms[i].h = args[3];
    if (typeof args[4] === "string") state.rhythms[i].name = args[4];
    state.rhySel = i;
    saveState();
    suppressEmit = true;
    try {
      restoreSel("rhythm", i);
      updateSelLabels("rhythm");
      updateNameInputs();
      renderRhyGrid();
    } finally {
      suppressEmit = false;
    }
    return;
  }

  // /seq/melody/state [idx, deg0, deg1, ...]
  if (address === "/seq/melody/state") {
    if (!state) return;
    const i = Math.round(Number(args[0]));
    if (!Number.isFinite(i) || i < 0 || i >= state.melodies.length) return;
    const degs = args.slice(1).map(Number).filter(Number.isFinite);
    if (degs.length > 0) state.melodies[i].degrees = degs;
    state.melSel = i;
    saveState();
    suppressEmit = true;
    try {
      restoreSel("melody", i);
      updateSelLabels("melody");
      updateNameInputs();
      renderMelSteps();
    } finally {
      suppressEmit = false;
    }
    return;
  }
});

// --- Pattern state (defaults mirror launchpad.scd exactly) ---
const STORAGE_KEY = "avlive.seq";

const DFLT_RHYTHMS = [
  { name: "4floor",     k: "1000100010001000", s: "0000100000001000", h: "0010101010101010" },
  { name: "breakbeat",  k: "1000101010001000", s: "0000100100001001", h: "0101010101010101" },
  { name: "halftime",   k: "1000000010000000", s: "0000000000001000", h: "0010001001000010" },
  { name: "psyroll",    k: "1001100110011001", s: "0000100000001000", h: "1111111111111111" },
  { name: "garage",     k: "1000001010000010", s: "0000100000001000", h: "0101101001011010" },
  { name: "tribal",     k: "1010100010101000", s: "0000101000001010", h: "1010101010101010" },
  { name: "industrial", k: "1100110011001100", s: "0011001100110011", h: "0101010101010101" },
  { name: "jungle",     k: "1000100110001001", s: "0000100100001001", h: "1011101110111011" },
];

const DFLT_MELODIES = [
  { name: "Mélodie 1", degrees: [0, 2, 3, 5, 7, 5, 3, 2] },
  { name: "Mélodie 2", degrees: [0, 3, 7, 3, 0, -2] },
  { name: "Mélodie 3", degrees: [0, 0, 7, 0, 3, 5, 2, 0, 3, 5, 7, 3] },
  { name: "Mélodie 4", degrees: [7, 5, 3, 2, 0, -2, 0, 2] },
  { name: "Mélodie 5", degrees: [0, 2, 3, 5, 7, 10, 7, 5, 3, 0, 2, 3, 5, 3, 2, 0] },
  { name: "Mélodie 6", degrees: [0, 3, 7] },
  { name: "Mélodie 7", degrees: [0, 7, 5, 3, 7, 0] },
  { name: "Mélodie 8", degrees: [2, 0, -2, 0, 3, 2, 0, -2, 5, 3, 2, 0] },
];

let state = null;

function seedState() {
  state = {
    rhythms: DFLT_RHYTHMS.map(r => ({ name: r.name, k: r.k, s: r.s, h: r.h })),
    melodies: DFLT_MELODIES.map(m => ({ name: m.name, degrees: [...m.degrees] })),
    rhySel: 0,
    melSel: 0,
  };
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (
        parsed &&
        Array.isArray(parsed.rhythms) && parsed.rhythms.length === 8 &&
        Array.isArray(parsed.melodies) && parsed.melodies.length === 8 &&
        typeof parsed.rhySel === "number" &&
        typeof parsed.melSel === "number"
      ) {
        state = parsed;
        return;
      }
    }
  } catch (e) {}
  seedState();
}

function saveState() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (e) {}
}

// --- Render rhythm 3x16 step grid ---
function renderRhyGrid() {
  const container = document.getElementById("rhy-grid");
  if (!container) return;
  const r = state.rhythms[state.rhySel];
  const voices = [
    { key: "k", label: "K", str: r.k },
    { key: "s", label: "S", str: r.s },
    { key: "h", label: "H", str: r.h },
  ];
  container.innerHTML = voices.map(v =>
    `<div class="step-row">` +
    `<span class="step-row-label">${v.label}</span>` +
    Array.from({ length: 16 }, (_, i) => {
      const on = (v.str[i] || "0") === "1";
      return `<button class="step-cell${on ? " on" : ""}" data-voice="${v.key}" data-step="${i}" aria-pressed="${on}"></button>`;
    }).join("") +
    `</div>`
  ).join("");
  container.querySelectorAll(".step-cell").forEach(cell =>
    cell.addEventListener("click", () => {
      if (suppressEmit) return;
      const voice = cell.dataset.voice;
      const step = +cell.dataset.step;
      const preset = state.rhythms[state.rhySel];
      const arr = preset[voice].split("");
      arr[step] = arr[step] === "1" ? "0" : "1";
      preset[voice] = arr.join("");
      saveState();
      const isOn = arr[step] === "1";
      cell.classList.toggle("on", isOn);
      cell.setAttribute("aria-pressed", isOn);
      send("/seq/rhythm/set", preset.k, preset.s, preset.h);
    })
  );
}

// --- Render melody degree inputs ---
function renderMelSteps() {
  const container = document.getElementById("mel-steps");
  if (!container) return;
  const m = state.melodies[state.melSel];
  container.innerHTML = m.degrees.map((deg, i) =>
    `<div class="mel-cell"><input type="number" min="-7" max="14" value="${deg}" data-midx="${i}"></div>`
  ).join("");
  container.querySelectorAll("input[type=number]").forEach(inp =>
    inp.addEventListener("change", () => {
      if (suppressEmit) return;
      const i = +inp.dataset.midx;
      const val = Math.max(-7, Math.min(14, isNaN(+inp.value) ? 0 : +inp.value));
      inp.value = val;
      state.melodies[state.melSel].degrees[i] = val;
      saveState();
      send("/seq/melody/set", ...state.melodies[state.melSel].degrees);
    })
  );
}

// --- Update selector button text from state ---
function updateSelLabels(group) {
  document.querySelectorAll(`[data-seq="${group}"]`).forEach(btn => {
    const idx = +btn.dataset.seqidx;
    if (group === "rhythm" && state.rhythms[idx]) {
      btn.textContent = state.rhythms[idx].name;
    } else if (group === "melody" && state.melodies[idx]) {
      btn.textContent = state.melodies[idx].name;
    }
  });
}

// --- Restore .sel highlight from persisted state ---
function restoreSel(group, idx) {
  document.querySelectorAll(`[data-seq="${group}"]`).forEach(b => b.classList.remove("sel"));
  const sel = document.querySelector(`[data-seq="${group}"][data-seqidx="${idx}"]`);
  if (sel) sel.classList.add("sel");
}

// --- Sync name inputs to selected preset ---
function updateNameInputs() {
  const mn = document.getElementById("mel-name");
  if (mn) mn.value = state.melodies[state.melSel].name;
  const rn = document.getElementById("rhy-name");
  if (rn) rn.value = state.rhythms[state.rhySel].name;
}

document.addEventListener("DOMContentLoaded", () => {
  loadState();

  // Tab switching
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
      document.querySelectorAll(".tab-panel").forEach((p) => p.classList.remove("active"));
      btn.classList.add("active");
      const panel = document.getElementById(`tab-${btn.dataset.tab}`);
      if (panel) panel.classList.add("active");
    });
  });

  // Render editors from state
  restoreSel("melody", state.melSel);
  restoreSel("rhythm", state.rhySel);
  updateSelLabels("melody");
  updateSelLabels("rhythm");
  updateNameInputs();
  renderRhyGrid();
  renderMelSteps();

  // Name input: rename selected preset and update button labels
  const melName = document.getElementById("mel-name");
  if (melName) {
    melName.addEventListener("input", () => {
      state.melodies[state.melSel].name = melName.value;
      saveState();
      updateSelLabels("melody");
    });
  }
  const rhyName = document.getElementById("rhy-name");
  if (rhyName) {
    rhyName.addEventListener("input", () => {
      state.rhythms[state.rhySel].name = rhyName.value;
      saveState();
      updateSelLabels("rhythm");
    });
  }

  // Pad arm buttons
  document.querySelectorAll("[data-pad]").forEach((el) =>
    el.addEventListener("click", () => togglePad(el, el.dataset.pad)));

  // Generic OSC buttons
  document.querySelectorAll("[data-osc]").forEach((el) =>
    el.addEventListener("click", () => {
      const a = el.dataset.arg;
      send(el.dataset.osc, ...(a === undefined ? [] : [isNaN(+a) ? a : +a]));
    }));

  // Vol sliders
  document.querySelectorAll("[data-vol]").forEach((el) =>
    el.addEventListener("input", () => send("/launch/vol", el.dataset.vol, +el.value)));

  // Tempo
  const tempo = document.getElementById("tempo");
  tempo && tempo.addEventListener("input", () => send("/launch/tempo", +tempo.value));

  // Filter
  const filt = document.getElementById("filter");
  filt && filt.addEventListener("input", () => send("/control/fx/filter", +filt.value));

  // Quantize selector
  document.querySelectorAll(".quant-btn").forEach(btn =>
    btn.addEventListener("click", () => {
      document.querySelectorAll(".quant-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      send("/launch/quant", +btn.dataset.quant);
    }));

  // Clear
  document.getElementById("clear").addEventListener("click", () => {
    armed.clear();
    document.querySelectorAll("[data-pad]").forEach((e) => e.classList.remove("armed"));
    send("/launch/clear");
  });

  // Seq selector buttons — select preset, reload editor, push OSC
  document.querySelectorAll("[data-seq]").forEach((el) =>
    el.addEventListener("click", () => {
      const group = el.dataset.seq;
      const idx = +el.dataset.seqidx;
      document.querySelectorAll(`[data-seq="${group}"]`).forEach((b) => b.classList.remove("sel"));
      el.classList.add("sel");
      if (group === "rhythm") {
        state.rhySel = idx;
        saveState();
        renderRhyGrid();
        updateNameInputs();
        send("/seq/rhythm", idx);
        const r = state.rhythms[idx];
        send("/seq/rhythm/set", r.k, r.s, r.h);
      } else {
        state.melSel = idx;
        saveState();
        renderMelSteps();
        updateNameInputs();
        send("/seq/melody", idx);
        send("/seq/melody/set", ...state.melodies[idx].degrees);
      }
    }));
});
