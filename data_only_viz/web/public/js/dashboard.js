// Dashboard live : OSC -> WS -> cards + sparklines.
// Aucune dependance externe. Tous les graphes en SVG vanilla.

const grid = document.getElementById("grid");
const connPill = document.getElementById("conn");
const ratePill = document.getElementById("rate");
const logEl = document.getElementById("log");

// ------------------- WebSocket connection -------------------
let ws = null;
let msgCount = 0;
function connect() {
  const url = (location.protocol === "https:" ? "wss://" : "ws://")
    + location.host;
  ws = new WebSocket(url);
  ws.onopen = () => {
    connPill.textContent = "connecte";
    connPill.style.background = "rgba(110,233,179,.18)";
    connPill.style.color = "#6fe9b3";
    connPill.style.borderColor = "rgba(110,233,179,.4)";
  };
  ws.onclose = () => {
    connPill.textContent = "deconnecte";
    connPill.style.background = "rgba(255,94,149,.18)";
    connPill.style.color = "#ff5e95";
    setTimeout(connect, 2000);
  };
  ws.onmessage = (ev) => {
    msgCount++;
    try { handleMessage(JSON.parse(ev.data)); }
    catch (e) { console.warn("parse error", e); }
  };
}
connect();

// Rate counter
setInterval(() => {
  ratePill.textContent = `${msgCount} msg/s`;
  msgCount = 0;
}, 1000);

// ------------------- Card registry --------------------------
const cards = new Map();   // id -> {el, valueEl, subEl, sparkEl, history}
function ensureCard(id, opts = {}) {
  let c = cards.get(id);
  if (c) return c;
  const el = document.createElement("div");
  el.className = "card";
  if (opts.wide) el.classList.add("wide");
  if (opts.alert) el.classList.add("alert");
  if (opts.warn) el.classList.add("warn");
  if (opts.green) el.classList.add("green");
  const title = document.createElement("h2");
  title.textContent = opts.title || id;
  const valueEl = document.createElement("div");
  valueEl.className = "value";
  valueEl.textContent = "—";
  const subEl = document.createElement("div");
  subEl.className = "sub";
  const sparkEl = document.createElementNS(
    "http://www.w3.org/2000/svg", "svg");
  sparkEl.setAttribute("class", "spark");
  sparkEl.setAttribute("preserveAspectRatio", "none");
  sparkEl.setAttribute("viewBox", "0 0 100 30");
  el.append(title, valueEl, subEl, sparkEl);
  grid.appendChild(el);
  c = { el, valueEl, subEl, sparkEl, history: [], order: opts.order ?? 99 };
  cards.set(id, c);
  // Sort children by order
  [...grid.children]
    .sort((a, b) => Number(a.dataset.order || 99) - Number(b.dataset.order || 99));
  el.dataset.order = c.order;
  return c;
}

function pushHistory(card, v, maxLen = 64) {
  card.history.push(v);
  if (card.history.length > maxLen) card.history.shift();
}

function drawSpark(card, color = "#ff5e95") {
  const hist = card.history;
  if (hist.length < 2) return;
  const min = Math.min(...hist);
  const max = Math.max(...hist);
  const range = (max - min) || 1;
  const stepX = 100 / (hist.length - 1);
  const points = hist.map((v, i) => {
    const x = i * stepX;
    const y = 28 - ((v - min) / range) * 26;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(" ");
  card.sparkEl.innerHTML = `<polyline fill="none" stroke="${color}" stroke-width="1.5" points="${points}" />`;
}

function fmt(v, digits = 2) {
  return (typeof v === "number" ? v.toFixed(digits) : "—");
}

// ------------------- Message handlers -----------------------
const handlers = {
  usgs: (m) => {
    if (m.sub === "event") {
      const [, , mag] = m.args;
      const c = ensureCard("usgs", { title: "USGS · seisme", order: 1, alert: mag >= 5 });
      c.valueEl.textContent = `M${fmt(mag, 1)}`;
      c.subEl.textContent = `dernier event • ${new Date(m.t).toLocaleTimeString()}`;
      pushHistory(c, Number(mag) || 0);
      drawSpark(c);
    }
  },
  swpc: (m) => {
    if (m.sub === "kp") {
      const c = ensureCard("kp", { title: "SWPC · Kp index", order: 5,
        alert: m.args[0] >= 6, warn: m.args[0] >= 4 });
      c.valueEl.textContent = fmt(m.args[0], 1);
      c.subEl.textContent = "geomagnetique 0..9";
      pushHistory(c, m.args[0]);
      drawSpark(c);
    } else if (m.sub === "wind") {
      const c = ensureCard("wind", { title: "SWPC · vent solaire", order: 6 });
      c.valueEl.textContent = `${fmt(m.args[0], 0)} km/s`;
      pushHistory(c, m.args[0]);
      drawSpark(c, "#6fe9b3");
    } else if (m.sub === "bz") {
      const c = ensureCard("bz", { title: "SWPC · Bz IMF", order: 7,
        alert: m.args[0] <= -10 });
      c.valueEl.textContent = `${fmt(m.args[0], 1)} nT`;
      pushHistory(c, m.args[0]);
      drawSpark(c);
    } else if (m.sub === "xray") {
      const c = ensureCard("xray", { title: "SWPC · X-ray flux", order: 8 });
      c.valueEl.textContent = m.args[0].toExponential(2);
      pushHistory(c, Math.log10(Math.max(m.args[0], 1e-10)));
      drawSpark(c, "#ffd84a");
    }
  },
  blitzortung: (m) => {
    if (m.sub === "strike") {
      const c = ensureCard("blitz", { title: "Foudre · global", order: 2 });
      c.valueEl.textContent = `${(c.history.length + 1)}`;
      c.subEl.textContent = `dernier • ${new Date(m.t).toLocaleTimeString()}`;
      pushHistory(c, c.history.length + 1, 128);
      drawSpark(c, "#ffd84a");
    }
  },
  opensky: (m) => {
    if (m.sub === "count") {
      const c = ensureCard("opensky", { title: "OpenSky · avions", order: 9 });
      c.valueEl.textContent = String(m.args[0] | 0);
      pushHistory(c, m.args[0]);
      drawSpark(c, "#6fe9b3");
    }
  },
  bluesky: (m) => {
    if (m.sub === "post") {
      const c = ensureCard("bsky", { title: "Bluesky · firehose", order: 10 });
      pushHistory(c, c.history.length + 1, 80);
      c.valueEl.textContent = `${c.history.length}`;
      c.subEl.textContent = "posts (window)";
      drawSpark(c, "#6fa6ff");
    }
  },
  openmeteo: (m) => {
    if (m.sub === "now") {
      const [t, hum, wspd, , press, rain] = m.args;
      const c = ensureCard("meteo", { title: "Meteo locale", order: 11, wide: true });
      c.valueEl.textContent = `${fmt(t, 1)}°C  /  ${fmt(hum, 0)}% HR`;
      c.subEl.textContent = `vent ${fmt(wspd, 1)} m/s · ${fmt(press, 0)} hPa · pluie ${fmt(rain, 1)} mm/h`;
      pushHistory(c, t);
      drawSpark(c, "#6fa6ff");
    }
  },
  openaq: (m) => {
    if (m.sub === "now") {
      const [pm25, pm10, no2, o3] = m.args;
      const c = ensureCard("air", { title: "Qualite air (μg/m³)", order: 12,
        wide: true, alert: pm25 > 35, warn: pm25 > 15 });
      c.valueEl.textContent = `PM2.5 ${fmt(pm25, 0)}`;
      c.subEl.textContent = `PM10 ${fmt(pm10, 0)} · NO₂ ${fmt(no2, 0)} · O₃ ${fmt(o3, 0)}`;
      pushHistory(c, pm25);
      drawSpark(c);
    }
  },
  iss: (m) => {
    if (m.sub === "pos") {
      const [lat, lon, alt, vel] = m.args;
      const c = ensureCard("iss", { title: "ISS · position", order: 13, wide: true });
      c.valueEl.textContent = `${fmt(lat, 1)}°, ${fmt(lon, 1)}°`;
      c.subEl.textContent = `alt ${fmt(alt, 0)} km · vel ${fmt(vel, 0)} km/h`;
    } else if (m.sub === "pass") {
      const c = ensureCard("iss", { title: "ISS · passage !", order: 13, wide: true, green: true });
      c.subEl.textContent = `dans le radius • dist ${fmt(m.args[1], 0)} km`;
    }
  },
  volcano: (m) => {
    if (m.sub === "active") {
      const c = ensureCard("volcano", { title: "Volcans actifs", order: 14,
        alert: m.args[0] >= 20 });
      c.valueEl.textContent = String(m.args[0] | 0);
      c.subEl.textContent = "eruptions 7 derniers jours";
      pushHistory(c, m.args[0]);
      drawSpark(c);
    } else if (m.sub === "eruption") {
      const c = ensureCard("volcano", { title: "Volcans actifs", order: 14 });
      c.subEl.textContent = `nouvelle eruption • ${m.args[3] || "region inconnue"}`;
    }
  },
  social_buzz: (m) => {
    if (m.sub === "pulse") {
      const c = ensureCard("social", { title: "Pulse social", order: 15 });
      c.valueEl.textContent = fmt(m.args[0] * 100, 0) + " %";
      pushHistory(c, m.args[0]);
      drawSpark(c, "#ff5e95");
    } else if (m.sub === "reddit") {
      const c = ensureCard("reddit", { title: "Reddit /r/all hot", order: 16 });
      c.valueEl.textContent = fmt(m.args[0], 0);
      c.subEl.textContent = `score moyen · ${fmt(m.args[1], 0)} comments`;
      pushHistory(c, m.args[0]);
      drawSpark(c, "#ff8838");
    } else if (m.sub === "hn") {
      const c = ensureCard("hn", { title: "HackerNews top", order: 17 });
      c.valueEl.textContent = fmt(m.args[0], 0);
      c.subEl.textContent = `score moyen · ${fmt(m.args[1], 0)} comments`;
      pushHistory(c, m.args[0]);
      drawSpark(c, "#ff8838");
    }
  },
  netzfrequenz: (m) => {
    if (m.sub === "freq") {
      const c = ensureCard("grid", { title: "Reseau EU · 50 Hz", order: 18 });
      c.valueEl.textContent = `${fmt(m.args[0], 3)} Hz`;
      c.subEl.textContent = `delta ${fmt((m.args[0] - 50) * 1000, 1)} mHz`;
      pushHistory(c, m.args[0]);
      drawSpark(c);
    }
  },
  // ---- Nouveaux feeds (gdelt, wikimedia, tides, atc, pose, mempool,
  //      github, rte_eco2mix) -------------------------------------
  gdelt: (m) => {
    if (m.sub === "batch") {
      const [n, countries, tone] = m.args;
      const c = ensureCard("gdelt", { title: "GDELT · evenements 15min",
        order: 19, wide: true,
        alert: tone < -5, warn: tone < -2, green: tone > 2 });
      c.valueEl.textContent = String(n | 0);
      c.subEl.textContent = `${countries | 0} pays · tone ${fmt(tone, 2)}`;
      pushHistory(c, n);
      drawSpark(c);
    }
  },
  wikimedia: (m) => {
    if (m.sub === "rate") {
      const c = ensureCard("wiki", { title: "Wikipedia firehose", order: 20 });
      c.valueEl.textContent = `${fmt(m.args[0], 1)} /s`;
      pushHistory(c, m.args[0]);
      drawSpark(c, "#6fa6ff");
    } else if (m.sub === "edit") {
      const c = ensureCard("wiki", { title: "Wikipedia firehose", order: 20 });
      c.subEl.textContent = `${m.args[0]}: ${m.args[1]}`;
    }
  },
  tides: (m) => {
    if (m.sub === "level") {
      const [obs, pred, residual] = m.args;
      const c = ensureCard("tides", { title: "Marees NOAA", order: 21, wide: true });
      c.valueEl.textContent = `${fmt(obs, 2)} m`;
      c.subEl.textContent = `predit ${fmt(pred, 2)} m · residual ${fmt(residual, 2)} m`;
      pushHistory(c, obs);
      drawSpark(c, "#6fa6ff");
    } else if (m.sub === "moon") {
      const [phase, illum] = m.args;
      const c = ensureCard("moon", { title: "Phase lunaire", order: 22 });
      const phaseName = phase < 0.05 || phase > 0.95 ? "nouvelle"
        : phase < 0.25 ? "premier croissant"
        : phase < 0.30 ? "premier quartier"
        : phase < 0.45 ? "gibbeuse croissante"
        : phase < 0.55 ? "pleine"
        : phase < 0.70 ? "gibbeuse decroissante"
        : phase < 0.80 ? "dernier quartier"
        : "dernier croissant";
      c.valueEl.textContent = `${fmt(illum * 100, 0)}%`;
      c.subEl.textContent = phaseName;
    }
  },
  atc: (m) => {
    if (m.sub === "total") {
      const [total, hubs] = m.args;
      const c = ensureCard("atc", { title: "ATC · auditeurs", order: 23 });
      c.valueEl.textContent = String(total | 0);
      c.subEl.textContent = `${hubs | 0} hubs actifs`;
      pushHistory(c, total);
      drawSpark(c, "#6fe9b3");
    }
  },
  pose: (m) => {
    if (m.sub === "count") {
      const c = ensureCard("pose", { title: "Pose YOLO · personnes", order: 3 });
      c.valueEl.textContent = String(m.args[0] | 0);
      pushHistory(c, m.args[0]);
      drawSpark(c, "#ff8838");
    }
  },
  mempool: (m) => {
    if (m.sub === "fee") {
      const c = ensureCard("btc", { title: "Bitcoin · fee sat/vB", order: 24 });
      c.valueEl.textContent = String(m.args[0] | 0);
      pushHistory(c, m.args[0]);
      drawSpark(c, "#ff8838");
    } else if (m.sub === "tx") {
      const c = ensureCard("btc", { title: "Bitcoin · fee sat/vB", order: 24 });
      c.subEl.textContent = `${m.args[0] | 0} tx en attente`;
    }
  },
  github: (m) => {
    if (m.sub === "rate") {
      const c = ensureCard("gh", { title: "GitHub events", order: 25 });
      c.valueEl.textContent = `${fmt(m.args[0], 1)} /s`;
      pushHistory(c, m.args[0]);
      drawSpark(c, "#6fa6ff");
    }
  },
  rte_eco2mix: (m) => {
    if (m.sub === "mix") {
      const [nuclear, solar, wind, gas] = m.args;
      const c = ensureCard("rte", { title: "RTE eCO2mix · GW", order: 26, wide: true });
      c.valueEl.textContent = `${fmt((nuclear + solar + wind + gas) / 1000, 1)} GW`;
      c.subEl.textContent = `nuc ${fmt(nuclear / 1000, 1)} · sol ${fmt(solar / 1000, 1)} · eol ${fmt(wind / 1000, 1)} · gaz ${fmt(gas / 1000, 1)}`;
      pushHistory(c, (nuclear + solar + wind + gas) / 1000);
      drawSpark(c, "#6fe9b3");
    } else if (m.sub === "co2") {
      const c = ensureCard("co2", { title: "Intensite CO2 · g/kWh", order: 27,
        alert: m.args[0] > 200, warn: m.args[0] > 100, green: m.args[0] < 50 });
      c.valueEl.textContent = String(m.args[0] | 0);
      pushHistory(c, m.args[0]);
      drawSpark(c);
    }
  },
};

function handleMessage(msg) {
  logEl.textContent = `${new Date(msg.t).toLocaleTimeString()}  /data/${msg.feed}/${msg.sub}  ${JSON.stringify(msg.args)}`;
  const h = handlers[msg.feed];
  if (h) h(msg);
}
