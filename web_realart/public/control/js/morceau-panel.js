// morceau-panel.js — bottom-of-editor panel for matrix-wide ("morceau") actions.
// Phase 1: the 4 hand-gesture slots -> global action. DOM-only; state in
// matrix-state.js, transport over osc.js. Later phases add settings + global controls.
import { send, on, onOpen } from "./osc.js";
import {
  GLOBAL_ACTION_CHOICES, GLOBAL_SLOTS, matGlobalActions, setGlobalAction, saveMatState,
  matGlobalSettings, setGlobalSetting, parseGlobalSettings,
  matPinchHoldMs, setPinchHoldMs,
} from "./matrix-state.js";
import { MATRIX_VOICES } from "./matrix-state.js";

export function init() {
  const host = document.getElementById("morceau-slots");
  if (!host) return;
  const selects = [];
  const fills = [];
  GLOBAL_SLOTS.forEach((slot) => {
    const wrap = document.createElement("label");
    wrap.className = "morceau-slot";
    wrap.append(slot.label + " ");
    const sel = document.createElement("select");
    GLOBAL_ACTION_CHOICES.forEach((c) => {
      const o = document.createElement("option");
      o.value = c.id; o.textContent = c.label;
      sel.appendChild(o);
    });
    sel.value = matGlobalActions[slot.key] || "none";
    sel.addEventListener("change", () => {
      setGlobalAction(slot.key, sel.value);
      send("/matrix/globalaction", slot.key, sel.value);
      saveMatState();
    });
    selects[slot.key] = sel;
    wrap.appendChild(sel);
    const fill = document.createElement("div");
    fill.className = "morceau-slot-fill";
    wrap.appendChild(fill);
    fills[slot.key] = fill;
    host.appendChild(wrap);
  });
  on("/matrix/pinchprogress", (args) => {
    const slot = Math.round(Number(args[0]));
    const prog = Number(args[1]) || 0;
    const f = fills[slot];
    if (!f) return;
    f.style.width = (prog * 100) + "%";
    f.classList.toggle("fired", prog >= 1);
  });
  // --- Réglages: thresholds, transient duration, breakdown kept-voices ---
  const sHost = document.getElementById("morceau-settings");
  if (sHost) {
    const sendSettings = () => {
      const s = matGlobalSettings;
      send("/matrix/globalsettings", s.transientBars, s.breakdownKeep.length, ...s.breakdownKeep);
      saveMatState();
    };
    const slider = (key, label, min, max, step) => {
      const row = document.createElement("label");
      row.className = "morceau-set-row";
      const span = document.createElement("span"); span.textContent = label;
      const inp = document.createElement("input");
      inp.type = "range"; inp.min = min; inp.max = max; inp.step = step;
      inp.value = matGlobalSettings[key];
      const out = document.createElement("output"); out.textContent = matGlobalSettings[key];
      inp.addEventListener("input", () => { out.textContent = inp.value; });
      inp.addEventListener("change", () => {
        setGlobalSetting(key, key === "transientBars" ? Math.round(+inp.value) : +inp.value);
        sendSettings();
      });
      row.append(span, inp, out);
      sHost.appendChild(row);
      return { inp, out };
    };
    const ctl = {
      transientBars: slider("transientBars", "Durée (mesures)", 1, 8, 1),
    };
    const holdRow = document.createElement("label");
    holdRow.className = "morceau-set-row";
    const hSpan = document.createElement("span"); hSpan.textContent = "Maintien pince (ms)";
    const hInp = document.createElement("input");
    hInp.type = "range"; hInp.min = 50; hInp.max = 2000; hInp.step = 10; hInp.value = matPinchHoldMs;
    const hOut = document.createElement("output"); hOut.textContent = matPinchHoldMs;
    hInp.addEventListener("input", () => { hOut.textContent = hInp.value; });
    hInp.addEventListener("change", () => { setPinchHoldMs(+hInp.value); send("/matrix/pinchhold", +hInp.value); saveMatState(); });
    holdRow.append(hSpan, hInp, hOut);
    sHost.appendChild(holdRow);
    on("/matrix/pinchhold", (args) => {
      const v = Math.round(Number(args[0]));
      if (Number.isFinite(v)) { hInp.value = v; hOut.textContent = v; setPinchHoldMs(v); saveMatState(); }
    });
    onOpen(() => send("/matrix/pinchhold/get"));
    send("/matrix/pinchhold/get");
    const keepWrap = document.createElement("div");
    keepWrap.className = "morceau-keep";
    const keepTitle = document.createElement("span");
    keepTitle.textContent = "Voix gardées (breakdown)";
    keepWrap.appendChild(keepTitle);
    const keepBoxes = {};
    MATRIX_VOICES.forEach((v) => {
      const lab = document.createElement("label"); lab.className = "morceau-keep-box";
      const cb = document.createElement("input"); cb.type = "checkbox"; cb.value = v;
      cb.checked = matGlobalSettings.breakdownKeep.includes(v);
      cb.addEventListener("change", () => {
        const keep = MATRIX_VOICES.filter((x) => keepBoxes[x].checked);
        setGlobalSetting("breakdownKeep", keep);
        sendSettings();
      });
      keepBoxes[v] = cb;
      lab.append(cb, document.createTextNode(v));
      keepWrap.appendChild(lab);
    });
    sHost.appendChild(keepWrap);
    on("/matrix/globalsettings", (args) => {
      const s = parseGlobalSettings(args);
      setGlobalSetting("transientBars", s.transientBars);
      setGlobalSetting("breakdownKeep", s.breakdownKeep);
      ctl.transientBars.inp.value = s.transientBars; ctl.transientBars.out.textContent = s.transientBars;
      MATRIX_VOICES.forEach((v) => { keepBoxes[v].checked = s.breakdownKeep.includes(v); });
      saveMatState();
    });
    onOpen(() => send("/matrix/globalsettings/get"));
    send("/matrix/globalsettings/get");
  }
  const bpm = document.getElementById("matrix-bpm");
  const bpmOut = document.getElementById("matrix-bpm-out");
  if (bpm) {
    bpm.addEventListener("input", () => { if (bpmOut) bpmOut.textContent = bpm.value; });
    bpm.addEventListener("change", () => send("/matrix/bpm", +bpm.value));
    on("/matrix/bpm", (args) => {
      const v = Math.round(Number(args[0]));
      if (Number.isFinite(v)) { bpm.value = v; if (bpmOut) bpmOut.textContent = v; }
    });
    onOpen(() => send("/matrix/bpm/get"));
    send("/matrix/bpm/get");
  }
  on("/matrix/globalaction", (args) => {
    const slot = Math.round(Number(args[0]));
    const id = String(args[1] || "none");
    if (slot >= 0 && slot < 8 && selects[slot]) {
      selects[slot].value = id;
      setGlobalAction(slot, id);
      saveMatState();
    }
  });
  onOpen(() => send("/matrix/globalaction/get"));
  send("/matrix/globalaction/get");
}
