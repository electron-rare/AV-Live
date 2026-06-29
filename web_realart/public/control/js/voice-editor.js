import { send, on } from "./osc.js";
import {
  PALETTE,
  MATRIX_VOICES, MATRIX_INST_CHOICES,
  MATRIX_MOD_SOURCES, MATRIX_MOD_TARGETS,
  matColorDefs, saveMatState,
  VOICE_CLASS, defaultStepMode, isMelodic,
  matVoiceMods, matVoicePoses,
  MOD_SOURCE_LABELS, MOD_TARGET_LABELS, POSE_EVENT_CHOICES,
  parseVoiceMod, parseVoicePose, parseModValues,
} from "./matrix-state.js";

// Per-voice step edit mode; initialised from defaultStepMode() on first expand.
const stepMode = {}; // vi -> 'pitch' | 'drum'

let expandedVoice = -1;
let expandedContainer = null;
let expandedBtn = null;
let cdColor = 1;
let cdAuditioning = false;
let cdColorSelEl = null;
let cdPatternEl = null;
let cdAuditionBtn = null;
let cdTabBodyEl = null;
let activeTab = "steps"; // "steps" | "synthfx" | "modpose"

// Returns true when the inline editor is currently open for voice vi.
export function isOpenFor(vi) {
  return expandedVoice === vi;
}

export function collapse() {
  if (cdAuditioning && expandedVoice >= 0) {
    send("/matrix/audition", expandedVoice, 0);
    cdAuditioning = false;
  }
  if (expandedContainer) {
    expandedContainer.innerHTML = "";
    expandedContainer.hidden = true;
  }
  if (expandedBtn) {
    expandedBtn.textContent = "▷";
    expandedBtn.classList.remove("open");
  }
  expandedVoice = -1;
  expandedContainer = null;
  expandedBtn = null;
  cdColorSelEl = null;
  cdPatternEl = null;
  cdAuditionBtn = null;
  cdTabBodyEl = null;
}

export function openFor(vi, containerEl) {
  expandedVoice = vi;
  expandedContainer = containerEl;
  cdColor = 1;
  cdAuditioning = false;
  activeTab = "steps";
  if (stepMode[vi] === undefined) stepMode[vi] = defaultStepMode(MATRIX_VOICES[vi]);

  // Mark the expand toggle button
  const grid = document.getElementById("matrix-grid");
  expandedBtn = grid ? grid.querySelector(`.voice-expand-btn[data-vi="${vi}"]`) : null;
  if (expandedBtn) { expandedBtn.textContent = "▼"; expandedBtn.classList.add("open"); }

  containerEl.innerHTML = "";
  containerEl.hidden = false;

  // Head: voice name + audition button
  const head = document.createElement("div");
  head.className = "cd-head";
  const titleEl = document.createElement("span");
  titleEl.textContent = MATRIX_VOICES[vi];
  head.appendChild(titleEl);
  cdAuditionBtn = document.createElement("button");
  cdAuditionBtn.className = "cd-aud";
  cdAuditionBtn.textContent = "AUDITION";
  cdAuditionBtn.addEventListener("click", () => {
    if (expandedVoice < 0) return;
    cdAuditioning = !cdAuditioning;
    send("/matrix/audition", expandedVoice, cdAuditioning ? 1 : 0);
    cdAuditionBtn.classList.toggle("on", cdAuditioning);
  });
  head.appendChild(cdAuditionBtn);
  containerEl.appendChild(head);

  // Color selector container (above tabs, applies across all tabs)
  cdColorSelEl = document.createElement("div");
  cdColorSelEl.className = "cd-colorsel";
  containerEl.appendChild(cdColorSelEl);

  // Pattern container (holds tab bar + active tab body)
  cdPatternEl = document.createElement("div");
  cdPatternEl.className = "cd-pattern";
  containerEl.appendChild(cdPatternEl);

  renderColorSel(vi);
  renderPattern(vi);

  send("/matrix/colordefs/get", vi);
  send("/matrix/steps/get", vi);
  send("/matrix/voicemod/get", vi);
  send("/matrix/voicepose/get", vi);
}

export function toggle(vi, containerEl) {
  if (expandedVoice === vi) {
    collapse();
    return;
  }
  collapse();
  openFor(vi, containerEl);
}

function setCD(color, field, value) {
  if (expandedVoice < 0) return;
  matColorDefs[expandedVoice][color][field] = value;
  saveMatState();
  send("/matrix/colordef", expandedVoice, color, field, value);
}

// Shared field-wrapper helper used by all tab renderers.
function mk(label, el) {
  const w = document.createElement("label");
  w.className = "cd-field";
  w.textContent = label;
  w.appendChild(el);
  return w;
}

function renderColorSel(vi) {
  if (!cdColorSelEl) return;
  cdColorSelEl.innerHTML = "";
  for (let c = 1; c <= 6; c++) {
    const btn = document.createElement("button");
    btn.textContent = String(c);
    btn.style.background = PALETTE[c-1];
    btn.style.borderColor = PALETTE[c-1];
    btn.classList.toggle("on", c === cdColor);
    btn.addEventListener("click", () => { cdColor = c; renderColorSel(vi); renderPattern(vi); });
    cdColorSelEl.appendChild(btn);
  }
}

// --- Tab renderers ---

// Adaptive step tab: branches on stepMode[vi] ('pitch' | 'drum').
function renderStepsTab(vi) {
  if (!cdTabBodyEl) return;
  const d = matColorDefs[vi][cdColor];
  if (!d) return;

  const voiceName = MATRIX_VOICES[vi];
  const isDrumOnly = VOICE_CLASS[voiceName] === "drum";

  // Mode toggle header — hidden for pure-drum voices (pitch is meaningless).
  if (!isDrumOnly) {
    const hdr = document.createElement("div");
    hdr.className = "steps-mode-hdr";
    ["pitch", "drum"].forEach(mode => {
      const btn = document.createElement("button");
      btn.className = "steps-mode-btn" + (stepMode[vi] === mode ? " active" : "");
      btn.textContent = mode === "pitch" ? "Pitch" : "Drum";
      btn.addEventListener("click", () => {
        if (stepMode[vi] === mode) return;
        stepMode[vi] = mode;
        renderPattern(vi);
      });
      hdr.appendChild(btn);
    });
    cdTabBodyEl.appendChild(hdr);
  }

  if (stepMode[vi] === "pitch") {
    renderPitchRoll(vi, cdColor, cdTabBodyEl);
  } else {
    renderDrumGrid(vi, cdColor, cdTabBodyEl);
  }
}

// Drum mode: 16 pads cycling off -> soft (vel 0.6) -> loud (vel 0.95).
function renderDrumGrid(vi, colour, body) {
  const def = matColorDefs[vi][colour];
  if (!def) return;
  const seqRow = document.createElement("div");
  seqRow.className = "seq-row m" + colour;
  seqRow.style.setProperty("--row-color", PALETTE[colour - 1]);
  for (let s = 0; s < 16; s++) {
    const cell = document.createElement("button");
    cell.className = "seq-cell";
    const st = def.steps[s];
    if (st) cell.classList.add(st.vel >= 0.9 ? "loud" : "soft");
    cell.addEventListener("click", () => {
      const cur = def.steps[s];
      if (!cur) {
        def.steps[s] = { degree: 0, vel: 0.6 };
        send("/matrix/step", vi, colour, s, 0, 0.6);
      } else if (cur.vel < 0.9) {
        def.steps[s] = { degree: 0, vel: 0.95 };
        send("/matrix/step", vi, colour, s, 0, 0.95);
      } else {
        def.steps[s] = null;
        send("/matrix/step", vi, colour, s, -99, 0);
      }
      saveMatState();
      renderPattern(vi);
    });
    cell.addEventListener("wheel", (e) => {
      e.preventDefault();
      const cur = def.steps[s];
      if (!cur) return;
      cur.vel = Math.max(0, Math.min(1, cur.vel + (e.deltaY < 0 ? 0.05 : -0.05)));
      send("/matrix/step", vi, colour, s, 0, cur.vel);
      saveMatState();
      renderPattern(vi);
    });
    seqRow.appendChild(cell);
  }
  body.appendChild(seqRow);
}

// Pitch mode: piano-roll grid (rows=degrees top=high, cols=16 steps).
// One note per step; clicking the active degree clears, another degree moves it.
// Wheel on an active cell adjusts velocity.
function renderPitchRoll(vi, colour, body) {
  const def = matColorDefs[vi][colour];
  if (!def) return;
  const degrees = [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]; // top=high
  const grid = document.createElement("div");
  grid.className = "pianoroll";
  grid.style.setProperty("--pr-color", PALETTE[colour - 1]);
  for (const d of degrees) {
    const rowEl = document.createElement("div");
    rowEl.className = "pr-row";
    for (let s = 0; s < 16; s++) {
      const cell = document.createElement("button");
      cell.className = "pr-cell";
      cell.dataset.step = s;
      const st = def.steps[s];
      if (st && st.degree === d) cell.classList.add("on");
      cell.addEventListener("click", () => {
        const cur = def.steps[s];
        const vel = cur ? cur.vel : 0.8;
        def.steps[s] = (cur && cur.degree === d) ? null : { degree: d, vel };
        saveMatState();
        send("/matrix/step", vi, colour, s, def.steps[s] ? d : -99, vel);
        renderPattern(vi);
      });
      cell.addEventListener("wheel", (e) => {
        e.preventDefault();
        const cur = def.steps[s];
        if (!cur || cur.degree !== d) return;
        cur.vel = Math.max(0, Math.min(1, cur.vel + (e.deltaY < 0 ? 0.05 : -0.05)));
        send("/matrix/step", vi, colour, s, d, cur.vel);
        saveMatState();
      });
      rowEl.appendChild(cell);
    }
    grid.appendChild(rowEl);
  }
  body.appendChild(grid);
}

// Renders the var row (inst/stretch/oct/amp/cutoff/pan) into cdTabBodyEl.
function renderSynthFxTab(vi) {
  if (!cdTabBodyEl) return;
  const c = cdColor;
  const d = matColorDefs[vi][c];
  const targets = MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]] || ["none","amp"];
  const hasCut = targets.includes("cutoff"), hasPan = targets.includes("pan");

  const varRow = document.createElement("div");
  varRow.className = "cd-row m" + c;

  const inst = document.createElement("select");
  [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
    .forEach(([val,txt])=>{ const o=document.createElement("option"); o.value=val; o.textContent=txt; inst.appendChild(o); });
  inst.value = d.inst || "default";
  inst.addEventListener("change", () => setCD(c, "inst", inst.value));

  const stretch = document.createElement("select");
  [0.5,1.0,2.0].forEach(v=>{ const o=document.createElement("option"); o.value=v; o.textContent=v+"x"; stretch.appendChild(o); });
  stretch.value = d.stretch;
  stretch.addEventListener("change", () => setCD(c, "stretch", +stretch.value));

  const oct = document.createElement("select");
  [-1,0,1].forEach(v=>{ const o=document.createElement("option"); o.value=v; o.textContent=v; oct.appendChild(o); });
  oct.value = d.octave;
  oct.addEventListener("change", () => setCD(c, "octave", +oct.value));

  const amp = document.createElement("input");
  amp.type="range"; amp.min=0; amp.max=1.5; amp.step=0.01;
  amp.value = d.amp;
  amp.addEventListener("change", () => setCD(c, "amp", +amp.value));

  varRow.appendChild(mk("inst", inst));
  varRow.appendChild(mk("stretch", stretch));
  varRow.appendChild(mk("oct", oct));
  varRow.appendChild(mk("amp", amp));

  if (hasCut) {
    const cut = document.createElement("input");
    cut.type="range"; cut.min=200; cut.max=6000; cut.step=10;
    cut.value = d.cutoff > 0 ? d.cutoff : 1000;
    cut.addEventListener("change", () => setCD(c, "cutoff", +cut.value));
    varRow.appendChild(mk("cutoff", cut));
  }
  if (isMelodic(MATRIX_VOICES[vi])) {
    const res = document.createElement("input");
    res.type="range"; res.min=0; res.max=1; res.step=0.02;
    res.value = d.res ?? 0.3;
    res.addEventListener("change", () => setCD(c, "res", +res.value));
    varRow.appendChild(mk("res", res));
  }
  if (hasPan) {
    const pan = document.createElement("input");
    pan.type="range"; pan.min=-1; pan.max=1; pan.step=0.01;
    pan.value = d.pan >= -1 ? d.pan : 0;
    pan.addEventListener("change", () => setCD(c, "pan", +pan.value));
    varRow.appendChild(mk("pan", pan));
  }
  const rev = document.createElement("input");
  rev.type="range"; rev.min=0; rev.max=1; rev.step=0.02;
  rev.value = d.rev ?? 0;
  rev.addEventListener("change", () => setCD(c, "rev", +rev.value));
  varRow.appendChild(mk("reverb", rev));
  cdTabBodyEl.appendChild(varRow);
}

// Per-voice MOD (additive free list) + POSE (curated events). Independent of cdColor.
function sendVoiceMod(vi) {
  const list = matVoiceMods[vi] || [];
  send("/matrix/voicemod", vi, list.length,
    ...list.flatMap((b) => [b.source, b.target, +b.depth]));
  saveMatState();
}
function sendVoicePose(vi) {
  const list = matVoicePoses[vi] || [];
  send("/matrix/voicepose", vi, list.length,
    ...list.flatMap((b) => [b.poseId, b.action]));
  saveMatState();
}

// helpers
function firstTarget(targets) { return targets.find((t) => t !== "none") || "amp"; }
function MOD_SOURCE_ORDER_FIRST() { return "bodyVitesse"; }

function renderModPoseTab(vi) {
  if (!cdTabBodyEl) return;
  const voice = MATRIX_VOICES[vi];
  const targets = MATRIX_MOD_TARGETS[voice] || ["none", "amp"];

  // --- MOD: additive list ---
  const modWrap = document.createElement("div");
  modWrap.className = "cd-modlist";
  (matVoiceMods[vi] || []).forEach((b, i) => {
    const row = document.createElement("div");
    row.className = "cd-row";
    const src = document.createElement("select");
    MATRIX_MOD_SOURCES.forEach((s) => { const o = document.createElement("option");
      o.value = s; o.textContent = MOD_SOURCE_LABELS[s] || s; src.appendChild(o); });
    src.value = b.source;
    const tgt = document.createElement("select");
    targets.forEach((t) => { const o = document.createElement("option");
      o.value = t; o.textContent = MOD_TARGET_LABELS[t] || t; tgt.appendChild(o); });
    tgt.value = b.target;
    const dep = document.createElement("input");
    dep.type = "range"; dep.min = 0; dep.max = 1; dep.step = 0.01; dep.value = b.depth;
    const meter = document.createElement("span");
    meter.className = "cd-meter"; meter.dataset.src = b.source;
    const del = document.createElement("button");
    del.textContent = "x"; del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    const apply = () => { b.source = src.value; b.target = tgt.value; b.depth = +dep.value;
      meter.dataset.src = b.source; sendVoiceMod(vi); };
    src.addEventListener("change", apply);
    tgt.addEventListener("change", apply);
    dep.addEventListener("change", apply);
    del.addEventListener("click", () => { matVoiceMods[vi].splice(i, 1); sendVoiceMod(vi); renderPattern(vi); });
    [mk("src", src), mk("cible", tgt), mk("depth", dep), meter, del].forEach((e) => row.appendChild(e));
    modWrap.appendChild(row);
  });
  const addMod = document.createElement("button");
  addMod.textContent = "+ modulation";
  addMod.addEventListener("click", () => {
    (matVoiceMods[vi] ||= []).push({ source: MOD_SOURCE_ORDER_FIRST(), target: firstTarget(targets), depth: 0.5 });
    sendVoiceMod(vi); renderPattern(vi);
  });
  modWrap.appendChild(addMod);
  cdTabBodyEl.appendChild(modWrap);

  // --- POSE: curated events ---
  const poseWrap = document.createElement("div");
  poseWrap.className = "cd-poselist";
  (matVoicePoses[vi] || []).forEach((b, i) => {
    const row = document.createElement("div");
    row.className = "cd-row";
    const ev = document.createElement("select");
    POSE_EVENT_CHOICES.forEach((c) => { const o = document.createElement("option");
      o.value = c.id; o.textContent = c.label; ev.appendChild(o); });
    const custom = document.createElement("input");
    custom.placeholder = "poseId"; custom.className = "pose-id";
    const known = POSE_EVENT_CHOICES.some((c) => c.id === b.poseId);
    ev.value = known ? b.poseId : "__custom__";
    custom.value = known ? "" : b.poseId;
    custom.hidden = ev.value !== "__custom__";
    const act = document.createElement("select");
    ["trigger", "gate"].forEach((a) => { const o = document.createElement("option");
      o.value = a; o.textContent = a; act.appendChild(o); });
    act.value = b.action;
    const del = document.createElement("button");
    del.textContent = "x"; del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    const apply = () => {
      custom.hidden = ev.value !== "__custom__";
      b.poseId = ev.value === "__custom__" ? (custom.value || "none") : ev.value;
      b.action = act.value; sendVoicePose(vi);
    };
    ev.addEventListener("change", apply);
    custom.addEventListener("change", apply);
    act.addEventListener("change", apply);
    del.addEventListener("click", () => { matVoicePoses[vi].splice(i, 1); sendVoicePose(vi); renderPattern(vi); });
    [mk("event", ev), custom, mk("action", act), del].forEach((e) => row.appendChild(e));
    poseWrap.appendChild(row);
  });
  const addPose = document.createElement("button");
  addPose.textContent = "+ pose";
  addPose.addEventListener("click", () => {
    (matVoicePoses[vi] ||= []).push({ poseId: "danse", action: "trigger" });
    sendVoicePose(vi); renderPattern(vi);
  });
  poseWrap.appendChild(addPose);
  cdTabBodyEl.appendChild(poseWrap);
}

// Renders the tab bar into cdPatternEl.
function renderTabBar(vi) {
  if (!cdPatternEl) return;
  const bar = document.createElement("div");
  bar.className = "tab-bar";
  [
    { id: "steps",   label: "STEPS"    },
    { id: "synthfx", label: "SYNTH/FX" },
    { id: "modpose", label: "MOD/POSE" },
  ].forEach(({ id, label }) => {
    const btn = document.createElement("button");
    btn.className = "tab-btn" + (activeTab === id ? " active" : "");
    btn.textContent = label;
    btn.addEventListener("click", () => { activeTab = id; renderPattern(vi); });
    bar.appendChild(btn);
  });
  cdPatternEl.appendChild(bar);
}

// Renders tab bar + active tab body into cdPatternEl.
function renderPattern(vi) {
  if (!cdPatternEl) return;
  cdPatternEl.innerHTML = "";
  cdTabBodyEl = null;
  const c = cdColor;
  const d = matColorDefs[vi][c];
  if (!d) return;
  if (!d.steps) d.steps = new Array(16).fill(null);
  if (!d.pose) d.pose = [];
  if (d.mod === undefined) d.mod = null;

  renderTabBar(vi);

  const tabBody = document.createElement("div");
  tabBody.className = "cd-tab-body";
  cdPatternEl.appendChild(tabBody);
  cdTabBodyEl = tabBody;

  if (activeTab === "steps") renderStepsTab(vi);
  else if (activeTab === "synthfx") renderSynthFxTab(vi);
  else renderModPoseTab(vi);
}

// --- OSC handlers ---

// Pure parse function for stride-8 /matrix/colordefs flat args.
// SC field order per colour: stretch, octave, amp, inst(str),
//   cutoff(-1=nil), pan(-2=nil), res(-3=nil), rev(-4=nil).
// Returns { vi, colors: { 1..6 -> plain field object (no steps/mod/pose) } }.
export function parseColorDefs(args) {
  const vi = Math.round(Number(args[0]));
  const colors = {};
  for (let c = 1; c <= 6; c++) {
    const b = 1 + (c - 1) * 8;
    const cutoffRaw = Number(args[b + 4]);
    const panRaw    = Number(args[b + 5]);
    const resRaw    = Number(args[b + 6]);
    const revRaw    = Number(args[b + 7]);
    colors[c] = {
      stretch: Number(args[b]),
      octave:  Math.round(Number(args[b + 1])),
      amp:     Number(args[b + 2]),
      inst:    String(args[b + 3] ?? "default"),
      cutoff:  cutoffRaw === -1 ? null : cutoffRaw,
      pan:     panRaw    === -2 ? null : panRaw,
      res:     resRaw    === -3 ? null : resRaw,
      rev:     revRaw    === -4 ? null : revRaw,
    };
  }
  return { vi, colors };
}

on("/matrix/colordefs", (args) => {
  const { vi, colors } = parseColorDefs(args);
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    for (let c = 1; c <= 6; c++) {
      const ex = matColorDefs[vi][c] || {};
      matColorDefs[vi][c] = { ...colors[c],
        mod:ex.mod ?? null, pose:ex.pose || [], steps:ex.steps || new Array(16).fill(null) };
    }
    saveMatState();
    if (isOpenFor(vi)) { renderColorSel(vi); renderPattern(vi); }
  }
});

on("/matrix/steps", (args) => {
  const vi = Math.round(Number(args[0])), c = Math.round(Number(args[1]));
  if (vi>=0 && vi<MATRIX_VOICES.length && c>=1 && c<=6 && matColorDefs[vi][c]) {
    if (!matColorDefs[vi][c].steps) matColorDefs[vi][c].steps = new Array(16).fill(null);
    for (let s=0; s<16; s++) {
      const deg = Number(args[2 + s*2]), vel = Number(args[3 + s*2]);
      matColorDefs[vi][c].steps[s] = (deg === -99) ? null : {degree:deg, vel:vel};
    }
    saveMatState();
    if (isOpenFor(vi) && cdColor === c) renderPattern(vi);
  }
});

on("/matrix/colormod", (args) => {
  const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1]));
  if (vi>=0&&vi<MATRIX_VOICES.length&&c>=1&&c<=6&&matColorDefs[vi][c]) {
    const src=String(args[2]??"none");
    matColorDefs[vi][c].mod = (src==="none") ? null : {source:src, target:String(args[3]??"none"), depth:Number(args[4])||0};
    saveMatState();
    if (isOpenFor(vi) && cdColor === c) renderPattern(vi);
  }
});

on("/matrix/colorpose", (args) => {
  const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1])), n=Math.round(Number(args[2]));
  if (vi>=0&&vi<MATRIX_VOICES.length&&c>=1&&c<=6&&matColorDefs[vi][c]) {
    matColorDefs[vi][c].pose = [];
    for (let k=0;k<n;k++){ const b=3+k*2; matColorDefs[vi][c].pose.push({poseId:String(args[b]),action:String(args[b+1])}); }
    saveMatState();
    if (isOpenFor(vi) && cdColor === c) renderPattern(vi);
  }
});

on("/matrix/voicemod", (args) => {
  const { vi, list } = parseVoiceMod(args);
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matVoiceMods[vi] = list; saveMatState();
    if (isOpenFor(vi)) renderPattern(vi);
  }
});

on("/matrix/voicepose", (args) => {
  const { vi, list } = parseVoicePose(args);
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matVoicePoses[vi] = list; saveMatState();
    if (isOpenFor(vi)) renderPattern(vi);
  }
});

let latestModValues = {};
on("/matrix/modvalues", (args) => {
  latestModValues = parseModValues(args);
  updateMeters();
});
function updateMeters() {
  if (expandedVoice < 0 || activeTab !== "modpose") return;
  const meters = cdTabBodyEl ? cdTabBodyEl.querySelectorAll(".cd-meter") : [];
  meters.forEach((m) => {
    const v = latestModValues[m.dataset.src] || 0;
    m.style.setProperty("--v", v.toFixed(3));
    m.title = `${m.dataset.src}: ${v.toFixed(2)}`;
  });
}

on("/matrix/stephead", (args) => {
  // Guard: only act when a voice is open and the STEPS tab is active.
  if (expandedVoice < 0 || !cdTabBodyEl || activeTab !== "steps") return;
  const s = Math.round(Number(args[0]));
  if (s < 0 || s > 15) return;
  // Drum mode: highlight the seq-cell at index s.
  const seqCells = cdTabBodyEl.querySelectorAll(".seq-cell");
  seqCells.forEach((c, i) => c.classList.toggle("playhead", i === s));
  // Piano-roll mode: highlight all pr-cells in column s.
  const prCells = cdTabBodyEl.querySelectorAll(".pr-cell");
  prCells.forEach((c) => c.classList.toggle("playhead", Number(c.dataset.step) === s));
});

export function init() {
  window.addEventListener("beforeunload", () => {
    if (cdAuditioning && expandedVoice >= 0) send("/matrix/audition", expandedVoice, 0);
  });
}
