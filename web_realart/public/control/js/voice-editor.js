import { send, on } from "./osc.js";
import {
  PALETTE,
  MATRIX_VOICES, MATRIX_INST_CHOICES,
  MATRIX_MOD_SOURCES, MATRIX_MOD_TARGETS,
  matColorDefs, saveMatState,
} from "./matrix-state.js";

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
  send("/matrix/colordefs/get/ext", vi);
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

// Renders the 16-step sub-editor into cdTabBodyEl.
function renderStepsTab(vi) {
  if (!cdTabBodyEl) return;
  const c = cdColor;
  const d = matColorDefs[vi][c];
  const seqRow = document.createElement("div");
  seqRow.className = "seq-row m" + c;
  for (let s = 0; s < 16; s++) {
    const cell = document.createElement("button");
    cell.className = "seq-cell";
    const st = d.steps[s];
    cell.textContent = st ? st.degree : "";
    if (st) cell.classList.add("on");
    cell.addEventListener("click", () => {
      if (d.steps[s]) { d.steps[s] = null; send("/matrix/step", vi, c, s, -99, 0); }
      else { d.steps[s] = {degree:0, vel:0.8}; send("/matrix/step", vi, c, s, 0, 0.8); }
      saveMatState(); renderPattern(vi);
    });
    cell.addEventListener("wheel", (e) => {
      e.preventDefault();
      const st2 = d.steps[s];
      if (!st2) return;
      if (e.shiftKey) {
        st2.vel = Math.max(0, Math.min(1, st2.vel + (e.deltaY < 0 ? 0.1 : -0.1)));
      } else {
        st2.degree = Math.max(-48, Math.min(48, st2.degree + (e.deltaY < 0 ? 1 : -1)));
      }
      send("/matrix/step", vi, c, s, st2.degree, st2.vel);
      saveMatState();
      renderPattern(vi);
    });
    seqRow.appendChild(cell);
  }
  cdTabBodyEl.appendChild(seqRow);
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
  if (hasPan) {
    const pan = document.createElement("input");
    pan.type="range"; pan.min=-1; pan.max=1; pan.step=0.01;
    pan.value = d.pan >= -1 ? d.pan : 0;
    pan.addEventListener("change", () => setCD(c, "pan", +pan.value));
    varRow.appendChild(mk("pan", pan));
  }
  cdTabBodyEl.appendChild(varRow);
}

// Renders mod row + pose section into cdTabBodyEl.
function renderModPoseTab(vi) {
  if (!cdTabBodyEl) return;
  const c = cdColor;
  const d = matColorDefs[vi][c];
  const targets = MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]] || ["none","amp"];

  // Mod row
  const modDiv = document.createElement("div");
  modDiv.className = "cd-row m" + c;
  const src = document.createElement("select");
  MATRIX_MOD_SOURCES.forEach(s=>{ const o=document.createElement("option"); o.value=s; o.textContent=s; src.appendChild(o); });
  const tgt = document.createElement("select");
  targets.forEach(t=>{ const o=document.createElement("option"); o.value=t; o.textContent=t; tgt.appendChild(o); });
  const dep = document.createElement("input");
  dep.type="range"; dep.min=0; dep.max=1; dep.step=0.01;
  const mod = d.mod || {source:"none", target:"none", depth:0.5};
  src.value = mod.source; tgt.value = mod.target; dep.value = mod.depth;
  const sendMod = () => {
    matColorDefs[vi][c].mod = {source:src.value, target:tgt.value, depth:+dep.value};
    saveMatState();
    send("/matrix/colormod", vi, c, src.value, tgt.value, +dep.value);
  };
  src.addEventListener("change", sendMod);
  tgt.addEventListener("change", sendMod);
  dep.addEventListener("change", sendMod);
  modDiv.appendChild(mk("src", src));
  modDiv.appendChild(mk("tgt", tgt));
  modDiv.appendChild(mk("depth", dep));
  cdTabBodyEl.appendChild(modDiv);

  // Pose section
  const poseDiv = document.createElement("div");
  const addDiv = document.createElement("div");
  const poseId = document.createElement("input");
  poseId.placeholder = "poseId";
  poseId.className = "pose-id";
  const poseAct = document.createElement("select");
  ["trigger","gate"].forEach(a=>{ const o=document.createElement("option"); o.value=a; o.textContent=a; poseAct.appendChild(o); });
  const poseGo = document.createElement("button");
  poseGo.textContent = "+";
  poseGo.addEventListener("click", () => {
    if (!poseId.value) return;
    const poses = (d.pose || []).filter(b => b.poseId !== poseId.value);
    poses.push({poseId: poseId.value, action: poseAct.value});
    matColorDefs[vi][c].pose = poses;
    saveMatState();
    send("/matrix/colorpose", vi, c, poses.length, ...poses.flatMap(b => [b.poseId, b.action]));
    renderPattern(vi);
  });
  [poseId, poseAct, poseGo].forEach(e => addDiv.appendChild(e));
  poseDiv.appendChild(addDiv);
  (d.pose || []).forEach(b => {
    const line = document.createElement("div");
    line.textContent = `${b.poseId} -> ${b.action}`;
    const del = document.createElement("button");
    del.textContent = "x";
    del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    del.addEventListener("click", () => {
      matColorDefs[vi][c].pose = (d.pose || []).filter(pp => pp.poseId !== b.poseId);
      const poses = matColorDefs[vi][c].pose;
      saveMatState();
      send("/matrix/colorpose", vi, c, poses.length, ...poses.flatMap(pp => [pp.poseId, pp.action]));
      renderPattern(vi);
    });
    line.appendChild(del);
    poseDiv.appendChild(line);
  });
  cdTabBodyEl.appendChild(poseDiv);
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

export function init() {
  window.addEventListener("beforeunload", () => {
    if (cdAuditioning && expandedVoice >= 0) send("/matrix/audition", expandedVoice, 0);
  });
}
