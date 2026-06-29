// js/mixer.js — per-voice fader/mute strips for the matrix mixer.
import { send } from "./osc.js";
import { MATRIX_VOICES } from "./matrix-state.js";

const mixerLevel = {};
const mixerMuted = {};
MATRIX_VOICES.forEach(v => { mixerLevel[v] = 0.8; mixerMuted[v] = false; });

function renderMixer() {
  const container = document.getElementById("matrix-mixer");
  if (!container) return;
  container.innerHTML = "";
  MATRIX_VOICES.forEach(voice => {
    const strip = document.createElement("div");
    strip.className = "mix-strip";
    strip.dataset.voice = voice;

    const fader = document.createElement("input");
    fader.type = "range";
    fader.min = "0";
    fader.max = "1.5";
    fader.step = "0.05";
    fader.value = String(mixerLevel[voice]);
    fader.className = "mix-fader";
    fader.dataset.voice = voice;

    const muteBtn = document.createElement("button");
    muteBtn.className = "mix-mute";
    muteBtn.textContent = "M";

    const label = document.createElement("span");
    label.className = "mix-label";
    label.textContent = voice;

    fader.addEventListener("input", () => {
      const v = +fader.value;
      mixerLevel[voice] = v;
      // Moving the fader unmutes + sends immediately
      if (mixerMuted[voice]) {
        mixerMuted[voice] = false;
        strip.classList.remove("muted");
        muteBtn.classList.remove("on");
      }
      send("/launch/vol", voice, v);
    });

    muteBtn.addEventListener("click", () => {
      mixerMuted[voice] = !mixerMuted[voice];
      if (mixerMuted[voice]) {
        muteBtn.classList.add("on");
        strip.classList.add("muted");
        send("/launch/vol", voice, 0);
      } else {
        muteBtn.classList.remove("on");
        strip.classList.remove("muted");
        send("/launch/vol", voice, mixerLevel[voice]);
      }
    });

    strip.appendChild(fader);
    strip.appendChild(muteBtn);
    strip.appendChild(label);
    container.appendChild(strip);
  });
}

export function init() {
  renderMixer();
}
