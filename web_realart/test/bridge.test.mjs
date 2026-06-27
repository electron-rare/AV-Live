import { test } from "node:test";
import assert from "node:assert";
import { spawn } from "node:child_process";
import { WebSocket } from "ws";
import osc from "osc";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HTTP_PORT = 4555, SC_PORT = 57599;

test("WS {address,args} is forwarded as OSC to the SC host", async () => {
  // loopback OSC listener standing in for SC
  const recv = new Promise((resolve) => {
    const udp = new osc.UDPPort({ localAddress: "127.0.0.1", localPort: SC_PORT, metadata: false });
    udp.on("message", (m) => { udp.close(); resolve(m); });
    udp.open();
  });
  const srv = spawn("node", [join(__dirname, "..", "server.js")], {
    env: { ...process.env, HTTP_PORT: String(HTTP_PORT), AVLIVE_SC_HOST: "127.0.0.1",
           AVLIVE_SC_PORT: String(SC_PORT), DATA_PORT_IN: "57598" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  await new Promise((res) => srv.stdout.on("data", (b) => { if (String(b).includes("listen") || String(b).includes("HTTP")) res(); }));
  await new Promise((r) => setTimeout(r, 300));
  const ws = new WebSocket(`ws://127.0.0.1:${HTTP_PORT}/ws`);
  await new Promise((res) => ws.on("open", res));
  ws.send(JSON.stringify({ address: "/launch", args: ["kick", 1] }));
  const msg = await recv;
  ws.close(); srv.kill("SIGKILL");
  assert.strictEqual(msg.address, "/launch");
  assert.strictEqual(String(msg.args[0]), "kick");
});
