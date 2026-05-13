// =====================================================================
//  data_only_viz / web / server.js
//
//  Bridge OSC -> WebSocket pour le mode data-only d'AV-Live.
//
//   data_feeds bridge.py
//        |  OSC UDP :57124
//        v
//   server.js (Express :3211 + WS)
//        |  JSON via WebSocket
//        v
//   browser : dashboard.html / map.html
//
//  Conversion : chaque message OSC /data/<feed>/<sub> args... devient
//      { feed, sub, args, t }
//  diffuse a tous les clients WS connectes.
// =====================================================================
import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import osc from "osc";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HTTP_PORT = parseInt(process.env.HTTP_PORT ?? "3211", 10);
const OSC_PORT_IN = parseInt(process.env.OSC_PORT_IN ?? "57124", 10);

const app = express();
app.use(express.static(join(__dirname, "public")));
app.get("/", (_req, res) => res.redirect("/dashboard.html"));

const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer });

// Ring buffer for late-joiners : ~500 last messages
const HISTORY_MAX = 500;
const history = [];
function record(msg) {
  history.push(msg);
  if (history.length > HISTORY_MAX) history.shift();
}

wss.on("connection", (ws) => {
  // Replay recent history so a new dashboard sees the latest values
  for (const msg of history.slice(-100)) {
    try { ws.send(JSON.stringify(msg)); } catch {}
  }
});

function broadcast(msg) {
  const payload = JSON.stringify(msg);
  for (const c of wss.clients) {
    if (c.readyState === 1) {
      try { c.send(payload); } catch {}
    }
  }
}

// OSC UDP listener
const udp = new osc.UDPPort({
  localAddress: "127.0.0.1",
  localPort: OSC_PORT_IN,
  metadata: false,
});

udp.on("message", (m) => {
  // Path format : /data/<feed>/<sub>
  const parts = (m.address || "").split("/").filter(Boolean);
  if (parts.length < 2 || parts[0] !== "data") return;
  const feed = parts[1];
  const sub = parts.slice(2).join("/") || "msg";
  const msg = {
    t: Date.now(),
    feed,
    sub,
    args: Array.isArray(m.args) ? m.args : [],
  };
  record(msg);
  broadcast(msg);
});

udp.on("error", (e) => console.error("OSC error:", e));
udp.open();
console.log(`OSC listening on udp :${OSC_PORT_IN}`);

httpServer.listen(HTTP_PORT, () => {
  console.log(`Data-only web on http://127.0.0.1:${HTTP_PORT}/`);
  console.log(`  Dashboard : http://127.0.0.1:${HTTP_PORT}/dashboard.html`);
  console.log(`  Map       : http://127.0.0.1:${HTTP_PORT}/map.html`);
});
