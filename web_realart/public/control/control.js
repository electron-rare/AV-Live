const ws = new WebSocket(`ws://${location.host}/ws`);
const dot = () => document.getElementById("status");
ws.addEventListener("open", () => { dot().className = "on"; send("/matrix/list"); });
ws.addEventListener("close", () => dot().className = "off");
function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
const armed = new Set();
const clipState = new Map(); // name -> last-known state int: 0 off, 1 playing, 2 queued-launch, 3 queued-stop

// --- Scene section mode ---
let sceneMode = "launch"; // "launch" | "save" | "clear"
function setSceneMode(mode) {
  sceneMode = mode;
  document.querySelectorAll(".mode-btn").forEach((b) => {
    b.classList.toggle("active", b.dataset.mode === mode);
  });
}
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

  // /scene/state <cur:int> <fill0:int> ... <fill7:int>
  if (address === "/scene/state") {
    const cur = Number(args[0]);
    document.querySelectorAll("[data-scene]").forEach((btn) => {
      const n = +btn.dataset.scene;
      btn.classList.toggle("filled", Number(args[n + 1]) === 1);
      btn.classList.toggle("current", n === cur);
    });
    return;
  }

  // /matrix/playhead <bar> — advance playhead column highlight
  if (address === "/matrix/playhead") {
    const bar = Math.round(Number(args[0]));
    if (!Number.isFinite(bar) || bar < 0 || bar >= MATRIX_BARS) return;
    if (matPlayhead >= 0) {
      for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
        const el = cellRefs[matPlayhead][vi];
        if (el) el.classList.remove("playing");
      }
    }
    matPlayhead = bar;
    for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
      const el = cellRefs[matPlayhead][vi];
      if (el) el.classList.add("playing");
    }
    updateTimelineHead(bar);
    return;
  }

  // /matrix/loop <start> <end> — loop region feedback
  if (address === "/matrix/loop") {
    const s = Math.round(Number(args[0]));
    const e = Math.round(Number(args[1]));
    if (Number.isFinite(s) && Number.isFinite(e) && s >= 0 && e < MATRIX_BARS) {
      matLoopStart = Math.min(s, e);
      matLoopEnd = Math.max(s, e);
      updateTimelineLoop();
    }
    return;
  }

  // /matrix/cell <vi> <bar> <color> — cross-surface cell sync
  if (address === "/matrix/cell") {
    const vi = Math.round(Number(args[0]));
    const bar = Math.round(Number(args[1]));
    const color = Math.round(Number(args[2]));
    if (vi < 0 || vi >= 16 || bar < 0 || bar >= MATRIX_BARS || color < 0 || color > 6) return;
    matGrid[vi][bar] = color;
    saveMatState();
    const el = cellRefs[bar][vi];
    if (el) {
      applyMatCellColor(el, color);
      if (bar === matPlayhead) el.classList.add("playing");
    }
    return;
  }

  // /matrix/list <name1> <name2> ... — populate saved/preset dropdown
  if (address === "/matrix/list") {
    const sel = document.getElementById("matrix-list");
    if (!sel) return;
    const prev = sel.value;
    sel.innerHTML = "";
    args.forEach(name => {
      const opt = document.createElement("option");
      opt.value = String(name);
      opt.textContent = String(name);
      sel.appendChild(opt);
    });
    // Preserve prior selection if still present
    if (args.map(String).includes(prev)) sel.value = prev;
    return;
  }

  // /matrix/grid <512 ints row-major vi*32+bar> — rebuild grid from loaded preset
  if (address === "/matrix/grid") {
    if (!Array.isArray(args) || args.length < 512) return;
    for (let vi = 0; vi < 16; vi++) {
      for (let bar = 0; bar < MATRIX_BARS; bar++) {
        const v = Math.round(Number(args[vi * 32 + bar]));
        matGrid[vi][bar] = (Number.isFinite(v) && v >= 0 && v <= 6) ? v : 0;
      }
    }
    saveMatState();
    renderMatrix();
    return;
  }

  // /matrix/trig <vi> <amp> — per-note pulse: glow the active cell of voice vi
  if (address === "/matrix/trig") {
    triggerGlow(Math.round(Number(args[0])), Number(args[1]));
    return;
  }

  // /matrix/instrument <vi> <inst> — single-voice instrument echo
  if (address === "/matrix/instrument") {
    const vi = Math.round(Number(args[0])); const v = String(args[1] ?? "default");
    if (vi >= 0 && vi < 16) {
      matInst[vi] = v; saveMatState();
      const sel = document.querySelector(`.minst[data-vi="${vi}"]`);
      if (sel) sel.value = v;
    }
    return;
  }
  // /matrix/instruments <16 strings> — bulk (preset load / kit)
  if (address === "/matrix/instruments") {
    for (let vi = 0; vi < 16 && vi < args.length; vi++) {
      const v = String(args[vi] ?? "default"); matInst[vi] = v;
      const sel = document.querySelector(`.minst[data-vi="${vi}"]`);
      if (sel) sel.value = v;
    }
    saveMatState();
    return;
  }
  if (address === "/matrix/mod") {
    const vi = Math.round(Number(args[0]));
    if (vi >= 0 && vi < 16) {
      matMod[vi] = { source:String(args[1]??"none"), target:String(args[2]??"none"), depth:Number(args[3])||0 };
      const r = document.querySelector(`.mmod-src[data-vi="${vi}"]`);
      if (r) { r.value = matMod[vi].source;
        document.querySelector(`.mmod-tgt[data-vi="${vi}"]`).value = matMod[vi].target;
        document.querySelector(`.mmod-dep[data-vi="${vi}"]`).value = matMod[vi].depth; }
      saveMatState();
    }
    return;
  }
  if (address === "/matrix/mods") {   // 16 triples flattened = 48 values
    for (let vi = 0; vi < 16; vi++) {
      const b = vi*3;
      matMod[vi] = { source:String(args[b]??"none"), target:String(args[b+1]??"none"), depth:Number(args[b+2])||0 };
      const r = document.querySelector(`.mmod-src[data-vi="${vi}"]`);
      if (r) { r.value=matMod[vi].source;
        document.querySelector(`.mmod-tgt[data-vi="${vi}"]`).value=matMod[vi].target;
        document.querySelector(`.mmod-dep[data-vi="${vi}"]`).value=matMod[vi].depth; }
    }
    saveMatState();
    return;
  }
  if (address === "/matrix/colordefs") {
    const vi = Math.round(Number(args[0]));
    if (vi >= 0 && vi < 16) {
      for (let c = 1; c <= 6; c++) {
        const b = 1 + (c - 1) * 6;
        matColorDefs[vi][c] = { stretch:Number(args[b]), octave:Math.round(Number(args[b+1])),
          amp:Number(args[b+2]), inst:String(args[b+3] ?? "default"),
          cutoff:Number(args[b+4]), pan:Number(args[b+5]) };
      }
      saveMatState();
      if (cdEditVoice === vi && !document.getElementById("colordef-modal").hidden) renderColorDefRows(vi);
    }
    return;
  }
});

// --- Matrix (16-voice x 32-bar song arranger) ---
const MATRIX_STORAGE_KEY = "avlive.matrix";
const MATRIX_VOICES = [
  "kick","hats","clap","perc","sub","acid","arp","lead",
  "stab","pad","ride","rim","tom","reese","bells","sweep"
];
// per-voice curated instrument options (must mirror SC ~matInstChoices)
// note-terminating synths only — the continuous do_ drones never free per-note.
const MATRIX_INST_CHOICES = {
  kick:["lp_kick","do_kick","do_quake_sub"], hats:["lp_hat","do_hat"],
  clap:["lp_clap","lp_rim","do_hat"], perc:["lp_perc","do_strike","lp_tom"],
  sub:["lp_sub","lp_reese","do_quake_sub"],
  acid:["lp_acid","lp_pluck"], arp:["lp_pluck","do_strike","lp_bells"],
  lead:["lp_pluck","do_plane","do_strike","lp_bells"], stab:["lp_pluck","lp_acid"],
  pad:["lp_pad","lp_reese","lp_sub"], ride:["lp_ride","lp_hat","do_hat"],
  rim:["lp_rim","lp_clap","do_hat"], tom:["lp_tom","do_strike","do_quake_sub"],
  reese:["lp_reese","lp_sub","lp_pad"],
  bells:["lp_bells","do_strike","do_plane"], sweep:["lp_sweep","lp_pad","lp_reese"]
};
let matInst = new Array(16).fill("default");   // per-voice selection (persisted)
const MATRIX_MOD_SOURCES = ["none","lHandY","rHandY","lOpen","rOpen","handSpeed","handDist","bodyY","depth"];
const MATRIX_MOD_TARGETS = {
  kick:["none","amp"], hats:["none","amp"], clap:["none","amp"], perc:["none","amp"],
  sub:["none","amp"], acid:["none","amp","cutoff","pan"], arp:["none","amp","cutoff","pan"],
  lead:["none","amp","cutoff","pan"], stab:["none","amp","cutoff","pan"], pad:["none","amp","cutoff"],
  ride:["none","amp"], rim:["none","amp"], tom:["none","amp"], reese:["none","amp"],
  bells:["none","amp"], sweep:["none","amp"]
};
let matMod = Array.from({length:16}, () => ({source:"none", target:"none", depth:0.5}));
let matColorDefs = Array.from({ length: 16 }, () =>
  [null,
   {stretch:1.0,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:0.5,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:1.0,octave:1,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:2.0,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:1.0,octave:-1,amp:1.05,inst:"default",cutoff:-1,pan:-2},
   {stretch:0.5,octave:0,amp:1.2,inst:"default",cutoff:-1,pan:-2}]);
let cdEditVoice = -1, cdAuditioning = false;
const MATRIX_BARS = 32;
let matGrid = Array.from({ length: 16 }, () => new Array(32).fill(0));
// cellRefs[bar][vi] for O(16) playhead column toggle
const cellRefs = Array.from({ length: 32 }, () => new Array(16).fill(null));
let matPlayhead = -1;
let matLoopStart = 0;
let matLoopEnd = 31;

function saveMatState() {
  try { localStorage.setItem(MATRIX_STORAGE_KEY,
    JSON.stringify({ grid: matGrid, inst: matInst, mod: matMod, cdef: matColorDefs })); } catch (_e) {}
}
function loadMatState() {
  try {
    const raw = JSON.parse(localStorage.getItem(MATRIX_STORAGE_KEY));
    if (raw && Array.isArray(raw.grid) && raw.grid.length === 16) { matGrid = raw.grid;
      if (Array.isArray(raw.inst) && raw.inst.length === 16) matInst = raw.inst;
      if (Array.isArray(raw.mod) && raw.mod.length === 16) matMod = raw.mod;
      if (Array.isArray(raw.cdef) && raw.cdef.length === 16) matColorDefs = raw.cdef;
      return; }
    if (Array.isArray(raw) && raw.length === 16) { matGrid = raw; return; }   // legacy: bare grid
  } catch (_e) {}
  matGrid = Array.from({ length: 16 }, () => new Array(32).fill(0));
}

function applyMatCellColor(el, color) {
  for (let c = 0; c <= 6; c++) el.classList.remove("m" + c);
  el.classList.add("m" + color);
  el.dataset.state = color;
}

function renderMatrix() {
  const container = document.getElementById("matrix-grid");
  if (!container) return;
  container.innerHTML = "";

  // Header row: bar numbers every 4 bars
  const headerRow = document.createElement("div");
  headerRow.className = "mrow";
  const corner = document.createElement("span");
  corner.className = "mvoice-label";
  headerRow.appendChild(corner);
  const instHead = document.createElement("span");
  instHead.className = "minst-head";
  headerRow.appendChild(instHead);
  const editHead = document.createElement("span");
  editHead.className = "minst-edit-head";
  headerRow.appendChild(editHead);
  for (let bar = 0; bar < MATRIX_BARS; bar++) {
    const num = document.createElement("span");
    num.className = "mbar-num";
    num.textContent = (bar % 4 === 0) ? String(bar + 1) : "";
    headerRow.appendChild(num);
  }
  const modHead = document.createElement("span");
  modHead.className = "mmod-head";
  headerRow.appendChild(modHead);
  container.appendChild(headerRow);

  // Voice rows
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    const row = document.createElement("div");
    row.className = "mrow";
    const label = document.createElement("span");
    label.className = "mvoice-label";
    label.textContent = MATRIX_VOICES[vi];
    row.appendChild(label);
    const inst = document.createElement("select");
    inst.className = "minst";
    inst.dataset.vi = vi;
    [["default","default"]].concat(
      (MATRIX_INST_CHOICES[MATRIX_VOICES[vi]] || []).map(s => [s, s])
    ).forEach(([val, txt]) => {
      const o = document.createElement("option"); o.value = val; o.textContent = txt;
      inst.appendChild(o);
    });
    inst.value = matInst[vi] || "default";
    inst.addEventListener("change", () => {
      matInst[vi] = inst.value; saveMatState();
      send("/matrix/instrument", vi, inst.value);
    });
    row.appendChild(inst);
    const edit = document.createElement("button");
    edit.className = "minst-edit"; edit.textContent = "..."; edit.dataset.vi = vi;
    edit.addEventListener("click", () => openColorDef(vi));
    row.appendChild(edit);
    for (let bar = 0; bar < MATRIX_BARS; bar++) {
      const color = matGrid[vi][bar];
      const cell = document.createElement("button");
      cell.className = "mcell m" + color;
      cell.dataset.vi = vi;
      cell.dataset.bar = bar;
      cell.dataset.state = color;
      if (bar === matPlayhead) cell.classList.add("playing");
      cell.addEventListener("click", () => {
        const cur = +cell.dataset.state;
        const next = (cur + 1) % 7;
        matGrid[vi][bar] = next;
        saveMatState();
        applyMatCellColor(cell, next);
        if (bar === matPlayhead) cell.classList.add("playing");
        send("/matrix/cell", vi, bar, next);
      });
      cell.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        matGrid[vi][bar] = 0; saveMatState();
        applyMatCellColor(cell, 0);
        if (bar === matPlayhead) cell.classList.add("playing");
        send("/matrix/cell", vi, bar, 0);
      });
      cellRefs[bar][vi] = cell;
      row.appendChild(cell);
    }
    const mod = document.createElement("span");
    mod.className = "mmod";
    const src = document.createElement("select"); src.className = "mmod-src"; src.dataset.vi = vi;
    MATRIX_MOD_SOURCES.forEach(s => { const o=document.createElement("option"); o.value=s; o.textContent=s; src.appendChild(o); });
    const tgt = document.createElement("select"); tgt.className = "mmod-tgt"; tgt.dataset.vi = vi;
    (MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]]||["none","amp"]).forEach(t => { const o=document.createElement("option"); o.value=t; o.textContent=t; tgt.appendChild(o); });
    const dep = document.createElement("input"); dep.type="range"; dep.min=0; dep.max=1; dep.step=0.01;
    dep.className = "mmod-dep"; dep.dataset.vi = vi;
    src.value = matMod[vi].source; tgt.value = matMod[vi].target; dep.value = matMod[vi].depth;
    const sendMod = () => { matMod[vi] = {source:src.value, target:tgt.value, depth:+dep.value};
      saveMatState(); send("/matrix/mod", vi, src.value, tgt.value, +dep.value); };
    src.addEventListener("change", sendMod);
    tgt.addEventListener("change", sendMod);
    dep.addEventListener("change", sendMod);
    mod.appendChild(src); mod.appendChild(tgt); mod.appendChild(dep);
    row.appendChild(mod);
    container.appendChild(row);
  }
}

// --- Color def modal ---
function renderColorDefRows(vi) {
  document.getElementById("cd-title").textContent = MATRIX_VOICES[vi];
  const rows = document.getElementById("cd-rows");
  rows.innerHTML = "";
  const targets = MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]] || ["none","amp"];
  const hasCut = targets.includes("cutoff"), hasPan = targets.includes("pan");
  for (let c = 1; c <= 6; c++) {
    const d = matColorDefs[vi][c];
    const r = document.createElement("div"); r.className = "cd-row m" + c;
    const mk = (label, el) => { const w = document.createElement("label");
      w.className = "cd-field"; w.textContent = label; w.appendChild(el); return w; };
    const inst = document.createElement("select"); inst.className = "cd-inst";
    [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
      .forEach(([v,t]) => { const o=document.createElement("option"); o.value=v; o.textContent=t; inst.appendChild(o); });
    inst.value = d.inst || "default";
    inst.addEventListener("change", () => setCD(c, "inst", inst.value));
    const stretch = document.createElement("select"); stretch.className = "cd-str";
    [0.5,1.0,2.0].forEach(v => { const o=document.createElement("option"); o.value=v; o.textContent=v+"x"; stretch.appendChild(o); });
    stretch.value = d.stretch; stretch.addEventListener("change", () => setCD(c, "stretch", +stretch.value));
    const oct = document.createElement("select"); oct.className = "cd-oct";
    [-1,0,1].forEach(v => { const o=document.createElement("option"); o.value=v; o.textContent=v; oct.appendChild(o); });
    oct.value = d.octave; oct.addEventListener("change", () => setCD(c, "octave", +oct.value));
    const amp = document.createElement("input"); amp.type="range"; amp.min=0; amp.max=1.5; amp.step=0.01;
    amp.value = d.amp; amp.addEventListener("change", () => setCD(c, "amp", +amp.value));
    r.appendChild(mk("inst", inst)); r.appendChild(mk("stretch", stretch));
    r.appendChild(mk("oct", oct)); r.appendChild(mk("amp", amp));
    if (hasCut) { const cut = document.createElement("input"); cut.type="range"; cut.min=200; cut.max=6000; cut.step=10;
      cut.value = d.cutoff > 0 ? d.cutoff : 1000; cut.addEventListener("change", () => setCD(c, "cutoff", +cut.value)); r.appendChild(mk("cutoff", cut)); }
    if (hasPan) { const pan = document.createElement("input"); pan.type="range"; pan.min=-1; pan.max=1; pan.step=0.01;
      pan.value = d.pan >= -1 ? d.pan : 0; pan.addEventListener("change", () => setCD(c, "pan", +pan.value)); r.appendChild(mk("pan", pan)); }
    rows.appendChild(r);
  }
}

function openColorDef(vi) {
  cdEditVoice = vi;
  document.getElementById("cd-audition").classList.toggle("on", cdAuditioning);
  renderColorDefRows(vi);
  document.getElementById("colordef-modal").hidden = false;
  send("/matrix/colordefs/get", vi);
}

function setCD(color, field, value) {
  if (cdEditVoice < 0) return;
  matColorDefs[cdEditVoice][color][field] = value;
  saveMatState();
  send("/matrix/colordef", cdEditVoice, color, field, value);
}

function closeColorDef() {
  if (cdAuditioning && cdEditVoice >= 0) { send("/matrix/audition", cdEditVoice, 0); cdAuditioning = false; }
  document.getElementById("cd-audition").classList.remove("on");
  document.getElementById("colordef-modal").hidden = true;
  cdEditVoice = -1;
}

// --- Matrix timeline: 32-bar loop region + playhead ---
function renderTimeline() {
  const tl = document.getElementById("matrix-timeline");
  if (!tl) return;
  tl.innerHTML = "";
  const spacer = document.createElement("span");
  spacer.className = "tl-spacer";
  tl.appendChild(spacer);
  for (let bar = 0; bar < MATRIX_BARS; bar++) {
    const cell = document.createElement("span");
    cell.className = "tl-bar";
    cell.dataset.bar = bar;
    if (bar % 4 === 0) cell.textContent = String(bar + 1);
    if (bar >= matLoopStart && bar <= matLoopEnd) cell.classList.add("in-loop");
    if (bar === matPlayhead) cell.classList.add("tl-head");
    tl.appendChild(cell);
  }
}

function updateTimelineLoop() {
  const tl = document.getElementById("matrix-timeline");
  if (!tl) return;
  tl.querySelectorAll(".tl-bar").forEach((cell) => {
    const b = +cell.dataset.bar;
    cell.classList.toggle("in-loop", b >= matLoopStart && b <= matLoopEnd);
  });
}

function updateTimelineHead(bar) {
  const tl = document.getElementById("matrix-timeline");
  if (!tl) return;
  const prev = tl.querySelector(".tl-head");
  if (prev) prev.classList.remove("tl-head");
  const next = tl.querySelector(`.tl-bar[data-bar="${bar}"]`);
  if (next) next.classList.add("tl-head");
}

function initTimelinePointer() {
  const tl = document.getElementById("matrix-timeline");
  if (!tl) return;
  let dragStart = -1;
  let dragging = false;

  function barFromPoint(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return -1;
    const barEl = el.classList && el.classList.contains("tl-bar")
      ? el
      : (el.closest ? el.closest(".tl-bar") : null);
    if (!barEl) return -1;
    const b = +barEl.dataset.bar;
    return (Number.isFinite(b) && b >= 0 && b < MATRIX_BARS) ? b : -1;
  }

  function previewLoop(start, end) {
    const lo = Math.min(start, end);
    const hi = Math.max(start, end);
    tl.querySelectorAll(".tl-bar").forEach((cell) => {
      const b = +cell.dataset.bar;
      cell.classList.toggle("in-loop", b >= lo && b <= hi);
    });
  }

  tl.addEventListener("pointerdown", (e) => {
    const bar = barFromPoint(e.clientX, e.clientY);
    if (bar < 0) return;
    e.preventDefault();
    tl.setPointerCapture(e.pointerId);
    dragStart = bar;
    dragging = true;
  });

  tl.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    const cur = barFromPoint(e.clientX, e.clientY);
    if (cur >= 0) previewLoop(dragStart, cur);
  });

  tl.addEventListener("pointerup", (e) => {
    if (!dragging) return;
    dragging = false;
    tl.releasePointerCapture(e.pointerId);
    const end = barFromPoint(e.clientX, e.clientY);
    const validEnd = end >= 0 ? end : dragStart;
    if (validEnd === dragStart) {
      send("/matrix/seek", dragStart);
    } else {
      const lo = Math.min(dragStart, validEnd);
      const hi = Math.max(dragStart, validEnd);
      send("/matrix/loop", lo, hi);
    }
    dragStart = -1;
  });

  tl.addEventListener("pointercancel", () => {
    dragging = false;
    dragStart = -1;
    updateTimelineLoop();
  });
}

// --- Matrix mixer: 16-voice per-strip volume + mute ---
const mixerLevel = {};
const mixerMuted = {};
MATRIX_VOICES.forEach(v => { mixerLevel[v] = 0.8; mixerMuted[v] = false; });

function renderMixer() {
  const container = document.getElementById("matrix-mixer");
  if (!container) return;
  container.innerHTML = "";
  MATRIX_VOICES.forEach(voice => {
    const strip = document.createElement("div");
    strip.className = "mix-strip";
    strip.dataset.voice = voice;

    const fader = document.createElement("input");
    fader.type = "range";
    fader.min = "0";
    fader.max = "1.5";
    fader.step = "0.05";
    fader.value = String(mixerLevel[voice]);
    fader.className = "mix-fader";
    fader.dataset.voice = voice;

    const muteBtn = document.createElement("button");
    muteBtn.className = "mix-mute";
    muteBtn.textContent = "M";

    const label = document.createElement("span");
    label.className = "mix-label";
    label.textContent = voice;

    fader.addEventListener("input", () => {
      const v = +fader.value;
      mixerLevel[voice] = v;
      // Moving the fader unmutes + sends immediately
      if (mixerMuted[voice]) {
        mixerMuted[voice] = false;
        strip.classList.remove("muted");
        muteBtn.classList.remove("on");
      }
      send("/launch/vol", voice, v);
    });

    muteBtn.addEventListener("click", () => {
      mixerMuted[voice] = !mixerMuted[voice];
      if (mixerMuted[voice]) {
        muteBtn.classList.add("on");
        strip.classList.add("muted");
        send("/launch/vol", voice, 0);
      } else {
        muteBtn.classList.remove("on");
        strip.classList.remove("muted");
        send("/launch/vol", voice, mixerLevel[voice]);
      }
    });

    strip.appendChild(fader);
    strip.appendChild(muteBtn);
    strip.appendChild(label);
    container.appendChild(strip);
  });
}

// --- Matrix audio-reactive glow (trigger envelope; math in matrix_glow.js) ---
const voiceLevel = new Array(MATRIX_VOICES.length).fill(0);
let glowRaf = null;
let glowLastTs = 0;
let glowAppliedBar = -1;

function clearGlowColumn(bar) {
  if (bar < 0) return;
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    const el = cellRefs[bar][vi];
    if (el) el.style.removeProperty("--glow");
  }
}

function glowFrame(ts) {
  const decay = window.MatrixGlow ? window.MatrixGlow.nextGlow : (l) => 0;
  const dt = glowLastTs ? (ts - glowLastTs) : (1000 / 60);
  glowLastTs = ts;
  if (matPlayhead !== glowAppliedBar) {
    clearGlowColumn(glowAppliedBar);
    glowAppliedBar = matPlayhead;
  }
  let anyActive = false;
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    const lvl = decay(voiceLevel[vi], dt);
    voiceLevel[vi] = lvl;
    if (matPlayhead >= 0) {
      const el = cellRefs[matPlayhead][vi];
      if (el) {
        if (lvl > 0) el.style.setProperty("--glow", lvl.toFixed(3));
        else el.style.removeProperty("--glow");
      }
    }
    if (lvl > 0) anyActive = true;
  }
  if (anyActive) {
    glowRaf = requestAnimationFrame(glowFrame);
  } else {
    clearGlowColumn(glowAppliedBar);
    glowRaf = null;
    glowLastTs = 0;
    glowAppliedBar = -1;
  }
}

function triggerGlow(vi, amp) {
  if (!Number.isInteger(vi) || vi < 0 || vi >= MATRIX_VOICES.length) return;
  const a = Math.max(0, Math.min(1, amp));
  if (a <= 0) return;
  voiceLevel[vi] = Math.max(voiceLevel[vi], a);
  if (glowRaf === null) {
    glowLastTs = 0;
    glowRaf = requestAnimationFrame(glowFrame);
  }
}

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
  loadMatState();

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
  renderMatrix();
  renderTimeline();
  initTimelinePointer();
  renderMixer();

  document.getElementById("cd-close").addEventListener("click", closeColorDef);
  document.getElementById("cd-audition").addEventListener("click", () => {
    if (cdEditVoice < 0) return;
    cdAuditioning = !cdAuditioning;
    send("/matrix/audition", cdEditVoice, cdAuditioning ? 1 : 0);
    document.getElementById("cd-audition").classList.toggle("on", cdAuditioning);
  });

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
    clipState.clear();
    document.querySelectorAll("[data-pad]").forEach((e) => e.classList.remove("armed", "queued"));
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

  // Scene mode toggle buttons
  document.querySelectorAll(".mode-btn").forEach((btn) =>
    btn.addEventListener("click", () => setSceneMode(btn.dataset.mode)));

  // Scene slot buttons
  document.querySelectorAll("[data-scene]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const i = +btn.dataset.scene;
      send("/scene/" + sceneMode, i);
      if (sceneMode === "save" || sceneMode === "clear") {
        setSceneMode("launch");
      }
    }));

  // Scene prev / next
  const scenePrev = document.getElementById("scene-prev");
  if (scenePrev) scenePrev.addEventListener("click", () => send("/scene/prev"));
  const sceneNext = document.getElementById("scene-next");
  if (sceneNext) sceneNext.addEventListener("click", () => send("/scene/next"));

  // Matrix loop full reset
  const matLoopFull = document.getElementById("matrix-loop-full");
  if (matLoopFull) matLoopFull.addEventListener("click", () => send("/matrix/loop", 0, MATRIX_BARS - 1));

  // Matrix transport
  const matPlay = document.getElementById("matrix-play");
  if (matPlay) matPlay.addEventListener("click", () => send("/matrix/play"));
  const matStop = document.getElementById("matrix-stop");
  if (matStop) matStop.addEventListener("click", () => send("/matrix/stop"));
  const matClear = document.getElementById("matrix-clear");
  if (matClear) matClear.addEventListener("click", () => {
    matGrid = Array.from({ length: 16 }, () => new Array(32).fill(0));
    saveMatState();
    renderMatrix();
    send("/matrix/clear");
  });

  document.querySelectorAll(".kit-btn").forEach((b) => {
    b.addEventListener("click", () => send("/matrix/kit", b.dataset.kit));
  });

  // Matrix persistence bar
  const matSave = document.getElementById("matrix-save");
  if (matSave) matSave.addEventListener("click", () => {
    const n = (document.getElementById("matrix-name").value || "").trim();
    if (n) { send("/matrix/save", n); send("/matrix/list"); }
  });
  const matLoad = document.getElementById("matrix-load");
  if (matLoad) matLoad.addEventListener("click", () => {
    const n = document.getElementById("matrix-list").value;
    if (n) send("/matrix/load", n);
  });
  const matRefresh = document.getElementById("matrix-refresh");
  if (matRefresh) matRefresh.addEventListener("click", () => send("/matrix/list"));
});
