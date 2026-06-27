const ws = new WebSocket(`ws://${location.host}/ws`);
const dot = () => document.getElementById("status");
ws.addEventListener("open", () => dot().className = "on");
ws.addEventListener("close", () => dot().className = "off");
function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
const armed = new Set();
function togglePad(el, name) {
  const on = !armed.has(name);
  on ? armed.add(name) : armed.delete(name);
  el.classList.toggle("armed", on);
  send("/launch", name, on ? 1 : 0);
}
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-pad]").forEach((el) =>
    el.addEventListener("click", () => togglePad(el, el.dataset.pad)));
  document.querySelectorAll("[data-osc]").forEach((el) =>
    el.addEventListener("click", () => {
      const a = el.dataset.arg;
      send(el.dataset.osc, ...(a === undefined ? [] : [isNaN(+a) ? a : +a]));
    }));
  const tempo = document.getElementById("tempo");
  tempo && tempo.addEventListener("input", () => send("/launch/tempo", +tempo.value));
  const filt = document.getElementById("filter");
  filt && filt.addEventListener("input", () => send("/control/fx/filter", +filt.value));
  document.getElementById("clear").addEventListener("click", () => {
    armed.clear(); document.querySelectorAll("[data-pad]").forEach((e) => e.classList.remove("armed"));
    send("/launch/clear");
  });
});
