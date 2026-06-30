import { send, on, onOpen, onClose } from "./osc.js";
import {
  PALETTE, MATRIX_BARS,
  resetMatGrid, saveMatState, loadMatState,
} from "./matrix-state.js";
import { init as initMixer } from "./mixer.js";
import { init as initTransport } from "./transport.js";
import { init as initScenes } from "./scenes.js";
import { init as initSequencer } from "./sequencer.js";
import { init as initLaunchpad } from "./launchpad.js";
import { init as initGrid, renderMatrix } from "./matrix-grid.js";
import { init as initVoiceEditor } from "./voice-editor.js";
import { init as initMorceauPanel } from "./morceau-panel.js";

function installPaletteVars() {
  const root = document.documentElement.style;
  PALETTE.forEach((c, i) => root.setProperty(`--m${i + 1}`, c));
}

const dot = () => document.getElementById("status");
onOpen(() => { dot().className = "on"; send("/matrix/list"); });
onClose(() => { dot().className = "off"; });

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
  initVoiceEditor();
  initGrid();
  initMorceauPanel();

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

  // Matrix evolve toggle + rate
  const matEvolve = document.getElementById("matrix-evolve");
  const matEvolveRate = document.getElementById("matrix-evolve-rate");
  if (matEvolve) matEvolve.addEventListener("click", () => {
    const isOn = !matEvolve.classList.contains("on");
    send("/matrix/evolve", isOn ? 1 : 0);
  });
  if (matEvolveRate) matEvolveRate.addEventListener("change", () => send("/matrix/evolverate", +matEvolveRate.value));
  on("/matrix/evolve", (args) => {
    const isOn = Math.round(Number(args[0])) === 1;
    const rate = Number(args[1]);
    if (matEvolve) matEvolve.classList.toggle("on", isOn);
    if (matEvolveRate && Number.isFinite(rate)) matEvolveRate.value = rate;
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
  // Queued load: arm the selected preset to swap at the next loop wrap.
  const matLoadNext = document.getElementById("matrix-loadnext");
  if (matLoadNext) matLoadNext.addEventListener("click", () => {
    const n = document.getElementById("matrix-list").value;
    if (n) send("/matrix/loadnext", n);
  });
  on("/matrix/queued", (args) => {
    const name = (args && args[0] != null) ? String(args[0]) : "";
    if (matLoadNext) {
      matLoadNext.classList.toggle("armed", name.length > 0);
      matLoadNext.textContent = name.length > 0 ? "SUIVANT → " + name : "SUIVANT";
    }
  });
  // A loaded matrix fills the name field, so SAUVER updates it in place.
  on("/matrix/loaded", (args) => {
    const name = (args && args[0] != null) ? String(args[0]) : "";
    const nameInput = document.getElementById("matrix-name");
    if (nameInput && name.length > 0) nameInput.value = name;
  });
  const matRefresh = document.getElementById("matrix-refresh");
  if (matRefresh) matRefresh.addEventListener("click", () => send("/matrix/list"));
});
