// Carte mondiale fullscreen : seismes, foudre, avions, ISS, volcans.
// Markers ephemeres (fade out apres TTL_MS) + ISS persistant.

const map = L.map("map", { zoomControl: false, attributionControl: false })
  .setView([20, 0], 2);
L.tileLayer(
  "https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png",
  { maxZoom: 12 }
).addTo(map);

const connEl = document.getElementById("conn");
const countsEl = document.getElementById("counts");
let total = 0;

// ------------------- WebSocket --------------------------------
function connect() {
  const url = (location.protocol === "https:" ? "wss://" : "ws://")
    + location.host;
  const ws = new WebSocket(url);
  ws.onopen = () => connEl.textContent = "connecte";
  ws.onclose = () => {
    connEl.textContent = "deconnecte";
    setTimeout(connect, 2000);
  };
  ws.onmessage = (ev) => {
    try { handleMessage(JSON.parse(ev.data)); }
    catch (e) { console.warn(e); }
  };
}
connect();

// ------------------- Marker helpers ---------------------------
const TTL_MS = 60_000;  // markers visibles 60s

function ephemeralMarker(lat, lon, kind, label) {
  const icon = L.divIcon({
    className: "",
    iconSize: [10, 10],
    html: `<div class="${kind}" style="width:10px;height:10px"></div>`,
  });
  const m = L.marker([lat, lon], { icon }).addTo(map);
  if (label) m.bindTooltip(label, { direction: "top" });
  setTimeout(() => map.removeLayer(m), TTL_MS);
  total += 1;
  countsEl.textContent = `${total} events`;
  return m;
}

// ISS : un seul marker persistant qui bouge
let issMarker = null;
function updateIss(lat, lon) {
  const icon = L.divIcon({
    className: "",
    iconSize: [16, 16],
    html: `<div class="iss" style="width:16px;height:16px"></div>`,
  });
  if (issMarker) issMarker.setLatLng([lat, lon]);
  else issMarker = L.marker([lat, lon], { icon })
    .addTo(map)
    .bindTooltip("ISS", { permanent: true, direction: "top",
                          offset: [0, -8] });
}

// ------------------- Handlers ---------------------------------
const handlers = {
  usgs: (m) => {
    if (m.sub !== "event") return;
    const [lat, lon, mag] = m.args;
    ephemeralMarker(lat, lon, "quake", `M${mag.toFixed(1)} seisme`);
  },
  blitzortung: (m) => {
    if (m.sub !== "strike") return;
    const [lat, lon] = m.args;
    ephemeralMarker(lat, lon, "strike", "foudre");
  },
  opensky: (m) => {
    if (m.sub !== "state") return;
    const [, , lat, lon] = m.args;
    if (lat && lon) ephemeralMarker(lat, lon, "plane", "vol");
  },
  iss: (m) => {
    if (m.sub === "pos") updateIss(m.args[0], m.args[1]);
  },
  volcano: (m) => {
    if (m.sub !== "eruption") return;
    const [lat, lon, vei, region] = m.args;
    ephemeralMarker(lat, lon, "volcano",
                    `volcan ${region} (VEI ${vei})`);
  },
};

function handleMessage(msg) {
  const h = handlers[msg.feed];
  if (h) h(msg);
}
