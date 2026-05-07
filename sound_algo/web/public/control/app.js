// =====================================================================
// sound_algo · live — surface de contrôle web
// Module unique vanilla JS, pas de framework, pas de build
// =====================================================================

// ---------------- Constantes (listes statiques) ----------------------
const KICKS = ["techno","gabber","dub","dubstep","trance","hardstyle","amen","dnb","jungle","house","detroit","phonk","afro","garage","triphop","footwork","minimal","electro"];
const PKITS = ["techno","dubstep","dnb","trap","house","hardstyle","jungle","phonk","industrial","hardcore","detroitDeep","lofiHipHop","tribalWorld"];
const PGENRES = ["hardTechno","acidHouse","trance138","psyTrance","liquidDnB","neurofunk","jungle165","futureBass","deepHouse","techHouse","industrialV2","breakcore","footwork","idm","glitchHop"];
const FF = ["dub","space","trance","dubstep","retro","industrial","dream","cosmic","drone","dry"];
const VOICES = ["kick","hat","snare","clap","perc","acid","melody","harmony"];
const SEQ_VOICES = ["kick","hat","snare","clap","perc","acid","melody","harmony"];
const M_KINDS = ["short","long","xlong","epic"];
// Listes hardcodées : utilisées en fallback si SC ne renvoie pas /sync/synthdef
// ou /sync/melody en moins de 5s (catalogues dynamiques).
const M_INSTS_FALLBACK = ["lead","warmPad","pluck","stab","saw3","fmBell","supersaw","rhodes","guzheng","koto","handpan"];
const M_GENRES_FALLBACK = ["acid","house","techno","trance","dnb","ambient","cinematic","ethno"];
const SD_CATS = ["drums","bass","lead","pad","world","master"];
const SEND_BUSES = [["rev","Reverb"],["dly","Delay"],["chr","Chorus"],["phs","Phaser"],["flg","Flanger"],["crsh","Bitcrush"],["tape","Tape"],["shim","Shimmer"],["dist","Dist"]];
const VCF_TYPES = ["moog","ladder","svf","rlpf","rhpf"];
// Listes alignées avec SC :
//  - VCF presets  : live/live.scd:459-475 (~vcfPreset)
//  - COMP presets : live/live.scd:1109-1122 (~compOn)
//  - SAT modes    : live/fx.scd:154 (~fx[\sat][\go]) -> tanh|softclip|fold
const VCF_PRESETS = ["acid","dub","deep","bright","dark","formantA","formantE","formantI","formantO","formantU"];
const COMP_PRESETS = ["soft","glue","punch","pump"];
const SAT_MODES = ["tanh","softclip","fold"];
const TRACKS = "ABCDEFGHIJKLMNOPQRSTUVW".split("");

const TRICKS = [
  { osc: "/control/drop", label: "Drop", note: "" },
  { osc: "/control/breakdown", args: [8], label: "Breakdown", note: "8 bars" },
  { osc: "/control/buildup", args: [8], label: "Buildup", note: "8 bars" },
  { osc: "/control/glitch", args: [2], label: "Glitch", note: "2s" },
  { osc: "/control/stutter", args: [8, 1], label: "Stutter", note: "8/1s" },
  { osc: "/control/freeze", label: "Freeze", note: "" },
  { osc: "/control/tapeStop", args: [2], label: "Tape stop", note: "2s" },
  { osc: "/control/tapeReverse", args: [4], label: "Tape rev", note: "4s" },
  { osc: "/control/handsUp", label: "Hands up", note: "" },
  { osc: "/control/jumpCut", args: [0.5], label: "Jump cut", note: "0.5s" },
  { osc: "/control/bitCrushNow", args: [6, 6000, 1], label: "Bit crush", note: "6b 6k 1s" },
];

const CHAINS = [
  { name: "intro" },
  { name: "drop" },
  { name: "breakdown" },
  { name: "buildup", input: { label: "bars", value: 8 } },
  { name: "techno", input: { label: "reps", value: 4 } },
  { name: "dnb", input: { label: "reps", value: 4 } },
  { name: "outroFade", input: { label: "dur s", value: 8 } },
  { name: "stop" },
];

// ---------------- État global ---------------------------------------
const state = {
  ws: null,
  bpm: 128,
  beatCount: 0,
  amp: {},          // voice -> { current, target }
  muted: new Set(),
  soloed: new Set(),
  playing: new Set(),
  liveEdit: false,
  selectedKick: null,
  selectedFf: null,
  jumpLetter: null,
  sectionsByLetter: {},  // 'A' -> [slug, ...]
  tapTimes: [],
  albums: new Map(),     // 'A' -> { title, trackCount, totalSec, slugs: [] }
  lastTrack: null,       // { letter, n }
};
VOICES.forEach(v => state.amp[v] = { current: 0, target: 0 });

// ----- Catalogues dynamiques (mélodies + SynthDefs) -----------------
const CAT_KEY = "sound_algo.catalog.v1";
const catalog = {
  // Mélodies : { genre -> [name1, name2, ...] }
  melodies: {},
  // SynthDefs : { category -> [name1, name2, ...] }
  synthdefs: {},
  // UI state mélodies
  melGenre: null,
  melLen: "all",
  melSearch: "",
  melPage: 0,
  melActive: null,
  // UI state synthdefs
  sdCat: "drums",
  sdSearch: "",
  sdPage: 0,
  sdActive: null,
  // Reception flags pour fallback timer
  gotMelody: false,
  gotSynthdef: false,
};
const CAT_PAGE_SIZE = 50;
try {
  const saved = JSON.parse(localStorage.getItem(CAT_KEY) || "{}");
  if (typeof saved.melGenre === "string") catalog.melGenre = saved.melGenre;
  if (typeof saved.melLen === "string") catalog.melLen = saved.melLen;
  if (typeof saved.melSearch === "string") catalog.melSearch = saved.melSearch;
  if (typeof saved.sdCat === "string") catalog.sdCat = saved.sdCat;
  if (typeof saved.sdSearch === "string") catalog.sdSearch = saved.sdSearch;
} catch {}
function saveCatalog() {
  try {
    localStorage.setItem(CAT_KEY, JSON.stringify({
      melGenre: catalog.melGenre,
      melLen: catalog.melLen,
      melSearch: catalog.melSearch,
      sdCat: catalog.sdCat,
      sdSearch: catalog.sdSearch,
    }));
  } catch {}
}

// État du séquenceur, persisté en localStorage
const SEQ_KEY = "sound_algo.seq.v2";
const seqState = {};
SEQ_VOICES.forEach(v => seqState[v] = new Array(16).fill(0));
try {
  const saved = JSON.parse(localStorage.getItem(SEQ_KEY) || "{}");
  SEQ_VOICES.forEach(v => {
    if (Array.isArray(saved[v]) && saved[v].length === 16) seqState[v] = saved[v].map(x => x ? 1 : 0);
  });
} catch {}
function saveSeq() {
  try { localStorage.setItem(SEQ_KEY, JSON.stringify(seqState)); } catch {}
}

// État Acid (notes 16, accents 16, slides 16, params)
const ACID_KEY = "sound_algo.acid.v1";
const ACID_DEFAULT_NOTES = [36,0,38,0,36,41,0,38, 36,43,0,46,38,0,48,0];
const acidState = {
  notes: ACID_DEFAULT_NOTES.slice(),
  accents: new Array(16).fill(0),
  slides: new Array(16).fill(0),
  cutoff: 1500, rq: 0.25, drive: 2.0, amp: 1.0,
};
try {
  const saved = JSON.parse(localStorage.getItem(ACID_KEY) || "{}");
  if (Array.isArray(saved.notes) && saved.notes.length === 16) acidState.notes = saved.notes.map(x => x | 0);
  if (Array.isArray(saved.accents) && saved.accents.length === 16) acidState.accents = saved.accents.map(x => x ? 1 : 0);
  if (Array.isArray(saved.slides) && saved.slides.length === 16) acidState.slides = saved.slides.map(x => x ? 1 : 0);
  if (typeof saved.cutoff === "number") acidState.cutoff = saved.cutoff;
  if (typeof saved.rq === "number") acidState.rq = saved.rq;
  if (typeof saved.drive === "number") acidState.drive = saved.drive;
  if (typeof saved.amp === "number") acidState.amp = saved.amp;
} catch {}
function saveAcid() {
  try { localStorage.setItem(ACID_KEY, JSON.stringify(acidState)); } catch {}
}

// État Harmony (notes 32 + amp)
const HARMONY_KEY = "sound_algo.harmony.v1";
const HARMONY_DEFAULT_NOTES = (() => {
  const a = new Array(32).fill(0);
  a[0] = 48; a[8] = 50; a[16] = 53; a[24] = 55;
  return a;
})();
const harmonyState = {
  notes: HARMONY_DEFAULT_NOTES.slice(),
  amp: 1.0,
};
try {
  const saved = JSON.parse(localStorage.getItem(HARMONY_KEY) || "{}");
  if (Array.isArray(saved.notes) && saved.notes.length === 32) harmonyState.notes = saved.notes.map(x => x | 0);
  if (typeof saved.amp === "number") harmonyState.amp = saved.amp;
} catch {}
function saveHarmony() {
  try { localStorage.setItem(HARMONY_KEY, JSON.stringify(harmonyState)); } catch {}
}

const HARMONY_PRESETS = ["off","third","fifth","octave","power","shell","sus2","sus4"];
const ACID_NOTE_CYCLE = [0, 36, 38, 41, 43, 46, 48, 51, 53];

// ---------------- Toasts -------------------------------------------
const toastsHost = document.getElementById("toasts");
function toast(msg, kind = "info", ttl = 3000) {
  if (!toastsHost) return;
  const t = document.createElement("div");
  t.className = `toast toast-${kind}`;
  t.textContent = msg;
  toastsHost.appendChild(t);
  setTimeout(() => { t.classList.add("leaving"); }, ttl - 300);
  setTimeout(() => { t.remove(); }, ttl);
}

// ---------------- Hamburger menu (responsive) ----------------------
{
  const btn = document.getElementById("tabMenuBtn");
  const tabs = document.getElementById("tabs");
  function toggleMenu(force) {
    const willOpen = force !== undefined ? force : !tabs.classList.contains("open");
    tabs.classList.toggle("open", willOpen);
    if (btn) btn.classList.toggle("open", willOpen);
  }
  if (btn) btn.addEventListener("click", () => toggleMenu());
  // Close menu on tab click (mobile)
  if (tabs) tabs.addEventListener("click", (ev) => {
    if (ev.target.matches("button.tab")) toggleMenu(false);
  });
}

// ---------------- Help modal --------------------------------------
{
  const modal = document.getElementById("helpModal");
  const open = () => { modal.hidden = false; };
  const close = () => { modal.hidden = true; };
  const btn = document.getElementById("helpBtn");
  if (btn) btn.addEventListener("click", open);
  document.getElementById("helpClose")?.addEventListener("click", close);
  modal?.addEventListener("click", (ev) => {
    if (ev.target === modal) close();
  });
  window.__helpOpen = open;
  window.__helpClose = close;
}

// ---------------- Keyboard shortcuts -------------------------------
document.addEventListener("keydown", (ev) => {
  // Skip when user is typing in a form field
  const t = ev.target;
  if (t.matches?.("input, textarea, select, [contenteditable=true]")) return;
  if (ev.metaKey || ev.ctrlKey || ev.altKey) return;

  const tabsEl = document.getElementById("tabs");
  const tabBtns = tabsEl ? Array.from(tabsEl.querySelectorAll("button.tab")) : [];
  const activeIdx = tabBtns.findIndex(b => b.classList.contains("active"));

  switch (ev.key) {
    case "ArrowLeft":
      if (tabBtns.length && activeIdx > 0) tabBtns[activeIdx - 1].click();
      ev.preventDefault();
      break;
    case "ArrowRight":
      if (tabBtns.length && activeIdx < tabBtns.length - 1) tabBtns[activeIdx + 1].click();
      ev.preventDefault();
      break;
    case "?": case "h":
      window.__helpOpen?.();
      ev.preventDefault();
      break;
    case "Escape":
      window.__helpClose?.();
      break;
    case "r":
      send("/control/listAlbums");
      send("/control/listSections");
      send("/control/listMelodies");
      send("/control/listSynthdefs");
      toast("Catalogues rafraîchis", "info", 1200);
      ev.preventDefault();
      break;
    case "s":
      send("/control/stopAll");
      toast("stop all", "info", 1000);
      ev.preventDefault();
      break;
    case "m":
      document.getElementById("tabMenuBtn")?.click();
      ev.preventDefault();
      break;
    default:
      // 1-9, 0 → tab N
      if (/^[0-9]$/.test(ev.key)) {
        const idx = ev.key === "0" ? 9 : (parseInt(ev.key, 10) - 1);
        if (tabBtns[idx]) {
          tabBtns[idx].click();
          ev.preventDefault();
        }
      }
  }
});

// ---------------- Pills active state -------------------------------
// Adds .active class to the clicked pill within its panel and removes it
// from any siblings of the same type. Listens at document level to handle
// dynamically rendered buttons.
document.addEventListener("click", (ev) => {
  const btn = ev.target.closest("button[data-pill-group]");
  if (!btn) return;
  const group = btn.dataset.pillGroup;
  document.querySelectorAll(`button[data-pill-group="${group}"]`).forEach(b => {
    b.classList.toggle("active", b === btn);
  });
});

// ---------------- WebSocket bridge ----------------------------------
const wsDot = document.getElementById("wsDot");
const wsLabel = document.getElementById("wsLabel");
const scDot = document.getElementById("scDot");
const scLabel = document.getElementById("scLabel");

// sclang heartbeat : last time we saw any /sync/* message
let lastSyncAt = 0;
function markSync() { lastSyncAt = Date.now(); }
function refreshSclangStatus() {
  const dt = Date.now() - lastSyncAt;
  const live = lastSyncAt > 0 && dt < 4000;
  if (scDot) scDot.classList.toggle("online", live);
  if (scDot) scDot.classList.toggle("offline", !live);
  if (scLabel) scLabel.textContent = live ? "sclang" : "no sync";
}
setInterval(refreshSclangStatus, 500);

function connect() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  state.ws = new WebSocket(`${proto}//${location.host}/ws`);

  state.ws.addEventListener("open", () => {
    wsDot.classList.add("online");
    wsDot.classList.remove("offline");
    wsLabel.textContent = "bridge";
    toast("Bridge connecté", "success", 1500);
    // Au démarrage : demander la liste des sections pour peupler le tab Jump
    send("/control/listSections");
    // Et la liste des albums pour peupler le tab Album
    send("/control/listAlbums");
    // Et l'état actuel du séquenceur (Steps tab)
    send("/control/getSteps");
    // Catalogues dynamiques (1060 SynthDefs + 2898 mélodies)
    send("/control/listSynthdefs");
    send("/control/listMelodies");
    // Fallback : si rien reçu en 5s, peuple avec listes hardcodées
    setTimeout(() => {
      if (!catalog.gotMelody) {
        M_GENRES_FALLBACK.forEach(g => { catalog.melodies[g] = []; });
        renderMelGenres();
      }
      if (!catalog.gotSynthdef) {
        SD_CATS.forEach(c => { catalog.synthdefs[c] = M_INSTS_FALLBACK.slice(); });
        renderSdGrid();
      }
    }, 5000);
  });
  state.ws.addEventListener("close", () => {
    wsDot.classList.remove("online");
    wsDot.classList.add("offline");
    wsLabel.textContent = "reconnecting…";
    setTimeout(connect, 1000);
  });
  state.ws.addEventListener("message", (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      markSync();
      handleSync(msg.address, msg.args || []);
    } catch {}
  });
}

// Auto-retry catalog queries while empty. sclang takes 60-90s to boot
// from a cold start, and may get restarted out from under the browser
// (operator relaunching the launcher). Keep retrying every 5s as long
// as the bridge is alive AND the local catalog is empty AND we've heard
// from sclang at least once in the last 4s.
setInterval(() => {
  if (state.ws && state.ws.readyState === WebSocket.OPEN
      && Date.now() - lastSyncAt < 4000) {
    if (state.albums && state.albums.size === 0) {
      send("/control/listAlbums");
      send("/control/listSections");
    }
  }
}, 5000);

function send(address, ...args) {
  if (!state.ws || state.ws.readyState !== WebSocket.OPEN) return;
  state.ws.send(JSON.stringify({ address, args }));
}

// Gestion des messages /sync/* depuis SC
function handleSync(addr, args) {
  switch (addr) {
    case "/sync/bpm": {
      const v = args[0] | 0;
      state.bpm = v;
      document.getElementById("hudBpm").textContent = v;
      const slider = document.getElementById("bpmSlider");
      const out = document.getElementById("outBpm");
      if (slider) { slider.value = v; setSliderFill(slider); }
      if (out) out.textContent = v;
      break;
    }
    case "/sync/beat": {
      state.beatCount = (state.beatCount + 1) % 16;
      flashBeat();
      updateStepMarker();
      const sc = document.getElementById("stepCounter");
      if (sc) sc.textContent = `step ${state.beatCount + 1}/16`;
      break;
    }
    case "/sync/amp": {
      const voice = args[0];
      const val = parseFloat(args[1]) || 0;
      if (state.amp[voice]) state.amp[voice].target = val;
      break;
    }
    case "/sync/sections": {
      const letter = args[0];
      const slugs = args.slice(1);
      if (typeof letter === "string") {
        state.sectionsByLetter[letter] = slugs;
      }
      break;
    }
    case "/sync/album": {
      const letter = args[0];
      const title = args[1];
      const trackCount = args[2] | 0;
      const totalSec = args[3] | 0;
      const slugs = args.slice(4).map(s => String(s));
      if (typeof letter === "string") {
        state.albums.set(letter, { title: String(title), trackCount, totalSec, slugs });
        renderAlbumCard(letter);
      }
      break;
    }
    case "/sync/synthdef": {
      const cat = String(args[0] || "");
      const names = args.slice(1).map(s => String(s));
      if (cat) {
        catalog.synthdefs[cat] = names;
        catalog.gotSynthdef = true;
        renderSdGrid();
        flashSync("sdCounter");
      }
      break;
    }
    case "/sync/melody": {
      const genre = String(args[0] || "");
      const names = args.slice(1).map(s => String(s));
      if (genre) {
        catalog.melodies[genre] = names;
        catalog.gotMelody = true;
        renderMelGenres();
        renderMelGrid();
        flashSync("melCounter");
      }
      break;
    }
    case "/sync/steps": {
      const voice = String(args[0]);
      const steps = args.slice(1, 17).map(v => (v | 0) ? 1 : 0);
      if (seqState[voice]) {
        seqState[voice] = steps;
        renderSeqVoice(voice);
        saveSeq();
      }
      break;
    }
    case "/sync/notes": {
      const voice = String(args[0]);
      const notes = args.slice(1).map(v => v | 0);
      // Voie acid : notes MIDI brutes 16 cellules
      if (voice === "acid" && notes.length >= 16) {
        acidState.notes = notes.slice(0, 16);
        renderAcidNotes();
        flashAcidGrid("acidNotesGrid");
        saveAcid();
      }
      // Voie harmony : notes MIDI brutes 32 cellules
      if (voice === "harmony" && notes.length >= 32) {
        harmonyState.notes = notes.slice(0, 32);
        renderHarmonyNotes();
        flashAcidGrid("harmonyNotesGrid");
        saveHarmony();
      }
      // Sync générique du Steps tab (binaire 16) : downsample si > 16
      if (seqState[voice]) {
        const bin = new Array(16).fill(0);
        if (notes.length <= 16) {
          for (let i = 0; i < Math.min(16, notes.length); i++) {
            bin[i] = notes[i] > 0 ? 1 : 0;
          }
        } else {
          // downsample 32 -> 16 (OR sur 2 valeurs consécutives)
          for (let i = 0; i < 16; i++) {
            const a = notes[i * 2] | 0;
            const b = notes[i * 2 + 1] | 0;
            bin[i] = (a > 0 || b > 0) ? 1 : 0;
          }
        }
        seqState[voice] = bin;
        renderSeqVoice(voice);
        saveSeq();
      }
      break;
    }
    case "/sync/acidAccents": {
      const accents = args.slice(0, 16).map(v => (v | 0) ? 1 : 0);
      if (accents.length === 16) {
        acidState.accents = accents;
        renderAcidAccents();
        flashAcidGrid("acidAccentsGrid");
        saveAcid();
      }
      break;
    }
    case "/sync/acidSlides": {
      const slides = args.slice(0, 16).map(v => (v | 0) ? 1 : 0);
      if (slides.length === 16) {
        acidState.slides = slides;
        renderAcidSlides();
        flashAcidGrid("acidSlidesGrid");
        saveAcid();
      }
      break;
    }
    case "/sync/acidParams": {
      const cutoff = parseFloat(args[0]);
      const rq = parseFloat(args[1]);
      const drive = parseFloat(args[2]);
      const amp = parseFloat(args[3]);
      if (!isNaN(cutoff)) { acidState.cutoff = cutoff; setAcidSlider("acidCut", cutoff, "outAcidCut", 0); }
      if (!isNaN(rq))     { acidState.rq = rq;         setAcidSlider("acidRq", rq, "outAcidRq", 2); }
      if (!isNaN(drive))  { acidState.drive = drive;   setAcidSlider("acidDrive", drive, "outAcidDrive", 2); }
      if (!isNaN(amp))    { acidState.amp = amp;       setAcidSlider("acidAmp", amp, "outAcidAmp", 2); }
      saveAcid();
      break;
    }
    case "/sync/harmonyAmp": {
      const amp = parseFloat(args[0]);
      if (!isNaN(amp)) {
        harmonyState.amp = amp;
        setAcidSlider("harmonyAmp", amp, "outHarmonyAmp", 2);
        saveHarmony();
      }
      break;
    }
    case "/sync/pong": {
      const ts = args[0];
      const out = document.getElementById("pingResult");
      if (out) out.textContent = `pong ${ts}`;
      break;
    }
    default:
      break;
  }
}

function flashBeat() {
  const el = document.getElementById("beatPulse");
  if (!el) return;
  el.classList.add("flash");
  setTimeout(() => el.classList.remove("flash"), 100);
}

connect();

// ---------------- Tabs (navigation) ---------------------------------
const tabsEl = document.getElementById("tabs");
const underline = document.getElementById("tabUnderline");

function activateTab(target) {
  document.querySelectorAll(".tab").forEach(t => t.classList.toggle("active", t.dataset.target === target));
  document.querySelectorAll(".tabpane").forEach(p => p.classList.toggle("active", p.dataset.tab === target));
  positionUnderline();
}
function positionUnderline() {
  const active = tabsEl.querySelector(".tab.active");
  if (!active || !underline) return;
  const r = active.getBoundingClientRect();
  const pr = tabsEl.getBoundingClientRect();
  underline.style.left = (active.offsetLeft) + "px";
  underline.style.width = r.width + "px";
}
tabsEl.querySelectorAll(".tab").forEach(t => {
  t.addEventListener("click", () => activateTab(t.dataset.target));
});
window.addEventListener("resize", positionUnderline);
requestAnimationFrame(positionUnderline);

// ---------------- Slider fill helper --------------------------------
function setSliderFill(el) {
  const min = parseFloat(el.min) || 0;
  const max = parseFloat(el.max) || 1;
  const v = parseFloat(el.value);
  const pct = ((v - min) / (max - min)) * 100;
  el.style.setProperty("--fill", pct + "%");
}
function bindSlider(el, onInput) {
  setSliderFill(el);
  el.addEventListener("input", () => {
    setSliderFill(el);
    onInput(parseFloat(el.value));
  });
}

// ---------------- TRANSPORT -----------------------------------------
const bpmSlider = document.getElementById("bpmSlider");
const outBpm = document.getElementById("outBpm");
let bpmThrottle = null;
bindSlider(bpmSlider, (v) => {
  outBpm.textContent = v.toFixed(0);
  document.getElementById("hudBpm").textContent = v.toFixed(0);
  if (bpmThrottle) return;
  bpmThrottle = setTimeout(() => {
    send("/control/bpm", parseInt(bpmSlider.value, 10));
    bpmThrottle = null;
  }, 100);
});

const masterSlider = document.getElementById("masterSlider");
const outMaster = document.getElementById("outMaster");
bindSlider(masterSlider, (v) => {
  outMaster.textContent = v.toFixed(2);
  send("/control/masterVol", v);
});

const fadeSlider = document.getElementById("fadeSlider");
const outFade = document.getElementById("outFade");
bindSlider(fadeSlider, (v) => { outFade.textContent = v.toFixed(0); });

document.getElementById("btnFadeOut").addEventListener("click", () => {
  const dur = parseFloat(fadeSlider.value);
  if (!confirm(`Fade out ${dur}s ?`)) return;
  send("/control/masterFadeOut", dur);
});
// Two-step "armed" pattern factored out — used by Reboot and Teardown
function makeArmedButton(btn, options) {
  const { armedLabel, armedClass, sendOnConfirm, toastArmed, toastFired } = options;
  let armed = false;
  let timer = null;
  const originalLabel = btn.textContent;
  const originalClass = "armed-" + (armedClass || "");
  btn.addEventListener("click", () => {
    if (!armed) {
      armed = true;
      btn.classList.add(originalClass, "armed");
      btn.textContent = armedLabel;
      if (toastArmed) toast(toastArmed, "warn", 2000);
      timer = setTimeout(() => {
        armed = false;
        btn.classList.remove(originalClass, "armed");
        btn.textContent = originalLabel;
      }, 2000);
      return;
    }
    clearTimeout(timer);
    armed = false;
    btn.classList.remove(originalClass, "armed");
    btn.textContent = originalLabel;
    sendOnConfirm();
    if (toastFired) toast(toastFired, originalClass.includes("danger") ? "danger" : "info", 1500);
  });
}

makeArmedButton(document.getElementById("btnRebootScsynth"), {
  armedLabel: "CONFIRM ?",
  armedClass: "warn",
  sendOnConfirm: () => send("/control/rebootServer"),
  toastArmed: "scsynth reboot armed — click again",
  toastFired: "scsynth reboot sent"
});

makeArmedButton(document.getElementById("btnRebootWeb"), {
  armedLabel: "CONFIRM ?",
  armedClass: "warn",
  sendOnConfirm: () => send("/control/rebootWeb"),
  toastArmed: "web reboot armed — click again",
  toastFired: "web reboot sent — Node restarting"
});

makeArmedButton(document.getElementById("btnRebootSclang"), {
  armedLabel: "CONFIRM sclang ?",
  armedClass: "warn",
  sendOnConfirm: () => send("/control/rebootSclang"),
  toastArmed: "sclang reboot armed — full engine restart",
  toastFired: "sclang reboot sent — engine restarting"
});

makeArmedButton(document.getElementById("btnTeardown"), {
  armedLabel: "CONFIRM ?",
  armedClass: "danger",
  sendOnConfirm: () => send("/control/teardown"),
  toastArmed: "TEARDOWN armed — click again within 2s",
  toastFired: "TEARDOWN sent"
});
document.getElementById("btnPing").addEventListener("click", () => {
  document.getElementById("pingResult").textContent = "…";
  send("/control/ping");
});
document.getElementById("btnTap").addEventListener("click", () => {
  const now = performance.now();
  state.tapTimes.push(now);
  state.tapTimes = state.tapTimes.filter(t => now - t < 3000);
  if (state.tapTimes.length >= 2) {
    const intervals = [];
    for (let i = 1; i < state.tapTimes.length; i++) intervals.push(state.tapTimes[i] - state.tapTimes[i-1]);
    const avg = intervals.reduce((a,b)=>a+b, 0) / intervals.length;
    const bpm = Math.round(60000 / avg);
    send("/control/bpm", bpm);
    bpmSlider.value = bpm;
    setSliderFill(bpmSlider);
    outBpm.textContent = bpm;
    document.getElementById("hudBpm").textContent = bpm;
  }
  send("/control/tap");
});
document.getElementById("btnPlayAll").addEventListener("click", () => send("/control/playAll"));
document.getElementById("btnStopAll").addEventListener("click", () => send("/control/stopAll"));

// ---------------- MIXER ---------------------------------------------
const mixerGrid = document.getElementById("mixerGrid");
// Voies pour lesquelles SC supporte cutoff / drive / RQ par voie
// (cf live/fx.scd:113-145 -- ~fxCut/Rq/Drive n'acceptent que \mel et \acid).
const FX_PER_VOICE_SUPPORTED = new Set(["melody", "acid"]);

VOICES.forEach((v) => {
  const card = document.createElement("div");
  card.className = "mixer-voice";
  card.dataset.voice = v;
  const fxBlock = FX_PER_VOICE_SUPPORTED.has(v) ? `
    <div class="voice-fx">
      <label class="ctrl mini">
        <span class="ctrl-row"><span>Cut</span><output class="mono mvfx-out" data-fx="Cut">5000</output></span>
        <input type="range" min="50" max="12000" step="10" value="5000" data-mvfx="Cut" />
      </label>
      <label class="ctrl mini">
        <span class="ctrl-row"><span>Drv</span><output class="mono mvfx-out" data-fx="Drive">1.00</output></span>
        <input type="range" min="0.5" max="5" step="0.05" value="1" data-mvfx="Drive" />
      </label>
      <label class="ctrl mini">
        <span class="ctrl-row"><span>RQ</span><output class="mono mvfx-out" data-fx="Rq">0.50</output></span>
        <input type="range" min="0.05" max="1.5" step="0.01" value="0.5" data-mvfx="Rq" />
      </label>
    </div>` : "";
  card.innerHTML = `
    <div class="playing-dot"></div>
    <div class="name">${v}</div>
    <div class="mixer-body">
      <div class="vu"><div class="vu-fill" data-vu="${v}"></div></div>
      <div class="vfader"><input type="range" min="0" max="1.5" step="0.01" value="1" /></div>
    </div>
    <div class="vol-display">1.00</div>
    <div class="actions">
      <button type="button" class="mute">M</button>
      <button type="button" class="solo">S</button>
    </div>
    <div class="voice-pdef">
      <button type="button" class="pdef-play">▶</button>
      <button type="button" class="pdef-stop">■</button>
    </div>
    ${fxBlock}
  `;
  const slider = card.querySelector('input[type="range"]');
  const display = card.querySelector('.vol-display');
  setSliderFill(slider);
  slider.addEventListener("input", () => {
    setSliderFill(slider);
    const val = parseFloat(slider.value);
    display.textContent = val.toFixed(2);
    send("/control/setVol", v, val);
  });
  card.querySelector('.mute').addEventListener("click", () => {
    if (state.muted.has(v)) {
      state.muted.delete(v);
      card.querySelector('.mute').classList.remove("active");
      send("/control/unmute", v);
    } else {
      state.muted.add(v);
      card.querySelector('.mute').classList.add("active");
      send("/control/mute", v);
    }
  });
  card.querySelector('.solo').addEventListener("click", () => {
    if (state.soloed.has(v)) {
      state.soloed.delete(v);
      card.querySelector('.solo').classList.remove("active");
      send("/control/unsolo");
    } else {
      mixerGrid.querySelectorAll('.solo.active').forEach(b => b.classList.remove("active"));
      state.soloed.clear();
      state.soloed.add(v);
      card.querySelector('.solo').classList.add("active");
      send("/control/solo", v);
    }
  });
  card.querySelector('.pdef-play').addEventListener("click", () => {
    send("/control/playPdef", v + "Seq");
    state.playing.add(v);
    card.classList.add("playing");
  });
  card.querySelector('.pdef-stop').addEventListener("click", () => {
    send("/control/stopPdef", v + "Seq");
    state.playing.delete(v);
    card.classList.remove("playing");
  });
  // FX par voie (Cut / Drive / RQ) directement dans la carte mixer
  card.querySelectorAll('input[data-mvfx]').forEach(el => {
    setSliderFill(el);
    const fx = el.dataset.mvfx;
    const out = card.querySelector(`output.mvfx-out[data-fx="${fx}"]`);
    el.addEventListener("input", () => {
      setSliderFill(el);
      const val = parseFloat(el.value);
      if (out) out.textContent = val < 10 ? val.toFixed(2) : val.toFixed(0);
      send(`/control/fx${fx}`, v, val);
    });
  });
  mixerGrid.appendChild(card);
});

// VU-mètres : smoothing + redraw 30fps
function vuLoop() {
  VOICES.forEach(v => {
    const a = state.amp[v];
    if (!a) return;
    a.current = a.current * 0.7 + a.target * 0.3;
    // Décroissance naturelle si plus de message
    a.target *= 0.92;
    const fill = document.querySelector(`.vu-fill[data-vu="${v}"]`);
    if (fill) {
      const pct = Math.min(100, a.current * 100);
      fill.style.height = pct + "%";
    }
  });
  setTimeout(() => requestAnimationFrame(vuLoop), 33);
}
requestAnimationFrame(vuLoop);

// ---------------- STEPS ---------------------------------------------
const seqGrid = document.getElementById("seqGrid");
SEQ_VOICES.forEach((v) => {
  const lbl = document.createElement("div");
  lbl.className = "seq-label";
  lbl.textContent = v;
  lbl.dataset.voice = v;
  seqGrid.appendChild(lbl);
  for (let i = 0; i < 16; i++) {
    const cell = document.createElement("div");
    cell.className = "seq-cell";
    if (i % 4 === 0) cell.classList.add("divider");
    if (seqState[v][i]) cell.classList.add("on");
    cell.dataset.voice = v;
    cell.dataset.step = i;
    cell.addEventListener("click", () => {
      seqState[v][i] = seqState[v][i] ? 0 : 1;
      cell.classList.toggle("on", !!seqState[v][i]);
      saveSeq();
      if (state.liveEdit) send(`/control/${v}Steps`, ...seqState[v]);
    });
    seqGrid.appendChild(cell);
  }
});

function renderSeqVoice(voice) {
  if (!seqGrid || !seqState[voice]) return;
  const cells = seqGrid.querySelectorAll(`.seq-cell[data-voice="${voice}"]`);
  cells.forEach((cell, i) => {
    cell.classList.toggle("on", !!seqState[voice][i]);
  });
  const label = seqGrid.querySelector(`.seq-label[data-voice="${voice}"]`);
  if (label) {
    label.classList.add("synced");
    setTimeout(() => label.classList.remove("synced"), 600);
  }
}

function updateStepMarker() {
  const cur = state.beatCount;
  document.querySelectorAll(".seq-cell.beat-marker").forEach(c => c.classList.remove("beat-marker"));
  document.querySelectorAll(`.seq-cell[data-step="${cur}"]`).forEach(c => c.classList.add("beat-marker"));
}

document.getElementById("liveEdit").addEventListener("change", (e) => {
  state.liveEdit = e.target.checked;
});
document.querySelectorAll('[data-seq-action]').forEach(b => {
  b.addEventListener("click", () => {
    const a = b.dataset.seqAction;
    if (a === "clear") {
      SEQ_VOICES.forEach(v => seqState[v].fill(0));
      document.querySelectorAll('.seq-cell').forEach(c => c.classList.remove("on"));
      saveSeq();
      if (state.liveEdit) SEQ_VOICES.forEach(v => send(`/control/${v}Steps`, ...seqState[v]));
    }
    if (a === "random") {
      SEQ_VOICES.forEach(v => {
        seqState[v] = Array.from({length: 16}, () => Math.random() < 0.35 ? 1 : 0);
        document.querySelectorAll(`.seq-cell[data-voice="${v}"]`).forEach((c, i) => {
          c.classList.toggle("on", !!seqState[v][i]);
        });
      });
      saveSeq();
      if (state.liveEdit) SEQ_VOICES.forEach(v => send(`/control/${v}Steps`, ...seqState[v]));
    }
    if (a === "send") {
      SEQ_VOICES.forEach(v => send(`/control/${v}Steps`, ...seqState[v]));
    }
  });
});

// ---------------- KICKS / PATTERNS / FF -----------------------------
function makeChips(host, items, oscAddr, opts = {}) {
  const el = document.getElementById(host);
  items.forEach(k => {
    const b = document.createElement("button");
    b.className = "chip";
    b.textContent = k;
    b.addEventListener("click", () => {
      if (opts.exclusive) {
        el.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
        b.classList.add("active");
      }
      send(oscAddr, k);
    });
    el.appendChild(b);
  });
}
makeChips("kicksChips", KICKS, "/control/kk", { exclusive: true });
makeChips("pkitChips", PKITS, "/control/pKit");
makeChips("pgenreChips", PGENRES, "/control/pGenre");
makeChips("ffChips", FF, "/control/ff", { exclusive: true });

// ---------------- FX par voie ---------------------------------------
const FX_VOICES = [
  { name: "melody", cutoff: 5000, drive: 1.0, rq: 0.4 },
  { name: "acid",   cutoff: 1500, drive: 2.0, rq: 0.25 },
  { name: "kick",   cutoff: 5000, drive: 1.0, rq: 0.5 },
  { name: "hat",    cutoff: 8000, drive: 1.0, rq: 0.5 },
];
const fxGrid = document.getElementById("fxGrid");
FX_VOICES.forEach(cfg => {
  const card = document.createElement("div");
  card.className = "fx-voice";
  card.innerHTML = `
    <div class="name">${cfg.name}</div>
    <label class="ctrl">
      <span class="ctrl-row"><span>Cutoff</span><output class="mono">${cfg.cutoff}</output></span>
      <input type="range" min="50" max="12000" step="10" value="${cfg.cutoff}" data-fx="Cut" data-voice="${cfg.name}" />
    </label>
    <label class="ctrl">
      <span class="ctrl-row"><span>Drive</span><output class="mono">${cfg.drive.toFixed(2)}</output></span>
      <input type="range" min="0.5" max="5" step="0.05" value="${cfg.drive}" data-fx="Drive" data-voice="${cfg.name}" />
    </label>
    <label class="ctrl">
      <span class="ctrl-row"><span>RQ</span><output class="mono">${cfg.rq.toFixed(2)}</output></span>
      <input type="range" min="0.05" max="1.5" step="0.01" value="${cfg.rq}" data-fx="Rq" data-voice="${cfg.name}" />
    </label>
  `;
  card.querySelectorAll('input[type="range"]').forEach(el => {
    setSliderFill(el);
    const out = el.parentElement.querySelector("output");
    el.addEventListener("input", () => {
      setSliderFill(el);
      const v = parseFloat(el.value);
      out.textContent = v < 10 ? v.toFixed(2) : v.toFixed(0);
      send(`/control/fx${el.dataset.fx}`, el.dataset.voice, v);
    });
  });
  fxGrid.appendChild(card);
});

// VCF master
VCF_TYPES.forEach(t => {
  const o = document.createElement("option");
  o.value = t; o.textContent = t;
  document.getElementById("vcfType").appendChild(o);
});
VCF_PRESETS.forEach(p => {
  const o = document.createElement("option");
  o.value = p; o.textContent = p;
  document.getElementById("vcfPreset").appendChild(o);
});
const vcfFreq = document.getElementById("vcfFreq");
const vcfQ = document.getElementById("vcfQ");
const outVcfFreq = document.getElementById("outVcfFreq");
const outVcfQ = document.getElementById("outVcfQ");
bindSlider(vcfFreq, (v) => {
  outVcfFreq.textContent = v.toFixed(0);
  send("/control/vcfFreq", v);
});
bindSlider(vcfQ, (v) => {
  outVcfQ.textContent = v.toFixed(2);
  send("/control/vcfQ", v);
});
document.getElementById("btnVcfOn").addEventListener("click", () => {
  const t = document.getElementById("vcfType").value;
  send("/control/vcfOn", t, parseFloat(vcfFreq.value), parseFloat(vcfQ.value));
});
document.getElementById("btnVcfOff").addEventListener("click", () => send("/control/vcfOff"));
document.getElementById("vcfPreset").addEventListener("change", (e) => {
  if (e.target.value) send("/control/vcfPreset", e.target.value);
});
document.getElementById("btnVcfSweep").addEventListener("click", () => {
  const f = parseFloat(document.getElementById("sweepFrom").value);
  const t = parseFloat(document.getElementById("sweepTo").value);
  const d = parseFloat(document.getElementById("sweepDur").value);
  send("/control/vcfSweep", f, t, d);
});

// Comp / Sat
const compChips = document.getElementById("compChips");
COMP_PRESETS.forEach(p => {
  const b = document.createElement("button");
  b.className = "chip"; b.textContent = p;
  b.addEventListener("click", () => {
    compChips.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
    b.classList.add("active");
    send("/control/fxComp", p);
  });
  compChips.appendChild(b);
});
SAT_MODES.forEach(m => {
  const o = document.createElement("option");
  o.value = m; o.textContent = m;
  document.getElementById("satMode").appendChild(o);
});
const satAmount = document.getElementById("satAmount");
const outSat = document.getElementById("outSat");
bindSlider(satAmount, (v) => { outSat.textContent = v.toFixed(2); });
document.getElementById("btnSat").addEventListener("click", () => {
  const m = document.getElementById("satMode").value;
  const a = parseFloat(satAmount.value);
  send("/control/fxSat", m, a);
});

// ---------------- SENDS ---------------------------------------------
const sendsGrid = document.getElementById("sendsGrid");
SEND_BUSES.forEach(([key, label]) => {
  const cell = document.createElement("div");
  cell.className = "send-cell";
  cell.innerHTML = `
    <div class="name">${label} <span class="key">${key}</span></div>
    <input type="range" min="0" max="1" step="0.01" value="0" />
    <div class="ctrl-row"><span class="muted">amount</span><output class="mono">0.00</output></div>
  `;
  const slider = cell.querySelector("input");
  const out = cell.querySelector("output");
  setSliderFill(slider);
  slider.addEventListener("input", () => {
    setSliderFill(slider);
    const v = parseFloat(slider.value);
    out.textContent = v.toFixed(2);
    send("/control/sendFx", key, v);
  });
  sendsGrid.appendChild(cell);
});

// ---------------- LFO -----------------------------------------------
const lfoTarget = document.getElementById("lfoTarget");
const lfoRate = document.getElementById("lfoRate");
const lfoDepth = document.getElementById("lfoDepth");
const outLfoRate = document.getElementById("outLfoRate");
const outLfoDepth = document.getElementById("outLfoDepth");
bindSlider(lfoRate, (v) => outLfoRate.textContent = v.toFixed(2));
bindSlider(lfoDepth, (v) => outLfoDepth.textContent = v.toFixed(0));
document.getElementById("btnLfoOn").addEventListener("click", () => {
  send("/control/lfoTo", lfoTarget.value, parseFloat(lfoRate.value), parseFloat(lfoDepth.value));
});
document.getElementById("btnLfoOff").addEventListener("click", () => {
  send("/control/lfoStop", lfoTarget.value);
});
document.getElementById("btnLfoStopAll").addEventListener("click", () => send("/control/lfoStopAll"));
document.querySelectorAll('#lfoPresets .chip').forEach(c => {
  c.addEventListener("click", () => { lfoTarget.value = c.dataset.lfo; });
});

// ---------------- TRICKS --------------------------------------------
const tricksGrid = document.getElementById("tricksGrid");
TRICKS.forEach(t => {
  const b = document.createElement("button");
  b.className = "btn";
  b.innerHTML = `${t.label}${t.note ? `<small>${t.note}</small>` : ""}`;
  b.addEventListener("click", () => send(t.osc, ...(t.args || [])));
  tricksGrid.appendChild(b);
});

// ---------------- MELODIES (rétrocompat sliders + ~mApply) ----------
const mApplyGrid = document.getElementById("mApplyGrid");
M_KINDS.forEach(kind => {
  const lbl = document.createElement("div");
  lbl.className = "row-label";
  lbl.textContent = kind;
  mApplyGrid.appendChild(lbl);
  for (let n = 1; n <= 8; n++) {
    const b = document.createElement("button");
    b.className = "btn";
    b.textContent = n;
    b.addEventListener("click", () => send("/control/mApply", kind, n));
    mApplyGrid.appendChild(b);
  }
});

const mAmp = document.getElementById("mAmp");
const mCut = document.getElementById("mCut");
const mDrive = document.getElementById("mDrive");
bindSlider(mAmp, v => { document.getElementById("outMAmp").textContent = v.toFixed(2); send("/control/mAmp", v); });
bindSlider(mCut, v => { document.getElementById("outMCut").textContent = v.toFixed(0); send("/control/mCut", v); });
bindSlider(mDrive, v => { document.getElementById("outMDrive").textContent = v.toFixed(2); send("/control/mDrive", v); });

document.getElementById("btnMNx").addEventListener("click", () => send("/control/mNx"));
document.getElementById("btnMPv").addEventListener("click", () => send("/control/mPv"));
document.getElementById("btnMOff").addEventListener("click", () => send("/control/mOff"));

// Genre wrapper rétrocompat (~mGen) : peuplé dynamiquement depuis melodies keys
function renderMGenChips() {
  const root = document.getElementById("mGenChips");
  if (!root) return;
  root.innerHTML = "";
  const keys = Object.keys(catalog.melodies).sort();
  const genres = keys.length ? keys : M_GENRES_FALLBACK;
  genres.forEach(g => {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = g;
    b.addEventListener("click", () => {
      root.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
      send("/control/mGen", g);
    });
    root.appendChild(b);
  });
}

// ---------------- CATALOGUE MÉLODIES (dynamique) --------------------
// Préfixes nommage : m=short, ml=long, mxl=xlong, mepic=epic.
function melLenOfName(name) {
  if (name.startsWith("mepic")) return "epic";
  if (name.startsWith("mxl")) return "xlong";
  if (name.startsWith("ml")) return "long";
  if (name.startsWith("m")) return "short";
  return "short";
}

function melFiltered() {
  const genre = catalog.melGenre;
  if (!genre) return [];
  const all = catalog.melodies[genre] || [];
  const len = catalog.melLen;
  const q = catalog.melSearch.trim().toLowerCase();
  return all.filter(name => {
    if (len !== "all" && melLenOfName(name) !== len) return false;
    if (q && !name.toLowerCase().includes(q)) return false;
    return true;
  });
}

function renderMelGenres() {
  const root = document.getElementById("melGenreChips");
  if (!root) return;
  const keys = Object.keys(catalog.melodies).sort();
  if (!catalog.melGenre || !keys.includes(catalog.melGenre)) {
    catalog.melGenre = keys[0] || null;
  }
  root.innerHTML = "";
  keys.forEach(g => {
    const b = document.createElement("button");
    b.className = "chip" + (g === catalog.melGenre ? " active" : "");
    b.textContent = `${g} (${(catalog.melodies[g] || []).length})`;
    b.addEventListener("click", () => {
      catalog.melGenre = g;
      catalog.melPage = 0;
      saveCatalog();
      renderMelGenres();
      renderMelGrid();
    });
    root.appendChild(b);
  });
  renderMGenChips();
}

function renderMelGrid() {
  const grid = document.getElementById("melGrid");
  const counter = document.getElementById("melCounter");
  const pageLbl = document.getElementById("melPage");
  const activeLbl = document.getElementById("melActive");
  if (!grid) return;
  const list = melFiltered();
  const totalAll = catalog.melGenre ? (catalog.melodies[catalog.melGenre] || []).length : 0;
  const pages = Math.max(1, Math.ceil(list.length / CAT_PAGE_SIZE));
  if (catalog.melPage >= pages) catalog.melPage = pages - 1;
  if (catalog.melPage < 0) catalog.melPage = 0;
  const start = catalog.melPage * CAT_PAGE_SIZE;
  const slice = list.slice(start, start + CAT_PAGE_SIZE);
  grid.innerHTML = "";
  slice.forEach(name => {
    const cell = document.createElement("button");
    cell.className = "cat-cell mono" + (name === catalog.melActive ? " active" : "");
    cell.textContent = name;
    cell.title = name;
    cell.addEventListener("click", () => {
      catalog.melActive = name;
      send("/control/setMelody", name);
      renderMelGrid();
    });
    grid.appendChild(cell);
  });
  if (counter) counter.textContent = `${list.length} / ${totalAll}`;
  if (pageLbl) pageLbl.textContent = `${catalog.melPage + 1} / ${pages}`;
  if (activeLbl) activeLbl.textContent = catalog.melActive ? `▶ ${catalog.melActive}` : "— aucune active —";
}

// Branchement UI Mélodies
(function bindMelodyCatalog() {
  const search = document.getElementById("melSearch");
  if (search) {
    search.value = catalog.melSearch;
    search.addEventListener("input", () => {
      catalog.melSearch = search.value;
      catalog.melPage = 0;
      saveCatalog();
      renderMelGrid();
    });
  }
  document.querySelectorAll("#melLenChips .chip").forEach(b => {
    if (b.dataset.len === catalog.melLen) {
      document.querySelectorAll("#melLenChips .chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
    }
    b.addEventListener("click", () => {
      document.querySelectorAll("#melLenChips .chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
      catalog.melLen = b.dataset.len;
      catalog.melPage = 0;
      saveCatalog();
      renderMelGrid();
    });
  });
  const prev = document.getElementById("melPrev");
  const next = document.getElementById("melNext");
  if (prev) prev.addEventListener("click", () => { catalog.melPage--; renderMelGrid(); });
  if (next) next.addEventListener("click", () => { catalog.melPage++; renderMelGrid(); });
  const refresh = document.getElementById("btnMelRefresh");
  if (refresh) refresh.addEventListener("click", () => send("/control/listMelodies"));
})();

// ---------------- CATALOGUE SYNTHDEFS (dynamique) -------------------
function sdFiltered() {
  const cat = catalog.sdCat;
  const all = catalog.synthdefs[cat] || [];
  const q = catalog.sdSearch.trim().toLowerCase();
  return q ? all.filter(n => n.toLowerCase().includes(q)) : all;
}

function renderSdGrid() {
  const grid = document.getElementById("sdGrid");
  const counter = document.getElementById("sdCounter");
  const pageLbl = document.getElementById("sdPage");
  const activeLbl = document.getElementById("sdActive");
  if (!grid) return;
  const list = sdFiltered();
  const totalAll = (catalog.synthdefs[catalog.sdCat] || []).length;
  const pages = Math.max(1, Math.ceil(list.length / CAT_PAGE_SIZE));
  if (catalog.sdPage >= pages) catalog.sdPage = pages - 1;
  if (catalog.sdPage < 0) catalog.sdPage = 0;
  const start = catalog.sdPage * CAT_PAGE_SIZE;
  const slice = list.slice(start, start + CAT_PAGE_SIZE);
  grid.innerHTML = "";
  slice.forEach(name => {
    const cell = document.createElement("button");
    cell.className = `cat-cell mono cat-${catalog.sdCat}` + (name === catalog.sdActive ? " active" : "");
    cell.textContent = name;
    cell.title = `${catalog.sdCat} · ${name}`;
    cell.addEventListener("click", () => {
      catalog.sdActive = name;
      send("/control/mInst", name);
      renderSdGrid();
    });
    grid.appendChild(cell);
  });
  if (counter) counter.textContent = `${list.length} / ${totalAll}`;
  if (pageLbl) pageLbl.textContent = `${catalog.sdPage + 1} / ${pages}`;
  if (activeLbl) activeLbl.textContent = catalog.sdActive ? `▶ ${catalog.sdActive}` : "— aucun actif —";
}

(function bindSynthdefCatalog() {
  document.querySelectorAll("#sdCatChips .chip").forEach(b => {
    if (b.dataset.cat === catalog.sdCat) {
      document.querySelectorAll("#sdCatChips .chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
    }
    b.addEventListener("click", () => {
      document.querySelectorAll("#sdCatChips .chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
      catalog.sdCat = b.dataset.cat;
      catalog.sdPage = 0;
      saveCatalog();
      renderSdGrid();
    });
  });
  const search = document.getElementById("sdSearch");
  if (search) {
    search.value = catalog.sdSearch;
    search.addEventListener("input", () => {
      catalog.sdSearch = search.value;
      catalog.sdPage = 0;
      saveCatalog();
      renderSdGrid();
    });
  }
  const prev = document.getElementById("sdPrev");
  const next = document.getElementById("sdNext");
  if (prev) prev.addEventListener("click", () => { catalog.sdPage--; renderSdGrid(); });
  if (next) next.addEventListener("click", () => { catalog.sdPage++; renderSdGrid(); });
  const refresh = document.getElementById("btnSdRefresh");
  if (refresh) refresh.addEventListener("click", () => send("/control/listSynthdefs"));
})();

function flashSync(elemId) {
  const el = document.getElementById(elemId);
  if (!el) return;
  el.classList.remove("synced");
  void el.offsetWidth;
  el.classList.add("synced");
  setTimeout(() => el.classList.remove("synced"), 600);
}

// Initial render (vide tant que rien reçu)
renderMelGenres();
renderMelGrid();
renderSdGrid();

// ---------------- ALBUM ---------------------------------------------
const albumsGrid = document.getElementById("albumsGrid");
const albumsPlaceholder = document.getElementById("albumsPlaceholder");
const albumGap = document.getElementById("albumGap");
const outAlbumGap = document.getElementById("outAlbumGap");
bindSlider(albumGap, (v) => { outAlbumGap.textContent = v.toFixed(0); });

function renderAlbumCard(letter) {
  if (albumsPlaceholder && albumsPlaceholder.parentNode) {
    albumsPlaceholder.remove();
  }
  const data = state.albums.get(letter);
  if (!data) return;
  let card = albumsGrid.querySelector(`.album-card[data-letter="${letter}"]`);
  const wasExpanded = card ? card.classList.contains("expanded") : false;
  if (!card) {
    card = document.createElement("div");
    card.className = "album-card";
    card.dataset.letter = letter;
    // Insertion triée par lettre
    const all = Array.from(albumsGrid.querySelectorAll(".album-card"));
    const next = all.find(c => c.dataset.letter > letter);
    if (next) albumsGrid.insertBefore(card, next);
    else albumsGrid.appendChild(card);
  }
  const minutes = Math.round(data.totalSec / 60);
  const tracksHtml = data.slugs.map((slug, i) => {
    const num = String(i + 1).padStart(2, "0");
    const last = state.lastTrack && state.lastTrack.letter === letter && state.lastTrack.n === (i + 1);
    return `<li class="album-track${last ? " last" : ""}" data-n="${i + 1}"><span class="num mono">${num}</span><span class="slug mono">${slug}</span></li>`;
  }).join("");
  card.innerHTML = `
    <div class="album-head">
      <div class="album-badge">${letter}</div>
      <div class="album-meta">
        <div class="album-title">${data.title}</div>
        <div class="album-stats mono">${data.trackCount} tracks · ~${minutes} min</div>
      </div>
    </div>
    <div class="album-actions">
      <button type="button" class="btn accent album-play">▶ Album entier</button>
      <button type="button" class="btn album-toggle">Tracks ▾</button>
    </div>
    <ul class="album-tracks">${tracksHtml}</ul>
  `;
  if (wasExpanded) card.classList.add("expanded");
  card.querySelector(".album-play").addEventListener("click", () => {
    const gap = parseInt(albumGap.value, 10) || 0;
    send("/control/playAlbum", letter, gap);
  });
  card.querySelector(".album-toggle").addEventListener("click", () => {
    card.classList.toggle("expanded");
  });
  card.querySelectorAll(".album-track").forEach(li => {
    li.addEventListener("click", () => {
      const n = parseInt(li.dataset.n, 10);
      state.lastTrack = { letter, n };
      card.querySelectorAll(".album-track.last").forEach(x => x.classList.remove("last"));
      li.classList.add("last");
      send("/control/playTrack", letter, n);
    });
  });
}

document.getElementById("btnAlbumStop").addEventListener("click", () => {
  if (!confirm("Stop album en cours ?")) return;
  send("/control/stopAlbum");
});
document.getElementById("btnAlbumRefresh").addEventListener("click", () => {
  send("/control/listAlbums");
});

// ---------------- JUMP ----------------------------------------------
const jumpLetters = document.getElementById("jumpLetters");
const jumpSectionsCard = document.getElementById("jumpSectionsCard");
const jumpSectionsEl = document.getElementById("jumpSections");
const jumpLetterLabel = document.getElementById("jumpLetterLabel");

TRACKS.forEach(L => {
  const b = document.createElement("button");
  b.className = "btn";
  b.textContent = L;
  b.addEventListener("click", () => {
    state.jumpLetter = L;
    jumpLetters.querySelectorAll(".btn.active").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    renderJumpSections();
  });
  jumpLetters.appendChild(b);
});

function renderJumpSections() {
  const L = state.jumpLetter;
  if (!L) { jumpSectionsCard.hidden = true; return; }
  jumpSectionsCard.hidden = false;
  jumpLetterLabel.textContent = L;
  jumpSectionsEl.innerHTML = "";
  const slugs = state.sectionsByLetter[L] || [];
  if (slugs.length === 0) {
    const m = document.createElement("span");
    m.className = "muted";
    m.textContent = "Aucune section listée — relance /control/listSections.";
    jumpSectionsEl.appendChild(m);
    const r = document.createElement("button");
    r.className = "btn";
    r.textContent = "↻ refresh";
    r.addEventListener("click", () => send("/control/listSections"));
    jumpSectionsEl.appendChild(r);
    return;
  }
  slugs.forEach(slug => {
    const c = document.createElement("button");
    c.className = "chip";
    c.textContent = slug;
    c.addEventListener("click", () => {
      jumpSectionsEl.querySelectorAll(".chip.active").forEach(x => x.classList.remove("active"));
      c.classList.add("active");
      send("/control/jumpTo", L, slug);
    });
    jumpSectionsEl.appendChild(c);
  });
}

// Re-render des sections quand /sync/sections arrive
const origHandle = handleSync;
// (handleSync ré-appelle déjà setSectionsByLetter ; on déclenche un repaint sur l'onglet sélectionné)
const _origMessage = state.ws;
// Patch léger : surveiller les changements via interval (simple, pas critique)
setInterval(() => { if (state.jumpLetter) renderJumpSections(); }, 500);

// ---------------- CHAINS --------------------------------------------
const chainsGrid = document.getElementById("chainsGrid");
CHAINS.forEach(c => {
  const wrap = document.createElement("div");
  wrap.style.display = "flex";
  wrap.style.gap = "0.4rem";
  wrap.style.alignItems = "center";

  const b = document.createElement("button");
  b.className = "btn big";
  b.style.flex = "1";
  b.textContent = c.name;

  if (c.input) {
    const inp = document.createElement("input");
    inp.type = "number";
    inp.value = c.input.value;
    inp.title = c.input.label;
    inp.style.width = "70px";
    b.addEventListener("click", () => {
      const opt = parseInt(inp.value, 10);
      send("/control/chain", c.name, isNaN(opt) ? c.input.value : opt);
    });
    wrap.appendChild(b);
    wrap.appendChild(inp);
  } else {
    b.addEventListener("click", () => send("/control/chain", c.name));
    wrap.appendChild(b);
  }
  chainsGrid.appendChild(wrap);
});

// ---------------- SCENES --------------------------------------------
document.getElementById("btnSaveScene").addEventListener("click", () => {
  const n = document.getElementById("sceneName").value.trim();
  if (!n) { alert("nom requis"); return; }
  send("/control/saveScene", n);
});
document.getElementById("btnLoadScene").addEventListener("click", () => {
  const n = document.getElementById("sceneName").value.trim();
  if (!n) { alert("nom requis"); return; }
  send("/control/loadScene", n);
});
document.querySelectorAll("#scenePresets .chip").forEach(c => {
  c.addEventListener("click", () => {
    const n = c.dataset.preset;
    document.getElementById("sceneName").value = n;
    send("/control/loadScene", n);
  });
});

// ---------------- MASTER RETURNS (in Mixer tab) ---------------------
const masterReturnsGrid = document.getElementById("masterReturnsGrid");
if (masterReturnsGrid) {
  SEND_BUSES.forEach(([key, label]) => {
    const cell = document.createElement("div");
    cell.className = "master-return-cell";
    cell.innerHTML = `
      <div class="name">${label} <span class="key">${key}</span></div>
      <input type="range" min="0" max="1" step="0.01" value="0" />
      <div class="ctrl-row"><span class="muted">amount</span><output class="mono">0.00</output></div>
    `;
    const slider = cell.querySelector("input");
    const out = cell.querySelector("output");
    setSliderFill(slider);
    slider.addEventListener("input", () => {
      setSliderFill(slider);
      const v = parseFloat(slider.value);
      out.textContent = v.toFixed(2);
      send("/control/sendFx", key, v);
    });
    masterReturnsGrid.appendChild(cell);
  });
}

// ---------------- ACID ----------------------------------------------
const acidNotesGrid = document.getElementById("acidNotesGrid");
const acidAccentsGrid = document.getElementById("acidAccentsGrid");
const acidSlidesGrid = document.getElementById("acidSlidesGrid");
const acidLiveCheck = document.getElementById("acidLive");

function flashAcidGrid(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add("synced");
  setTimeout(() => el.classList.remove("synced"), 600);
}

function setAcidSlider(id, value, outId, decimals) {
  const el = document.getElementById(id);
  if (el) { el.value = value; setSliderFill(el); }
  const out = document.getElementById(outId);
  if (out) out.textContent = value.toFixed(decimals);
}

function buildAcidNotesGrid() {
  acidNotesGrid.innerHTML = "";
  for (let i = 0; i < 16; i++) {
    const cell = document.createElement("div");
    cell.className = "acid-cell note";
    if (i % 4 === 0) cell.classList.add("divider");
    const val = acidState.notes[i] | 0;
    if (val > 0) cell.classList.add("on");
    cell.dataset.idx = i;
    cell.textContent = val > 0 ? val : "·";
    cell.addEventListener("click", () => {
      const cur = acidState.notes[i] | 0;
      const idx = ACID_NOTE_CYCLE.indexOf(cur);
      const next = ACID_NOTE_CYCLE[(idx + 1 + ACID_NOTE_CYCLE.length) % ACID_NOTE_CYCLE.length];
      acidState.notes[i] = next;
      cell.textContent = next > 0 ? next : "·";
      cell.classList.toggle("on", next > 0);
      saveAcid();
      if (acidLiveCheck && acidLiveCheck.checked) send("/control/acidNotes", ...acidState.notes);
    });
    cell.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      const cur = acidState.notes[i] | 0;
      const idx = ACID_NOTE_CYCLE.indexOf(cur);
      const prev = ACID_NOTE_CYCLE[(idx - 1 + ACID_NOTE_CYCLE.length) % ACID_NOTE_CYCLE.length];
      acidState.notes[i] = prev;
      cell.textContent = prev > 0 ? prev : "·";
      cell.classList.toggle("on", prev > 0);
      saveAcid();
      if (acidLiveCheck && acidLiveCheck.checked) send("/control/acidNotes", ...acidState.notes);
    });
    acidNotesGrid.appendChild(cell);
  }
}

function renderAcidNotes() {
  if (!acidNotesGrid) return;
  acidNotesGrid.querySelectorAll(".acid-cell.note").forEach((cell, i) => {
    const val = acidState.notes[i] | 0;
    cell.textContent = val > 0 ? val : "·";
    cell.classList.toggle("on", val > 0);
  });
}

function buildAcidToggleRow(grid, arr, kind, color) {
  grid.innerHTML = "";
  for (let i = 0; i < 16; i++) {
    const cell = document.createElement("div");
    cell.className = `acid-cell toggle ${kind}`;
    if (i % 4 === 0) cell.classList.add("divider");
    if (arr[i]) cell.classList.add("on");
    cell.dataset.idx = i;
    cell.addEventListener("click", () => {
      arr[i] = arr[i] ? 0 : 1;
      cell.classList.toggle("on", !!arr[i]);
      saveAcid();
      if (acidLiveCheck && acidLiveCheck.checked) {
        if (kind === "accent") send("/control/acidAccents", ...acidState.accents);
        else send("/control/acidSlides", ...acidState.slides);
      }
    });
    grid.appendChild(cell);
  }
}

function renderAcidAccents() {
  if (!acidAccentsGrid) return;
  acidAccentsGrid.querySelectorAll(".acid-cell.toggle").forEach((c, i) => {
    c.classList.toggle("on", !!acidState.accents[i]);
  });
}

function renderAcidSlides() {
  if (!acidSlidesGrid) return;
  acidSlidesGrid.querySelectorAll(".acid-cell.toggle").forEach((c, i) => {
    c.classList.toggle("on", !!acidState.slides[i]);
  });
}

if (acidNotesGrid) {
  buildAcidNotesGrid();
  buildAcidToggleRow(acidAccentsGrid, acidState.accents, "accent");
  buildAcidToggleRow(acidSlidesGrid, acidState.slides, "slide");

  const acidCut = document.getElementById("acidCut");
  const acidRq = document.getElementById("acidRq");
  const acidDrive = document.getElementById("acidDrive");
  const acidAmp = document.getElementById("acidAmp");
  bindSlider(acidCut, v => {
    document.getElementById("outAcidCut").textContent = v.toFixed(0);
    acidState.cutoff = v; saveAcid(); send("/control/acidCut", v);
  });
  bindSlider(acidRq, v => {
    document.getElementById("outAcidRq").textContent = v.toFixed(2);
    acidState.rq = v; saveAcid(); send("/control/acidRq", v);
  });
  bindSlider(acidDrive, v => {
    document.getElementById("outAcidDrive").textContent = v.toFixed(2);
    acidState.drive = v; saveAcid(); send("/control/acidDrive", v);
  });
  bindSlider(acidAmp, v => {
    document.getElementById("outAcidAmp").textContent = v.toFixed(2);
    acidState.amp = v; saveAcid(); send("/control/acidAmp", v);
  });
  // Init slider values from state
  setAcidSlider("acidCut", acidState.cutoff, "outAcidCut", 0);
  setAcidSlider("acidRq", acidState.rq, "outAcidRq", 2);
  setAcidSlider("acidDrive", acidState.drive, "outAcidDrive", 2);
  setAcidSlider("acidAmp", acidState.amp, "outAcidAmp", 2);

  const accProb = document.getElementById("acidAccProb");
  const sldProb = document.getElementById("acidSldProb");
  bindSlider(accProb, v => { document.getElementById("outAcidAccProb").textContent = v.toFixed(2); });
  bindSlider(sldProb, v => { document.getElementById("outAcidSldProb").textContent = v.toFixed(2); });

  document.getElementById("btnAcidRandom").addEventListener("click", () => {
    send("/control/acidRandom", parseFloat(accProb.value), parseFloat(sldProb.value));
  });
  document.getElementById("btnAcidSend").addEventListener("click", () => {
    send("/control/acidNotes", ...acidState.notes);
    send("/control/acidAccents", ...acidState.accents);
    send("/control/acidSlides", ...acidState.slides);
  });
}

// ---------------- HARMONY -------------------------------------------
const harmonyNotesGrid = document.getElementById("harmonyNotesGrid");
const harmonyLiveCheck = document.getElementById("harmonyLive");
const harmonyPresetChips = document.getElementById("harmonyPresetChips");

function buildHarmonyNotesGrid() {
  harmonyNotesGrid.innerHTML = "";
  for (let i = 0; i < 32; i++) {
    const cell = document.createElement("div");
    cell.className = "harmony-cell";
    if (i % 8 === 0) cell.classList.add("divider");
    const inp = document.createElement("input");
    inp.type = "number";
    inp.min = "0";
    inp.max = "120";
    inp.step = "1";
    inp.value = harmonyState.notes[i] | 0;
    inp.dataset.idx = i;
    inp.addEventListener("input", () => {
      const v = parseInt(inp.value, 10);
      harmonyState.notes[i] = isNaN(v) ? 0 : Math.max(0, Math.min(120, v));
      cell.classList.toggle("on", harmonyState.notes[i] > 0);
      saveHarmony();
      if (harmonyLiveCheck && harmonyLiveCheck.checked) send("/control/harmonyNotes", ...harmonyState.notes);
    });
    if ((harmonyState.notes[i] | 0) > 0) cell.classList.add("on");
    cell.appendChild(inp);
    harmonyNotesGrid.appendChild(cell);
  }
}

function renderHarmonyNotes() {
  if (!harmonyNotesGrid) return;
  harmonyNotesGrid.querySelectorAll(".harmony-cell").forEach((cell, i) => {
    const inp = cell.querySelector("input");
    if (inp) inp.value = harmonyState.notes[i] | 0;
    cell.classList.toggle("on", (harmonyState.notes[i] | 0) > 0);
  });
}

if (harmonyNotesGrid) {
  buildHarmonyNotesGrid();

  const harmonyAmp = document.getElementById("harmonyAmp");
  bindSlider(harmonyAmp, v => {
    document.getElementById("outHarmonyAmp").textContent = v.toFixed(2);
    harmonyState.amp = v; saveHarmony(); send("/control/harmonyAmp", v);
  });
  setAcidSlider("harmonyAmp", harmonyState.amp, "outHarmonyAmp", 2);

  HARMONY_PRESETS.forEach(p => {
    const b = document.createElement("button");
    b.className = "chip";
    b.textContent = p;
    b.addEventListener("click", () => {
      harmonyPresetChips.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
      send("/control/harmonyPreset", p);
    });
    harmonyPresetChips.appendChild(b);
  });

  document.getElementById("btnHarmonySend").addEventListener("click", () => {
    send("/control/harmonyNotes", ...harmonyState.notes);
  });
}

// ---------------- HYDRA tab -----------------------------------------
const HYDRA_PRESETS = [
  "default", "osc", "kaleido", "grid", "warp", "pixel",
  "feedback", "vortex", "liquid", "tunnel", "spectrum", "cellular",
  "glitch", "neon", "wireframe", "noise_storm", "mandala", "ripple",
  "strobe", "mountains", "cosmos",
];
const HYDRA_PARAMS = [
  { name: "intensity", min: 0, max: 2,  step: 0.01, def: 1   },
  { name: "hueShift",  min: 0, max: 1,  step: 0.01, def: 0   },
  { name: "speed",     min: 0, max: 4,  step: 0.01, def: 1   },
  { name: "density",   min: 0, max: 2,  step: 0.01, def: 1   },
  { name: "feedback",  min: 0, max: 1,  step: 0.01, def: 0.5 },
];

(function initHydraTab() {
  const chips = document.getElementById("hydraPresets");
  if (!chips) return;
  HYDRA_PRESETS.forEach(name => {
    const b = document.createElement("button");
    b.className = "chip";
    b.textContent = name;
    b.addEventListener("click", () => {
      chips.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
      b.classList.add("active");
      send("/hydra/preset", name);
    });
    chips.appendChild(b);
  });

  const params = document.getElementById("hydraParams");
  HYDRA_PARAMS.forEach(p => {
    const wrap = document.createElement("label");
    wrap.style.display = "flex";
    wrap.style.flexDirection = "column";
    wrap.style.gap = "0.2rem";
    wrap.style.fontSize = "0.75rem";
    wrap.style.minWidth = "120px";
    const valSpan = document.createElement("span");
    valSpan.textContent = `${p.name} = ${p.def}`;
    const slider = document.createElement("input");
    slider.type = "range";
    slider.min = p.min; slider.max = p.max; slider.step = p.step; slider.value = p.def;
    slider.addEventListener("input", () => {
      const v = parseFloat(slider.value);
      valSpan.textContent = `${p.name} = ${v}`;
      send("/hydra/param", p.name, v);
    });
    wrap.appendChild(valSpan);
    wrap.appendChild(slider);
    params.appendChild(wrap);
  });

  document.getElementById("btnHydraSendCode").addEventListener("click", () => {
    const code = document.getElementById("hydraCode").value.trim();
    if (code.length > 0) send("/hydra/code", code);
  });
})();

// ---------------- Init final ----------------------------------------
// Underline calé après render initial (fonts, layout)
window.addEventListener("load", () => requestAnimationFrame(positionUnderline));

// =====================================================================
// LIVE PADS — 30 boutons mappés sur les 3 rangées qwerty / asdf / zxcv
// =====================================================================
const LIVE_PADS = [
  // Row 1 — CHAINS (cyan)
  { key: "q", label: "INTRO",   sub: "chain",      kind: "chain",  arg: "intro"     },
  { key: "w", label: "DROP",    sub: "chain",      kind: "chain",  arg: "drop"      },
  { key: "e", label: "BRK",     sub: "breakdown",  kind: "chain",  arg: "breakdown" },
  { key: "r", label: "BLD ×4",  sub: "buildup",    kind: "chain",  arg: "buildup", arg2: 4 },
  { key: "t", label: "BLD ×8",  sub: "buildup",    kind: "chain",  arg: "buildup", arg2: 8 },
  { key: "y", label: "TECHNO",  sub: "chain",      kind: "chain",  arg: "techno",  arg2: 4 },
  { key: "u", label: "DNB",     sub: "chain",      kind: "chain",  arg: "dnb",     arg2: 4 },
  { key: "i", label: "FADE",    sub: "outro fade", kind: "chain",  arg: "outroFade", arg2: 16 },
  { key: "o", label: "C-STOP",  sub: "chain stop", kind: "chain",  arg: "stop"      },
  { key: "p", label: "PLAY",    sub: "playAll",    kind: "playAll" },

  // Row 2 — ONESHOTS (orange)
  { key: "a", label: "RISER",   sub: "FX trick",  kind: "synth",  arg: "riser"   },
  { key: "s", label: "STOP",    sub: "stopAll",   kind: "stopAll" },
  { key: "d", label: "SN-FILL", sub: "fill",      kind: "fn",     arg: "snareFill" },
  { key: "f", label: "TM-FILL", sub: "fill",      kind: "fn",     arg: "tomFill"   },
  { key: "g", label: "SWEEP",   sub: "down",      kind: "synth",  arg: "sweep"   },
  { key: "h", label: "CRASH",   sub: "FX trick",  kind: "synth",  arg: "crash"   },
  { key: "j", label: "GONG",    sub: "FX trick",  kind: "synth",  arg: "gong"    },
  { key: "k", label: "IMPACT",  sub: "FX trick",  kind: "synth",  arg: "impact"  },
  { key: "l", label: "TAP",     sub: "BPM tap",   kind: "tap" },
  { key: ";", label: "RANDOM",  sub: "tweak",     kind: "fn",     arg: "randomTweak" },

  // Row 3 — MUTES + FX (purple)
  { key: "z", label: "KICK",    sub: "mute",      kind: "muteToggle", voice: "kick"    },
  { key: "x", label: "HAT",     sub: "mute",      kind: "muteToggle", voice: "hat"     },
  { key: "c", label: "SNARE",   sub: "mute",      kind: "muteToggle", voice: "snare"   },
  { key: "v", label: "CLAP",    sub: "mute",      kind: "muteToggle", voice: "clap"    },
  { key: "b", label: "PERC",    sub: "mute",      kind: "muteToggle", voice: "perc"    },
  { key: "n", label: "ACID",    sub: "mute",      kind: "muteToggle", voice: "acid"    },
  { key: "m", label: "MELODY",  sub: "mute",      kind: "muteToggle", voice: "melody"  },
  { key: ",", label: "HARMONY", sub: "mute",      kind: "muteToggle", voice: "harmony" },
  { key: ".", label: "UNSOLO",  sub: "clear",     kind: "unsolo" },
  { key: "/", label: "PING",    sub: "round-trip",kind: "ping" },
];

const liveMuteState = new Set();   // voices currently muted

function firePad(pad, padEl) {
  switch (pad.kind) {
    case "chain":
      if (pad.arg2 != null) send("/control/chain", pad.arg, pad.arg2);
      else                   send("/control/chain", pad.arg);
      break;
    case "playAll":  send("/control/playAll");  break;
    case "stopAll":  send("/control/stopAll");  break;
    case "synth":    send("/control/triggerSynth", pad.arg); break;
    case "fn":       send("/control/" + pad.arg);             break;
    case "tap":      document.getElementById("btnTap")?.click(); break;
    case "ping":     send("/control/ping");     break;
    case "unsolo":   send("/control/unsolo");   break;
    case "muteToggle": {
      if (liveMuteState.has(pad.voice)) {
        send("/control/unmute", pad.voice);
        liveMuteState.delete(pad.voice);
        padEl?.classList.remove("muted");
      } else {
        send("/control/mute", pad.voice);
        liveMuteState.add(pad.voice);
        padEl?.classList.add("muted");
      }
      break;
    }
  }
  if (padEl) {
    padEl.classList.remove("hit");
    void padEl.offsetWidth;
    padEl.classList.add("hit");
  }
}

(function initLivePads() {
  const host = document.getElementById("livePads");
  if (!host) return;
  const byKey = new Map();
  LIVE_PADS.forEach(pad => {
    const el = document.createElement("button");
    const sectionClass =
      LIVE_PADS.indexOf(pad) < 10 ? "live-pad-chain" :
      LIVE_PADS.indexOf(pad) < 20 ? "live-pad-shot"  :
                                    "live-pad-mute";
    el.className = `live-pad ${sectionClass}`;
    el.dataset.key = pad.key;
    if (pad.voice) el.dataset.voice = pad.voice;
    el.innerHTML =
      `<div class="live-pad-label">${pad.label}</div>` +
      `<div class="live-pad-sub">${pad.sub}</div>` +
      `<div class="live-pad-key">${pad.key.toUpperCase()}</div>`;
    el.addEventListener("click", () => firePad(pad, el));
    host.appendChild(el);
    byKey.set(pad.key, { pad, el });
  });

  // Keyboard handling — only when the Live tab is active. Overrides the
  // global keymap (tab nav, refresh, stop, help) for the duration of
  // the tab. Always honors Esc, ?/h, m for fallthrough.
  document.addEventListener("keydown", (ev) => {
    const t = ev.target;
    if (t.matches?.("input, textarea, select, [contenteditable=true]")) return;
    if (ev.metaKey || ev.ctrlKey || ev.altKey) return;

    const liveTab = document.querySelector('.tabpane[data-tab="tab-live"]');
    const isLive = liveTab && liveTab.classList.contains("active");
    if (!isLive) return;

    const pair = byKey.get(ev.key.toLowerCase());
    if (!pair) return;
    firePad(pair.pad, pair.el);
    ev.preventDefault();
    ev.stopPropagation();
  }, true);  // capture phase so we win against the global handler
})();
