// =====================================================================
//  sound_algo / web / server.js
//
//  Pont HTTP + WebSocket + OSC entre le navigateur et SuperCollider.
//
//   navigateur (control/hydra)
//        |
//        |  WebSocket  (port HTTP 3000)
//        v
//   server.js
//        |
//        |  OSC UDP    (port 57121 -> SC, port 57122 <- SC)
//        v
//   SuperCollider (sclang) -- voir web_bridge.scd
//
//  Convention de paths :
//    /control/...  : navigateur -> SC  (mutations parametres)
//    /sync/...     : SC -> navigateur  (BPM, beats, amplitude voies)
// =====================================================================
import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import osc from "osc";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------
//  Configuration (modifiable via variables d'environnement)
// ---------------------------------------------------------------------
const HTTP_PORT = parseInt(process.env.HTTP_PORT ?? "3000", 10);
const SC_HOST = process.env.SC_HOST ?? "127.0.0.1";
const SC_PORT_OUT = parseInt(process.env.SC_PORT_OUT ?? "57121", 10); // -> SC
const SC_PORT_IN = parseInt(process.env.SC_PORT_IN ?? "57122", 10);  // <- SC

// ---------------------------------------------------------------------
//  HTTP : Express sert public/
// ---------------------------------------------------------------------
const app = express();
app.use(express.static(join(__dirname, "public")));
app.use(express.json());

// Healthcheck simple
app.get("/api/health", (_req, res) => {
    res.json({
        ok: true,
        sc: { host: SC_HOST, portOut: SC_PORT_OUT, portIn: SC_PORT_IN },
        clients: wss?.clients.size ?? 0,
    });
});

const httpServer = createServer(app);

// ---------------------------------------------------------------------
//  WebSocket : navigateur <-> server.js
// ---------------------------------------------------------------------
const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

function broadcast(msg) {
    const payload = JSON.stringify(msg);
    for (const client of wss.clients) {
        if (client.readyState === client.OPEN) {
            client.send(payload);
        }
    }
}

wss.on("connection", (ws) => {
    console.log(`[ws] client connecte (total: ${wss.clients.size})`);

    ws.on("message", (raw) => {
        let msg;
        try {
            msg = JSON.parse(raw.toString());
        } catch (err) {
            console.error("[ws] message non-JSON:", raw.toString());
            return;
        }
        // Format : { address: "/control/bpm", args: [128] }
        if (typeof msg.address === "string" && Array.isArray(msg.args)) {
            sendToSC(msg.address, msg.args);
        } else {
            console.warn("[ws] message mal forme:", msg);
        }
    });

    ws.on("close", () => {
        console.log(`[ws] client deconnecte (total: ${wss.clients.size})`);
    });

    // Hello message
    ws.send(JSON.stringify({
        address: "/sync/hello",
        args: [{ portOut: SC_PORT_OUT, portIn: SC_PORT_IN }],
    }));
});

// ---------------------------------------------------------------------
//  OSC : server.js <-> SuperCollider (UDP)
// ---------------------------------------------------------------------
const oscPort = new osc.UDPPort({
    localAddress: "127.0.0.1",
    localPort: SC_PORT_IN,
    remoteAddress: SC_HOST,
    remotePort: SC_PORT_OUT,
    metadata: false,
});

oscPort.on("ready", () => {
    console.log(
        `[osc] ready -- ecoute :${SC_PORT_IN} <- SC, envoie -> ${SC_HOST}:${SC_PORT_OUT}`,
    );
});

oscPort.on("message", (oscMsg) => {
    // SC -> navigateur (broadcast a tous les clients WS connectes)
    broadcast({ address: oscMsg.address, args: oscMsg.args });
});

oscPort.on("error", (err) => {
    console.error("[osc] erreur:", err.message);
});

oscPort.open();

function sendToSC(address, args) {
    const payload = args.map((v) => {
        if (typeof v === "number") {
            return Number.isInteger(v) ? { type: "i", value: v } : { type: "f", value: v };
        }
        if (typeof v === "string") return { type: "s", value: v };
        if (typeof v === "boolean") return { type: "i", value: v ? 1 : 0 };
        return { type: "s", value: String(v) };
    });
    oscPort.send({ address, args: payload });
}

// ---------------------------------------------------------------------
//  Demarrage HTTP
// ---------------------------------------------------------------------
httpServer.listen(HTTP_PORT, () => {
    console.log("");
    console.log("=== sound_algo web bridge ===");
    console.log(`  Landing   : http://localhost:${HTTP_PORT}/`);
    console.log(`  Control   : http://localhost:${HTTP_PORT}/control/`);
    console.log(`  Hydra     : http://localhost:${HTTP_PORT}/hydra/`);
    console.log(`  WebSocket : ws://localhost:${HTTP_PORT}/ws`);
    console.log(`  Health    : http://localhost:${HTTP_PORT}/api/health`);
    console.log("");
    console.log("  Cote SC   : (~base ++ \"web_bridge.scd\").load");
    console.log("");
});

// ---------------------------------------------------------------------
//  Cleanup propre
// ---------------------------------------------------------------------
function shutdown() {
    console.log("\n[server] shutdown...");
    wss.close();
    oscPort.close();
    httpServer.close(() => process.exit(0));
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
