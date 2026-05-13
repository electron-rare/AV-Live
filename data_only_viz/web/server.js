// =====================================================================
//  data_only_viz / web / server.js
//
//  Bridge bidirectionnel OSC <-> WebSocket pour le mode data-only.
//
//   data_feeds bridge.py ----osc :57124----> server.js
//                                              | WS broadcast
//                                              v
//                                         browser (dashboard / map)
//
//   browser (/control)  --WS--> server.js --osc :57121--> SuperCollider
//
//   SuperCollider --osc :57125--> server.js --WS broadcast--> browser
// =====================================================================
import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import osc from "osc";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HTTP_PORT = parseInt(process.env.HTTP_PORT ?? "3211", 10);
const OSC_DATA_IN = parseInt(process.env.OSC_DATA_IN ?? "57124", 10);
const OSC_SYNC_IN = parseInt(process.env.OSC_SYNC_IN ?? "57125", 10);
const SC_HOST = process.env.SC_HOST ?? "127.0.0.1";
const SC_PORT_OUT = parseInt(process.env.SC_PORT_OUT ?? "57121", 10);
const OF_PORT_OUT = parseInt(process.env.OF_PORT_OUT ?? "57123", 10);

const app = express();
app.use(express.static(join(__dirname, "public")));
app.get("/", (_req, res) => res.redirect("/dashboard.html"));

const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer });

const HISTORY_MAX = 500;
const history = [];
function record(m) {
  history.push(m);
  if (history.length > HISTORY_MAX) history.shift();
}

function broadcast(msg) {
  const payload = JSON.stringify(msg);
  for (const c of wss.clients) {
    if (c.readyState === 1) {
      try { c.send(payload); } catch {}
    }
  }
}

wss.on("connection", (ws) => {
  // Replay last ~100 events to fresh tabs
  for (const m of history.slice(-100)) {
    try { ws.send(JSON.stringify(m)); } catch {}
  }
  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(String(raw)); } catch { return; }
    // From browser : { kind: 'control'|'scene'|'xy', path, args }
    // -> dispatch en OSC vers SC.
    if (!msg || typeof msg.path !== "string") return;
    if (!msg.path.startsWith("/control/")
        && !msg.path.startsWith("/scene/")
        && !msg.path.startsWith("/xy/")) {
      return;
    }
    const args = (msg.args || []).map((v) => {
      if (typeof v === "number") return { type: "f", value: v };
      return { type: "s", value: String(v) };
    });
    // Routing par path :
    //   /control/viz* -> oscope-of (:57123) — Metal viz + skeleton renderer
    //   tout le reste -> SC (:57121)
    const port = msg.path.startsWith("/control/viz")
      ? OF_PORT_OUT : SC_PORT_OUT;
    udpOut.send({ address: msg.path, args }, SC_HOST, port);
  });
});

// OSC IN: data feeds + SC sync (2 sockets distincts)
const udpData = new osc.UDPPort({
  localAddress: "127.0.0.1", localPort: OSC_DATA_IN, metadata: false,
});
udpData.on("message", (m) => {
  const parts = (m.address || "").split("/").filter(Boolean);
  if (parts.length < 2 || parts[0] !== "data") return;
  const feed = parts[1];
  const sub = parts.slice(2).join("/") || "msg";
  const msg = {
    t: Date.now(), kind: "feed",
    feed, sub, args: Array.isArray(m.args) ? m.args : [],
  };
  record(msg);
  broadcast(msg);
});
udpData.on("error", (e) => console.error("OSC data error:", e));
udpData.open();
console.log(`OSC feeds in :${OSC_DATA_IN}`);

const udpSync = new osc.UDPPort({
  localAddress: "127.0.0.1", localPort: OSC_SYNC_IN, metadata: false,
});
udpSync.on("message", (m) => {
  // SC poussera /sync/bpm <f>, /sync/rms <f>, /sync/amp/<voie> <f>...
  const path = m.address || "";
  if (!path.startsWith("/sync/")) return;
  const sub = path.slice(6) || "msg";
  const msg = {
    t: Date.now(), kind: "sync", sub,
    args: Array.isArray(m.args) ? m.args : [],
  };
  record(msg);
  broadcast(msg);
});
udpSync.on("error", (e) => console.error("OSC sync error:", e));
udpSync.open();
console.log(`OSC sync from SC in :${OSC_SYNC_IN}`);

// OSC OUT vers SuperCollider
const udpOut = new osc.UDPPort({
  localAddress: "127.0.0.1", localPort: 0, metadata: false,
});
udpOut.open();
console.log(`OSC out to SC :${SC_HOST}:${SC_PORT_OUT}`);

httpServer.listen(HTTP_PORT, () => {
  console.log(`Data-only web on http://127.0.0.1:${HTTP_PORT}/`);
  console.log(`  Dashboard : /dashboard.html`);
  console.log(`  Map       : /map.html`);
  console.log(`  Control   : /control.html`);
});
