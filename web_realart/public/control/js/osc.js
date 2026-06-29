// js/osc.js — WebSocket↔OSC bridge with an address dispatch registry.
const ws = new WebSocket(`ws://${location.host}/ws`);
const handlers = new Map();       // address -> Set<fn(args)>
const openFns = [];
const closeFns = [];
const prefixHandlers = new Map(); // prefix -> Set<fn(address, args)>

export function on(address, fn) {
  if (!handlers.has(address)) handlers.set(address, new Set());
  handlers.get(address).add(fn);
}
/** Register a handler for all addresses starting with `prefix`. fn(address, args). */
export function onPrefix(prefix, fn) {
  if (!prefixHandlers.has(prefix)) prefixHandlers.set(prefix, new Set());
  prefixHandlers.get(prefix).add(fn);
}
export function onOpen(fn) { openFns.push(fn); }
export function onClose(fn) { closeFns.push(fn); }
export function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
ws.addEventListener("open", () => openFns.forEach((f) => f()));
ws.addEventListener("close", () => closeFns.forEach((f) => f()));
ws.addEventListener("message", (ev) => {
  let msg; try { msg = JSON.parse(ev.data); } catch (_e) { return; }
  if (!msg || typeof msg.address !== "string") return;
  const address = msg.address;
  const args = msg.args || [];
  const set = handlers.get(address);
  if (set) for (const fn of set) fn(args);
  for (const [prefix, pfns] of prefixHandlers) {
    if (address.startsWith(prefix)) for (const fn of pfns) fn(address, args);
  }
});
