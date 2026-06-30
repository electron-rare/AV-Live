// morceau-panel.js — bottom-of-editor panel for matrix-wide ("morceau") actions.
// Phase 1: the 4 hand-gesture slots -> global action. DOM-only; state in
// matrix-state.js, transport over osc.js. Later phases add settings + global controls.
import { send, on, onOpen } from "./osc.js";
import {
  GLOBAL_ACTION_CHOICES, GLOBAL_SLOTS, matGlobalActions,
  setGlobalAction, saveMatState,
} from "./matrix-state.js";

export function init() {
  const host = document.getElementById("morceau-slots");
  if (!host) return;
  const selects = [];
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
    host.appendChild(wrap);
  });
  on("/matrix/globalaction", (args) => {
    const slot = Math.round(Number(args[0]));
    const id = String(args[1] || "none");
    if (slot >= 0 && slot < 4 && selects[slot]) {
      selects[slot].value = id;
      setGlobalAction(slot, id);
      saveMatState();
    }
  });
  onOpen(() => send("/matrix/globalaction/get"));
  send("/matrix/globalaction/get");
}
