// =====================================================================
//  web_realart / server.js  --  Bridge OSC <- data_feeds bridge.py vers
//  WS pour clients web (real.art.saillant.cc).
//
//  Aucune dependance a SuperCollider : ce serveur ne fait QUE relayer
//  les /data/<source>/<sub> recus en OSC vers tous les clients WS.
//
//  Architecture cible :
//
//    data_feeds/bridge.py  --OSC UDP 57124-->  server.js  --WS-->  navigateurs
//                                                    ^
//                                                    |
//                                          Cloudflared tunnel
//                                          real.art.saillant.cc
//
//  Variables d'environnement :
//    HTTP_PORT         (defaut 4400)
//    DATA_PORT_IN      (defaut 57124, ce que bridge.py envoie ici)
//    FEEDBACK_PORT_IN  (defaut 9000, feedback SC engine -> navigateurs)
// =====================================================================
import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import osc from "osc";

const __dirname = dirname(fileURLToPath(import.meta.url));

const HTTP_PORT    = parseInt(process.env.HTTP_PORT ?? "4400", 10);
const DATA_PORT_IN = parseInt(process.env.DATA_PORT_IN ?? "57124", 10);
const SC_HOST          = process.env.AVLIVE_SC_HOST ?? "127.0.0.1";
const SC_PORT          = parseInt(process.env.AVLIVE_SC_PORT ?? "57121", 10);
const FEEDBACK_PORT_IN = parseInt(process.env.FEEDBACK_PORT_IN ?? "9000", 10);

const app = express();
app.use(express.static(join(__dirname, "public")));

app.get("/api/health", (_req, res) => {
    res.json({
        ok: true,
        clients: wss?.clients.size ?? 0,
        data_port: DATA_PORT_IN,
        last_event: lastEventAt,
    });
});

const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

// derniere snapshot de chaque /data/<source>/<sub> -> envoye a chaque
// nouveau client pour qu'il ne demarre pas a vide.
const lastByAddress = new Map();
let lastEventAt = 0;

function broadcast(msg) {
    const payload = JSON.stringify(msg);
    for (const client of wss.clients) {
        if (client.readyState === client.OPEN) client.send(payload);
    }
}

wss.on("connection", (ws) => {
    console.log(`[ws] client connecte (total: ${wss.clients.size})`);
    // replay snapshot
    for (const [address, args] of lastByAddress) {
        ws.send(JSON.stringify({ address, args }));
    }
    ws.send(JSON.stringify({ address: "/sync/hello",
                              args: [{ data_port: DATA_PORT_IN }] }));
    ws.on("message", (data) => {
        let m; try { m = JSON.parse(data.toString()); } catch (_e) { return; }
        if (!m || typeof m.address !== "string") return;
        const args = (Array.isArray(m.args) ? m.args : []).map((a) =>
            typeof a === "number"
                ? (Number.isInteger(a) ? { type: "i", value: a } : { type: "f", value: a })
                : { type: "s", value: String(a) });
        try { scPort.send({ address: m.address, args }, SC_HOST, SC_PORT); } catch (_e) { /* SC down */ }
    });
    ws.on("close", () => console.log(`[ws] client deconnecte (total: ${wss.clients.size})`));
});

const dataPort = new osc.UDPPort({
    localAddress: "0.0.0.0",
    localPort: DATA_PORT_IN,
    metadata: false,
});

dataPort.on("ready", () => {
    console.log(`[data] ecoute :${DATA_PORT_IN} <- bridge.py`);
});

dataPort.on("message", (oscMsg) => {
    lastEventAt = Date.now();
    if (oscMsg.address.startsWith("/data/")) {
        lastByAddress.set(oscMsg.address, oscMsg.args);
    }
    broadcast({ address: oscMsg.address, args: oscMsg.args });
});

dataPort.on("error", (err) => console.error("[data] erreur:", err.message));
dataPort.open();

// Second UDP listener: engine feedback (SC -> browser clients).
// Relays /armed/*, /sync/beat, /sync/rms, /seq/*/state to all WS clients.
// Does NOT update lastByAddress snapshot (feedback is transient, not snapshottable).
const feedbackPort = new osc.UDPPort({
    localAddress: "0.0.0.0",
    localPort: FEEDBACK_PORT_IN,
    metadata: false,
});

feedbackPort.on("ready", () => {
    console.log(`[feedback] ecoute :${FEEDBACK_PORT_IN} <- SC engine`);
});

const FEEDBACK_PREFIXES = ["/armed/", "/sync/", "/seq/"];
feedbackPort.on("message", (oscMsg) => {
    if (!FEEDBACK_PREFIXES.some((p) => oscMsg.address.startsWith(p))) return;
    broadcast({ address: oscMsg.address, args: oscMsg.args });
});

feedbackPort.on("error", (err) => console.error("[feedback] erreur:", err.message));
feedbackPort.open();

const scPort = new osc.UDPPort({ localAddress: "127.0.0.1", localPort: 0, metadata: true });
scPort.on("ready", () => console.log(`[sc] OSC out -> ${SC_HOST}:${SC_PORT}`));
scPort.open();

httpServer.listen(HTTP_PORT, () => {
    console.log(`[server] HTTP :${HTTP_PORT} listening`);
    console.log("");
    console.log("=== AV-Live realart ===");
    console.log(`  Landing  : http://localhost:${HTTP_PORT}/`);
    console.log(`  WebGL    : http://localhost:${HTTP_PORT}/webgl/`);
    console.log(`  Audio    : http://localhost:${HTTP_PORT}/audio/`);
    console.log(`  Hydra    : http://localhost:${HTTP_PORT}/hydra/`);
    console.log(`  WS       : ws://localhost:${HTTP_PORT}/ws`);
    console.log(`  Health   : http://localhost:${HTTP_PORT}/api/health`);
    console.log("");
});

function shutdown() {
    console.log("\n[server] shutdown...");
    wss.close();
    dataPort.close();
    feedbackPort.close();
    scPort.close();
    httpServer.close(() => process.exit(0));
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
