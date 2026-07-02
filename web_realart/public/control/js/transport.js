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

  // Tempo: slider + -/+ steppers (1 BPM per click), value label kept in sync
  const tempo = document.getElementById("tempo");
  const tempoVal = document.getElementById("tempo-val");
  const pushTempo = () => {
    if (tempoVal) tempoVal.textContent = tempo.value;
    send("/launch/tempo", +tempo.value);
  };
  tempo && tempo.addEventListener("input", pushTempo);
  const stepTempo = (d) => {
    if (!tempo) return;
    tempo.value = Math.max(+tempo.min, Math.min(+tempo.max, +tempo.value + d));
    pushTempo();
  };
  const tMinus = document.getElementById("tempo-minus");
  const tPlus = document.getElementById("tempo-plus");
  tMinus && tMinus.addEventListener("click", () => stepTempo(-1));
  tPlus && tPlus.addEventListener("click", () => stepTempo(1));

  // Master gain: slider + -/+ steppers (0.05 per click), SC /control/doMaster (0..2)
  const master = document.getElementById("master");
  const masterVal = document.getElementById("master-val");
  const pushMaster = () => {
    if (masterVal) masterVal.textContent = (+master.value).toFixed(2);
    send("/control/doMaster", +master.value);
  };
  master && master.addEventListener("input", pushMaster);
  const stepMaster = (d) => {
    if (!master) return;
    master.value = Math.max(+master.min, Math.min(+master.max, +master.value + d)).toFixed(2);
    pushMaster();
  };
  const mMinus = document.getElementById("master-minus");
  const mPlus = document.getElementById("master-plus");
  mMinus && mMinus.addEventListener("click", () => stepMaster(-0.05));
  mPlus && mPlus.addEventListener("click", () => stepMaster(0.05));

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
