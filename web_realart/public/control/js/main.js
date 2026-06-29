import { send, on, onOpen, onClose } from "./osc.js";
import {
  PALETTE,
  MATRIX_VOICES, MATRIX_BARS, MATRIX_INST_CHOICES,
  MATRIX_MOD_SOURCES, MATRIX_MOD_TARGETS,
  mkColor, matGrid, matInst, matColorDefs,
  resetMatGrid, saveMatState, loadMatState,
} from "./matrix-state.js";
import { init as initMixer } from "./mixer.js";
import { init as initTransport } from "./transport.js";
import { init as initScenes } from "./scenes.js";
import { init as initSequencer } from "./sequencer.js";
import { init as initLaunchpad } from "./launchpad.js";

function installPaletteVars() {
  const root = document.documentElement.style;
  PALETTE.forEach((c, i) => root.setProperty(`--m${i + 1}`, c));
}

const dot = () => document.getElementById("status");
onOpen(() => { dot().className = "on"; send("/matrix/list"); });
onClose(() => { dot().className = "off"; });

// --- Matrix (22-voice x 64-bar song arranger) ---
// Data layer lives in matrix-state.js — constants/state/save/load imported above.
let cdEditVoice = -1, cdColor = 1, cdAuditioning = false;
// cellRefs[bar][vi] for O(16) playhead column toggle
const cellRefs = Array.from({ length: MATRIX_BARS }, () => new Array(MATRIX_VOICES.length).fill(null));
let matPlayhead = -1;
let matLoopStart = 0;
let matLoopEnd = MATRIX_BARS - 1;

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
  const ih = document.createElement("span");
  ih.className = "minst-head";
  headerRow.appendChild(ih);
  const editHead = document.createElement("span");
  editHead.className = "minst-edit-head";
  headerRow.appendChild(editHead);
  for (let bar = 0; bar < MATRIX_BARS; bar++) {
    const num = document.createElement("span");
    num.className = "mbar-num";
    num.textContent = (bar % 4 === 0) ? String(bar + 1) : "";
    headerRow.appendChild(num);
  }
  container.appendChild(headerRow);

  // Voice rows
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    const row = document.createElement("div");
    row.className = "mrow";
    const label = document.createElement("span");
    label.className = "mvoice-label";
    label.textContent = MATRIX_VOICES[vi];
    row.appendChild(label);
    const vinst = document.createElement("select");
    vinst.className = "minst"; vinst.dataset.vi = vi;
    [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
      .forEach(([val,txt])=>{const o=document.createElement("option");o.value=val;o.textContent=txt;vinst.appendChild(o);});
    vinst.value = matInst[vi] || "default";
    vinst.addEventListener("change", ()=>{ matInst[vi]=vinst.value; saveMatState(); send("/matrix/instrument", vi, vinst.value); });
    row.appendChild(vinst);
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
    container.appendChild(row);
  }
}

// --- Color def modal ---
function renderColorSel(vi) {
  const sel = document.getElementById("cd-colorsel");
  if (!sel) return;
  sel.innerHTML = "";
  for (let c = 1; c <= 6; c++) {
    const btn = document.createElement("button");
    btn.textContent = String(c);
    btn.style.background = PALETTE[c-1];
    btn.style.borderColor = PALETTE[c-1];
    btn.classList.toggle("on", c === cdColor);
    btn.addEventListener("click", () => { cdColor = c; renderColorSel(vi); renderPattern(vi); });
    sel.appendChild(btn);
  }
}

function renderPattern(vi) {
  const p = document.getElementById("cd-pattern");
  if (!p) return;
  p.innerHTML = "";
  const c = cdColor;
  const d = matColorDefs[vi][c];
  if (!d) return;
  if (!d.steps) d.steps = new Array(16).fill(null);
  if (!d.pose) d.pose = [];
  if (d.mod === undefined) d.mod = null;

  const targets = MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]] || ["none","amp"];
  const hasCut = targets.includes("cutoff"), hasPan = targets.includes("pan");
  const mk = (label, el) => { const w = document.createElement("label");
    w.className = "cd-field"; w.textContent = label; w.appendChild(el); return w; };

  // Instrument + variation row
  const varRow = document.createElement("div"); varRow.className = "cd-row m" + c;
  const inst = document.createElement("select");
  [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
    .forEach(([val,txt])=>{ const o=document.createElement("option"); o.value=val; o.textContent=txt; inst.appendChild(o); });
  inst.value = d.inst || "default";
  inst.addEventListener("change", () => setCD(c, "inst", inst.value));
  const stretch = document.createElement("select");
  [0.5,1.0,2.0].forEach(v=>{ const o=document.createElement("option"); o.value=v; o.textContent=v+"x"; stretch.appendChild(o); });
  stretch.value = d.stretch; stretch.addEventListener("change", () => setCD(c, "stretch", +stretch.value));
  const oct = document.createElement("select");
  [-1,0,1].forEach(v=>{ const o=document.createElement("option"); o.value=v; o.textContent=v; oct.appendChild(o); });
  oct.value = d.octave; oct.addEventListener("change", () => setCD(c, "octave", +oct.value));
  const amp = document.createElement("input"); amp.type="range"; amp.min=0; amp.max=1.5; amp.step=0.01;
  amp.value = d.amp; amp.addEventListener("change", () => setCD(c, "amp", +amp.value));
  varRow.appendChild(mk("inst", inst)); varRow.appendChild(mk("stretch", stretch));
  varRow.appendChild(mk("oct", oct)); varRow.appendChild(mk("amp", amp));
  if (hasCut) { const cut = document.createElement("input"); cut.type="range"; cut.min=200; cut.max=6000; cut.step=10;
    cut.value = d.cutoff > 0 ? d.cutoff : 1000;
    cut.addEventListener("change", () => setCD(c, "cutoff", +cut.value)); varRow.appendChild(mk("cutoff", cut)); }
  if (hasPan) { const pan = document.createElement("input"); pan.type="range"; pan.min=-1; pan.max=1; pan.step=0.01;
    pan.value = d.pan >= -1 ? d.pan : 0;
    pan.addEventListener("change", () => setCD(c, "pan", +pan.value)); varRow.appendChild(mk("pan", pan)); }
  p.appendChild(varRow);

  // 16-step row
  const seqRow = document.createElement("div"); seqRow.className = "seq-row m" + c;
  for (let s = 0; s < 16; s++) {
    const cell = document.createElement("button"); cell.className = "seq-cell";
    const st = d.steps[s];
    cell.textContent = st ? st.degree : "";
    if (st) cell.classList.add("on");
    cell.addEventListener("click", () => {
      if (d.steps[s]) { d.steps[s] = null; send("/matrix/step", vi, c, s, -99, 0); }
      else { d.steps[s] = {degree:0, vel:0.8}; send("/matrix/step", vi, c, s, 0, 0.8); }
      saveMatState(); renderPattern(vi);
    });
    cell.addEventListener("wheel", (e) => {
      e.preventDefault(); const st2 = d.steps[s]; if (!st2) return;
      if (e.shiftKey) {
        st2.vel = Math.max(0, Math.min(1, st2.vel + (e.deltaY < 0 ? 0.1 : -0.1)));
      } else {
        st2.degree = Math.max(-48, Math.min(48, st2.degree + (e.deltaY < 0 ? 1 : -1)));
      }
      send("/matrix/step", vi, c, s, st2.degree, st2.vel); saveMatState(); renderPattern(vi);
    });
    seqRow.appendChild(cell);
  }
  p.appendChild(seqRow);

  // Effect (mod) row
  const modDiv = document.createElement("div"); modDiv.className = "cd-row m" + c;
  const src = document.createElement("select");
  MATRIX_MOD_SOURCES.forEach(s=>{ const o=document.createElement("option"); o.value=s; o.textContent=s; src.appendChild(o); });
  const tgt = document.createElement("select");
  targets.forEach(t=>{ const o=document.createElement("option"); o.value=t; o.textContent=t; tgt.appendChild(o); });
  const dep = document.createElement("input"); dep.type="range"; dep.min=0; dep.max=1; dep.step=0.01;
  const mod = d.mod || {source:"none", target:"none", depth:0.5};
  src.value = mod.source; tgt.value = mod.target; dep.value = mod.depth;
  const sendMod = () => {
    matColorDefs[vi][c].mod = {source:src.value, target:tgt.value, depth:+dep.value};
    saveMatState(); send("/matrix/colormod", vi, c, src.value, tgt.value, +dep.value);
  };
  src.addEventListener("change", sendMod); tgt.addEventListener("change", sendMod); dep.addEventListener("change", sendMod);
  modDiv.appendChild(mk("src", src)); modDiv.appendChild(mk("tgt", tgt)); modDiv.appendChild(mk("depth", dep));
  p.appendChild(modDiv);

  // Pose section
  const poseDiv = document.createElement("div");
  const addDiv = document.createElement("div");
  const poseId = document.createElement("input"); poseId.placeholder = "poseId"; poseId.className = "pose-id";
  const poseAct = document.createElement("select");
  ["trigger","gate"].forEach(a=>{ const o=document.createElement("option"); o.value=a; o.textContent=a; poseAct.appendChild(o); });
  const poseGo = document.createElement("button"); poseGo.textContent = "+";
  poseGo.addEventListener("click", () => {
    if (!poseId.value) return;
    const poses = (d.pose || []).filter(b => b.poseId !== poseId.value);
    poses.push({poseId: poseId.value, action: poseAct.value});
    matColorDefs[vi][c].pose = poses;
    saveMatState(); send("/matrix/colorpose", vi, c, poses.length, ...poses.flatMap(b => [b.poseId, b.action]));
    renderPattern(vi);
  });
  [poseId, poseAct, poseGo].forEach(e => addDiv.appendChild(e));
  poseDiv.appendChild(addDiv);
  (d.pose || []).forEach(b => {
    const line = document.createElement("div");
    line.textContent = `${b.poseId} -> ${b.action}`;
    const del = document.createElement("button"); del.textContent = "x";
    del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    del.addEventListener("click", () => {
      matColorDefs[vi][c].pose = (d.pose || []).filter(pp => pp.poseId !== b.poseId);
      const poses = matColorDefs[vi][c].pose;
      saveMatState(); send("/matrix/colorpose", vi, c, poses.length, ...poses.flatMap(pp => [pp.poseId, pp.action]));
      renderPattern(vi);
    });
    line.appendChild(del); poseDiv.appendChild(line);
  });
  p.appendChild(poseDiv);
}

function openColorDef(vi) {
  cdEditVoice = vi;
  cdColor = 1;
  document.getElementById("cd-title").textContent = MATRIX_VOICES[vi];
  document.getElementById("cd-audition").classList.toggle("on", cdAuditioning);
  renderColorSel(vi);
  renderPattern(vi);
  document.getElementById("colordef-modal").hidden = false;
  send("/matrix/colordefs/get", vi);
  send("/matrix/steps/get", vi);
  send("/matrix/colordefs/get/ext", vi);
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

// --- Matrix timeline: 64-bar loop region + playhead ---
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

// --- Matrix audio-reactive glow ---
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
  const decay = window.MatrixGlow ? window.MatrixGlow.nextGlow : () => 0;
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

// --- Matrix OSC handlers ---
// /matrix/playhead <bar>
on("/matrix/playhead", (args) => {
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
});

// /matrix/loop <start> <end>
on("/matrix/loop", (args) => {
  const s = Math.round(Number(args[0]));
  const e = Math.round(Number(args[1]));
  if (Number.isFinite(s) && Number.isFinite(e) && s >= 0 && e < MATRIX_BARS) {
    matLoopStart = Math.min(s, e);
    matLoopEnd = Math.max(s, e);
    updateTimelineLoop();
  }
});

// /matrix/cell <vi> <bar> <color>
on("/matrix/cell", (args) => {
  const vi = Math.round(Number(args[0]));
  const bar = Math.round(Number(args[1]));
  const color = Math.round(Number(args[2]));
  if (vi < 0 || vi >= MATRIX_VOICES.length || bar < 0 || bar >= MATRIX_BARS || color < 0 || color > 6) return;
  matGrid[vi][bar] = color;
  saveMatState();
  const el = cellRefs[bar][vi];
  if (el) {
    applyMatCellColor(el, color);
    if (bar === matPlayhead) el.classList.add("playing");
  }
});

// /matrix/list <name1> <name2> ...
on("/matrix/list", (args) => {
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
  if (args.map(String).includes(prev)) sel.value = prev;
});

// /matrix/grid <N ints row-major vi*BARS+bar>
on("/matrix/grid", (args) => {
  if (!Array.isArray(args) || args.length < (MATRIX_VOICES.length * MATRIX_BARS)) return;
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    for (let bar = 0; bar < MATRIX_BARS; bar++) {
      const v = Math.round(Number(args[vi * MATRIX_BARS + bar]));
      matGrid[vi][bar] = (Number.isFinite(v) && v >= 0 && v <= 6) ? v : 0;
    }
  }
  saveMatState();
  renderMatrix();
});

// /matrix/trig <vi> <amp>
on("/matrix/trig", (args) => {
  triggerGlow(Math.round(Number(args[0])), Number(args[1]));
});

// /matrix/instrument <vi> <inst>
on("/matrix/instrument", (args) => {
  const vi = Math.round(Number(args[0])); const v = String(args[1] ?? "default");
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matInst[vi] = v; saveMatState();
    const rowSel = document.querySelector(`.minst[data-vi="${vi}"]`);
    if (rowSel) rowSel.value = v;
  }
});

// /matrix/instruments <N strings>
on("/matrix/instruments", (args) => {
  for (let vi = 0; vi < MATRIX_VOICES.length && vi < args.length; vi++) {
    const v = String(args[vi] ?? "default"); matInst[vi] = v;
    const rowSel = document.querySelector(`.minst[data-vi="${vi}"]`);
    if (rowSel) rowSel.value = v;
  }
  saveMatState();
});

on("/matrix/colordefs", (args) => {
  const vi = Math.round(Number(args[0]));
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    for (let c = 1; c <= 6; c++) {
      const b = 1 + (c - 1) * 6;
      const ex = matColorDefs[vi][c] || {};
      matColorDefs[vi][c] = { stretch:Number(args[b]), octave:Math.round(Number(args[b+1])),
        amp:Number(args[b+2]), inst:String(args[b+3] ?? "default"),
        cutoff:Number(args[b+4]), pan:Number(args[b+5]),
        mod:ex.mod ?? null, pose:ex.pose || [], steps:ex.steps || new Array(16).fill(null) };
    }
    saveMatState();
    if (cdEditVoice === vi && !document.getElementById("colordef-modal").hidden) {
      renderColorSel(vi); renderPattern(vi);
    }
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
    if (cdEditVoice===vi && cdColor===c && !document.getElementById("colordef-modal").hidden) renderPattern(vi);
  }
});

on("/matrix/colormod", (args) => {
  const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1]));
  if (vi>=0&&vi<MATRIX_VOICES.length&&c>=1&&c<=6&&matColorDefs[vi][c]) {
    const src=String(args[2]??"none");
    matColorDefs[vi][c].mod = (src==="none") ? null : {source:src, target:String(args[3]??"none"), depth:Number(args[4])||0};
    saveMatState();
    if (cdEditVoice===vi && cdColor===c && !document.getElementById("colordef-modal").hidden) renderPattern(vi);
  }
});

on("/matrix/colorpose", (args) => {
  const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1])), n=Math.round(Number(args[2]));
  if (vi>=0&&vi<MATRIX_VOICES.length&&c>=1&&c<=6&&matColorDefs[vi][c]) {
    matColorDefs[vi][c].pose = [];
    for (let k=0;k<n;k++){ const b=3+k*2; matColorDefs[vi][c].pose.push({poseId:String(args[b]),action:String(args[b+1])}); }
    saveMatState();
    if (cdEditVoice===vi && cdColor===c && !document.getElementById("colordef-modal").hidden) renderPattern(vi);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  installPaletteVars();
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

  // Initialise each concern module
  initMixer();
  initTransport();
  initScenes();
  initSequencer();
  initLaunchpad();

  // Render matrix
  renderMatrix();
  renderTimeline();
  initTimelinePointer();

  document.getElementById("cd-close").addEventListener("click", closeColorDef);
  document.getElementById("cd-audition").addEventListener("click", () => {
    if (cdEditVoice < 0) return;
    cdAuditioning = !cdAuditioning;
    send("/matrix/audition", cdEditVoice, cdAuditioning ? 1 : 0);
    document.getElementById("cd-audition").classList.toggle("on", cdAuditioning);
  });

  // Generic OSC buttons
  document.querySelectorAll("[data-osc]").forEach((el) =>
    el.addEventListener("click", () => {
      const a = el.dataset.arg;
      send(el.dataset.osc, ...(a === undefined ? [] : [isNaN(+a) ? a : +a]));
    }));

  // Vol sliders
  document.querySelectorAll("[data-vol]").forEach((el) =>
    el.addEventListener("input", () => send("/launch/vol", el.dataset.vol, +el.value)));

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
    resetMatGrid();
    saveMatState();
    renderMatrix();
    send("/matrix/clear");
  });

  document.querySelectorAll(".kit-btn").forEach((b) => {
    b.addEventListener("click", () => send("/matrix/kit", b.dataset.kit));
  });

  window.addEventListener("beforeunload", () => {
    if (cdAuditioning && cdEditVoice >= 0) send("/matrix/audition", cdEditVoice, 0);
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
