// =====================================================================
//  hydra/app.js  --  Patches Hydra data-driven (real.art version).
//
//  Reuse les memes 7 patches que sound_algo/web/public/hydra (presets
//  feeds_*) mais sans dependances aux /sync/* SC. Tout vient de
//  window.feeds + window.f via /feeds_client.js.
// =====================================================================

const canvas = document.getElementById("hydra-canvas");
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
window.addEventListener("resize", () => {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
});
new Hydra({ canvas, detectAudio: false, makeGlobal: true });

const PRESETS = {
    aurora: () => {
        osc(() => 6 + window.f.wind01() * 18, 0.05, () => 1 + window.f.kp01())
          .modulate(noise(() => 2 + window.f.kp01() * 6, 0.1)
                    .scrollY(() => time * 0.05))
          .rotate(() => window.f.bz() * 0.03)
          .color(() => 0.2 + window.f.kp01() * 0.4,
                 () => 0.6 + window.f.wind01() * 0.4,
                 () => 0.4 + window.f.flarePulse())
          .scale(() => 1 + window.f.flarePulse() * 0.6)
          .out();
    },
    quake: () => {
        shape(() => 4 + Math.floor(window.feeds.usgs.last_mag), 0.05, 0.02)
          .repeat(8, 8)
          .scale(() => 0.5 + window.f.quakePulse() * 2.5)
          .modulateRotate(noise(2, 0.2), () => window.f.quakePulse() * 3)
          .color(() => 0.8 + window.f.quakePulse(),
                 () => 0.2 - window.f.quakePulse() * 0.2, 0.1)
          .add(osc(20, 0.05, 1).pixelate(8, 8), () => window.f.quakePulse() * 0.4)
          .out();
    },
    lightning: () => {
        voronoi(() => 8 + window.f.lightRate01() * 30, 0.3, 0.1)
          .modulate(noise(6, 0.3))
          .invert(() => window.f.strikePulse() > 0.6 ? 1 : 0)
          .add(solid(1, 1, 1, () => window.f.strikePulse() * 0.6))
          .color(0.7, 0.7, () => 0.9 + window.f.strikePulse())
          .out();
    },
    flightmap: () => {
        osc(() => 10 + window.feeds.sky.count, 0.05, 1)
          .kaleid(() => 4 + Math.floor(window.f.skyCount01() * 8))
          .modulate(osc(2).scrollX(() => (window.feeds.sky.last_pan || 0) * 0.1)
                          .scrollY(() => (window.feeds.sky.last_alt || 0) / 50000))
          .rotate(() => (window.feeds.sky.last_pan || 0) * 0.5)
          .color(() => 0.3 + window.f.skyCount01() * 0.5,
                 () => 0.5 + (window.feeds.sky.last_vel || 0) / 500,
                 () => 0.6 + (window.feeds.sky.last_alt || 0) / 20000)
          .out();
    },
    gridpulse: () => {
        osc(() => 30 + (window.feeds.netz.freq || 50) * 0.5, 0.05, 1.5)
          .modulateScale(osc(8).rotate(() => time * 0.5),
                         () => 0.05 + Math.abs(window.f.netzDev()) * 4)
          .scale(() => 1 + window.f.netzDev() * 8)
          .color(() => 0.5 - window.f.netzDev() * 5,
                 () => 0.5 + window.f.netzDev() * 5,
                 () => 0.5 + window.f.renew() * 0.5)
          .contrast(() => 1.2 + Math.abs(window.f.netzDev()) * 8)
          .out();
    },
    solarwind: () => {
        noise(() => 2 + window.f.wind01() * 8,
              () => 0.05 + window.f.flarePulse() * 0.3)
          .modulate(osc(() => 5 + window.f.wind01() * 10, 0.05)
                    .rotate(() => time * 0.2))
          .colorama(() => 0.05 + window.f.kp01() * 0.4)
          .add(solid(1, 0.6, 0.2, () => window.f.flarePulse() * 0.5))
          .scale(() => 0.8 + window.f.wind01() * 0.5)
          .saturate(() => 1.3 + window.f.flarePulse() * 2)
          .out();
    },
    bskyrain: () => {
        shape(4, 0.005, 0.001)
          .repeat(() => 40 + window.f.bskyDensity() * 80,
                  () => 40 + window.f.bskyDensity() * 80)
          .scrollY(() => time * (0.05 + window.f.bskyDensity() * 0.3))
          .scrollX(() => Math.sin(time * 0.3) * 0.02)
          .color(() => 0.4 + window.f.bskyDensity() * 0.4,
                 () => 0.7 + window.f.kp01() * 0.3, 1)
          .modulate(noise(2, 0.2), 0.05)
          .out();
    },
};

document.querySelectorAll("[data-p]").forEach(b => b.addEventListener("click", () => {
    document.querySelectorAll("[data-p]").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    const p = PRESETS[b.dataset.p];
    if (p) p();
}));

// HUD
const aliveEl = document.getElementById("alive");
const kpEl = document.getElementById("kp");
const bzEl = document.getElementById("bz");
const windEl = document.getElementById("wind");
setInterval(() => {
    const a = window.feeds?.alive;
    aliveEl.textContent = a ? "ALIVE" : "DOWN";
    aliveEl.className = a ? "alive" : "dead";
    kpEl.textContent = (window.feeds?.swpc.kp ?? 0).toFixed(1);
    bzEl.textContent = (window.feeds?.swpc.bz ?? 0).toFixed(1);
    windEl.textContent = (window.feeds?.swpc.wind_speed ?? 0).toFixed(0);
}, 250);

PRESETS.aurora();
document.querySelector("[data-p=aurora]").classList.add("active");
