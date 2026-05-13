// Control panel : sliders + scenes + XY pad -> WS -> server -> OSC SC.
// Retour SC (sync) -> WS -> labels du panneau.

const connPill = document.getElementById("conn");
let ws = null;
let connected = false;

function connect() {
  const url = (location.protocol === "https:" ? "wss://" : "ws://")
    + location.host;
  ws = new WebSocket(url);
  ws.onopen = () => {
    connected = true;
    connPill.textContent = "connecte";
    connPill.style.color = "#6fe9b3";
    connPill.style.background = "rgba(110,233,179,0.15)";
    connPill.style.borderColor = "rgba(110,233,179,0.4)";
  };
  ws.onclose = () => {
    connected = false;
    connPill.textContent = "deconnecte";
    setTimeout(connect, 2000);
  };
  ws.onmessage = (ev) => {
    try { handleSync(JSON.parse(ev.data)); } catch {}
  };
}
connect();

function send(path, args) {
  if (!connected || !ws) return;
  try {
    ws.send(JSON.stringify({ path, args }));
  } catch {}
}

// ---------- Sliders ----------
document.querySelectorAll(".slider-row").forEach((row) => {
  const path = row.dataset.osc;
  const input = row.querySelector("input[type=range]");
  const valEl = row.querySelector(".val");
  const update = () => {
    const v = parseFloat(input.value);
    valEl.textContent = (v >= 100 ? v.toFixed(0) : v.toFixed(2));
    send(path, [v]);
  };
  input.addEventListener("input", update);
});

// ---------- Scene buttons ----------
document.querySelectorAll("#scenes .scene-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("#scenes .scene-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    send("/scene/play", [btn.dataset.scene]);
  });
});

// ---------- Visual mode buttons ----------
document.querySelectorAll("#vizmodes .scene-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("#vizmodes .scene-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    send("/control/vizMode", [parseInt(btn.dataset.viz, 10)]);
  });
});

// ---------- XY pad ----------
const pad = document.getElementById("xy");
const cursor = document.getElementById("xy-cursor");
const coords = document.getElementById("xy-coords");
let dragging = false;

function setXY(clientX, clientY) {
  const r = pad.getBoundingClientRect();
  const x = Math.max(0, Math.min(1, (clientX - r.left) / r.width));
  const y = Math.max(0, Math.min(1, (clientY - r.top) / r.height));
  cursor.style.left = (x * 100) + "%";
  cursor.style.top = (y * 100) + "%";
  coords.textContent = `x=${x.toFixed(2)}  y=${y.toFixed(2)}`;
  send("/xy/x", [x]);
  send("/xy/y", [1.0 - y]);   // invert Y so 'up' = 1
}

pad.addEventListener("pointerdown", (e) => {
  dragging = true;
  pad.setPointerCapture(e.pointerId);
  setXY(e.clientX, e.clientY);
});
pad.addEventListener("pointermove", (e) => {
  if (!dragging) return;
  setXY(e.clientX, e.clientY);
});
pad.addEventListener("pointerup", (e) => {
  dragging = false;
  pad.releasePointerCapture(e.pointerId);
});

// ---------- Sync retour SC ----------
const syncBpm = document.getElementById("sync-bpm");
const syncBeat = document.getElementById("sync-beat");
const syncRms = document.getElementById("sync-rms");
const syncVoices = document.getElementById("sync-voices");

function handleSync(msg) {
  if (msg.kind !== "sync") return;
  switch (msg.sub) {
    case "bpm":
      syncBpm.textContent = msg.args[0]?.toFixed(1) + " BPM";
      break;
    case "beat":
      syncBeat.textContent = String(msg.args[0] | 0);
      break;
    case "rms":
      syncRms.textContent = (msg.args[0] ?? 0).toFixed(3);
      break;
    case "voices":
      syncVoices.textContent = String(msg.args[0] | 0);
      break;
  }
}
