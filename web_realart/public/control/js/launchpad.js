// js/launchpad.js — clip pad arming, state feedback, and clear.
import { send, onPrefix } from "./osc.js";

const armed = new Set();
const clipState = new Map(); // name -> state int: 0 off, 1 playing, 2 queued-launch, 3 queued-stop

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

export function init() {
  // /armed/<name> — engine is source of truth; args[0] is a state int 0-3
  // 0 = off, 1 = playing (solid), 2 = queued-launch (blink), 3 = queued-stop (blink)
  onPrefix("/armed/", (address, args) => {
    const name = address.slice(7); // strip "/armed/"
    const st = Number(args[0]);
    clipState.set(name, st);
    if (st >= 1) armed.add(name); else armed.delete(name);
    document.querySelectorAll(`[data-pad="${name}"]`).forEach((btn) => {
      btn.classList.toggle("armed", st >= 1);
      btn.classList.toggle("queued", st === 2 || st === 3);
    });
  });

  // Pad arm buttons
  document.querySelectorAll("[data-pad]").forEach((el) =>
    el.addEventListener("click", () => togglePad(el, el.dataset.pad)));

  // Clear
  document.getElementById("clear").addEventListener("click", () => {
    armed.clear();
    clipState.clear();
    document.querySelectorAll("[data-pad]").forEach((e) => e.classList.remove("armed", "queued"));
    send("/launch/clear");
  });
}
