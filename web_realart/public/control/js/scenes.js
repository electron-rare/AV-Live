// js/scenes.js — scene slot controls, mode toggle, prev/next navigation.
import { send, on } from "./osc.js";

let sceneMode = "launch"; // "launch" | "save" | "clear"

function setSceneMode(mode) {
  sceneMode = mode;
  document.querySelectorAll(".mode-btn").forEach((b) => {
    b.classList.toggle("active", b.dataset.mode === mode);
  });
}

export function init() {
  // /scene/state <cur:int> <fill0:int> ... <fill7:int>
  on("/scene/state", (args) => {
    const cur = Number(args[0]);
    document.querySelectorAll("[data-scene]").forEach((btn) => {
      const n = +btn.dataset.scene;
      btn.classList.toggle("filled", Number(args[n + 1]) === 1);
      btn.classList.toggle("current", n === cur);
    });
  });

  // Scene mode toggle buttons
  document.querySelectorAll(".mode-btn").forEach((btn) =>
    btn.addEventListener("click", () => setSceneMode(btn.dataset.mode)));

  // Scene slot buttons
  document.querySelectorAll("[data-scene]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const i = +btn.dataset.scene;
      send("/scene/" + sceneMode, i);
      if (sceneMode === "save" || sceneMode === "clear") {
        setSceneMode("launch");
      }
    }));

  // Scene prev / next
  const scenePrev = document.getElementById("scene-prev");
  if (scenePrev) scenePrev.addEventListener("click", () => send("/scene/prev"));
  const sceneNext = document.getElementById("scene-next");
  if (sceneNext) sceneNext.addEventListener("click", () => send("/scene/next"));
}
