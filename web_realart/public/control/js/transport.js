// js/transport.js — beat/rms feedback + tempo, filter, quantise controls.
import { send, on } from "./osc.js";

let beatFlashTimer = null;

export function init() {
  // /sync/beat — flash beat dot for 80 ms
  on("/sync/beat", () => {
    const beatDot = document.getElementById("beat-dot");
    if (!beatDot) return;
    if (beatFlashTimer !== null) { clearTimeout(beatFlashTimer); beatFlashTimer = null; }
    beatDot.classList.add("flash");
    beatFlashTimer = setTimeout(() => {
      beatDot.classList.remove("flash");
      beatFlashTimer = null;
    }, 80);
  });

  // /sync/rms — drive master VU meter width
  on("/sync/rms", (args) => {
    const raw = Number(args[0]);
    const rms = Number.isFinite(raw) ? Math.max(0, Math.min(1, raw)) : 0;
    const bar = document.getElementById("vu-bar");
    if (bar) bar.style.width = `${rms * 100}%`;
  });

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
}
