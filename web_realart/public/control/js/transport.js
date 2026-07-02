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

  // Tempo / Master: sliders + -/+ steppers, duplicated on the LIVE and
  // MATRICE tabs — every group member drives the same OSC address and all
  // members stay visually in sync.
  const bindStepGroup = (groups, step, fmt, addr) => {
    const push = (v) => {
      groups.forEach((g) => {
        const s = document.getElementById(g.slider);
        const l = document.getElementById(g.val);
        if (s) s.value = v;
        if (l) l.textContent = fmt(v);
      });
      send(addr, +v);
    };
    groups.forEach((g) => {
      const s = document.getElementById(g.slider);
      const clamp = (v) => Math.max(+s.min, Math.min(+s.max, v));
      const m = document.getElementById(g.minus);
      const p = document.getElementById(g.plus);
      s && s.addEventListener("input", () => push(+s.value));
      s && m && m.addEventListener("click", () => push(clamp(+s.value - step)));
      s && p && p.addEventListener("click", () => push(clamp(+s.value + step)));
    });
  };
  bindStepGroup([
    { slider: "tempo", minus: "tempo-minus", plus: "tempo-plus", val: "tempo-val" },
    { slider: "matrix-tempo", minus: "matrix-tempo-minus", plus: "matrix-tempo-plus", val: "matrix-tempo-val" },
  ], 1, (v) => String(Math.round(v)), "/launch/tempo");
  bindStepGroup([
    { slider: "master", minus: "master-minus", plus: "master-plus", val: "master-val" },
    { slider: "matrix-master", minus: "matrix-master-minus", plus: "matrix-master-plus", val: "matrix-master-val" },
  ], 0.05, (v) => (+v).toFixed(2), "/control/doMaster");

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
