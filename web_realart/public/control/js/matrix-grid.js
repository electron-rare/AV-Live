import { send, on } from "./osc.js";
import {
  MATRIX_VOICES, MATRIX_BARS, MATRIX_INST_CHOICES,
  matGrid, matInst, saveMatState,
} from "./matrix-state.js";
import { openFor } from "./voice-editor.js";

// cellRefs[bar][vi] for O(1) playhead column toggle
const cellRefs = Array.from({ length: MATRIX_BARS }, () => new Array(MATRIX_VOICES.length).fill(null));
let matPlayhead = -1;
let matLoopStart = 0;
let matLoopEnd = MATRIX_BARS - 1;

function applyMatCellColor(el, color) {
  for (let c = 0; c <= 6; c++) el.classList.remove("m" + c);
  el.classList.add("m" + color);
  el.dataset.state = color;
}

export function renderMatrix() {
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
    edit.addEventListener("click", () => openFor(vi));
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

// --- Timeline ---
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

// --- Audio-reactive glow ---
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

export function triggerGlow(vi, amp) {
  if (!Number.isInteger(vi) || vi < 0 || vi >= MATRIX_VOICES.length) return;
  const a = Math.max(0, Math.min(1, amp));
  if (a <= 0) return;
  voiceLevel[vi] = Math.max(voiceLevel[vi], a);
  if (glowRaf === null) {
    glowLastTs = 0;
    glowRaf = requestAnimationFrame(glowFrame);
  }
}

// --- OSC handlers (registered at module load) ---
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

on("/matrix/loop", (args) => {
  const s = Math.round(Number(args[0]));
  const e = Math.round(Number(args[1]));
  if (Number.isFinite(s) && Number.isFinite(e) && s >= 0 && e < MATRIX_BARS) {
    matLoopStart = Math.min(s, e);
    matLoopEnd = Math.max(s, e);
    updateTimelineLoop();
  }
});

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

on("/matrix/trig", (args) => {
  triggerGlow(Math.round(Number(args[0])), Number(args[1]));
});

on("/matrix/instrument", (args) => {
  const vi = Math.round(Number(args[0])); const v = String(args[1] ?? "default");
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matInst[vi] = v; saveMatState();
    const rowSel = document.querySelector(`.minst[data-vi="${vi}"]`);
    if (rowSel) rowSel.value = v;
  }
});

on("/matrix/instruments", (args) => {
  for (let vi = 0; vi < MATRIX_VOICES.length && vi < args.length; vi++) {
    const v = String(args[vi] ?? "default"); matInst[vi] = v;
    const rowSel = document.querySelector(`.minst[data-vi="${vi}"]`);
    if (rowSel) rowSel.value = v;
  }
  saveMatState();
});

export function init() {
  renderMatrix();
  renderTimeline();
  initTimelinePointer();
}
