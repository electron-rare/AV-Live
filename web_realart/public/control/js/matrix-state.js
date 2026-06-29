// matrix-state.js — pure data layer for the AV-Live matrix arranger.
// No DOM access. Consumed by main.js and future modules.

const MATRIX_STORAGE_KEY = "avlive.matrix";

export const MATRIX_VOICES = [
  "kick","hats","clap","perc","sub","acid","arp","lead",
  "stab","pad","ride","rim","tom","reese","bells","sweep",
  "melody","chord","fx","snare","crash","shaker"
];

export const MATRIX_BARS = 64;

// Per-voice curated instrument options (must mirror SC ~matInstChoices).
// Note-terminating synths only — the continuous do_ drones never free per-note.
export const MATRIX_INST_CHOICES = {
  kick:["lp_kick","tr909_kick","tr808_kick","sp1200","do_kick","do_quake_sub"], hats:["lp_hat","tr909_hat","tr808_hat","sp1200","do_hat"],
  clap:["lp_clap","tr909_clap","tr808_clap","sp1200","lp_rim"], perc:["lp_perc","tr808_cowbell","sp1200","akai_s","do_strike"],
  sub:["lp_sub","sh101","minimoog","system100","lp_reese"],
  acid:["lp_acid","tb303","ms20","system100","lp_pluck"], arp:["lp_pluck","tb303","supersaw","juno","do_strike"],
  lead:["lp_pluck","ms20","supersaw","do_plane","sh101"], stab:["lp_pluck","ms20","supersaw","tb303","lp_acid"],
  pad:["lp_pad","juno","supersaw","ms20","lp_reese"], ride:["lp_ride","tr909_ride","lp_hat","do_hat"],
  rim:["lp_rim","tr808_cowbell","tr909_clap","sp1200"], tom:["lp_tom","sp1200","do_strike","do_quake_sub"],
  reese:["lp_reese","ms20","minimoog","system100","supersaw"],
  bells:["lp_bells","dx7","akai_s","do_plane"], sweep:["lp_sweep","akai_s","lp_pad","lp_reese"],
  melody:["lp_pluck","supersaw","ms20","sh101","dx7"], chord:["lp_pad","juno","supersaw","ms20"],
  fx:["lp_fx","akai_s","lp_sweep"], snare:["lp_snare","tr909_clap","tr808_clap","lp_clap"],
  crash:["lp_crash","tr909_ride","akai_s"], shaker:["lp_shaker","tr909_hat","tr808_hat"]
};

export const MOD_SOURCE_ORDER = [
  "lHandY","rHandY","lHandX","rHandX","lOpen","rOpen","handSpeed","handDist",
  "bodyX","bodyY","depth","bodyVitesse","bodyAccel","bodySym","headX","headY",
  "limbSpan","danse","mouthOpen"
];
export const MATRIX_MOD_SOURCES = ["none", ...MOD_SOURCE_ORDER];

export const MOD_SOURCE_LABELS = {
  none:"—",
  lHandY:"Main G ↕", rHandY:"Main D ↕", lHandX:"Main G ↔", rHandX:"Main D ↔",
  lOpen:"Main G ouvert", rOpen:"Main D ouvert", handSpeed:"Vitesse mains", handDist:"Écart mains",
  bodyX:"Corps ↔", bodyY:"Corps ↕", depth:"Profondeur",
  bodyVitesse:"Vitesse corps", bodyAccel:"Accél. corps", bodySym:"Symétrie",
  headX:"Tête ↔", headY:"Tête ↕", limbSpan:"Envergure", danse:"Danse (proba)", mouthOpen:"Bouche"
};
export const MOD_TARGET_LABELS = { none:"—", amp:"volume", cutoff:"cutoff", pan:"pan", rev:"reverb" };

// Curated pose/event dropdown. id is the SC poseId symbol; __custom__ reveals a text input.
export const POSE_EVENT_CHOICES = [
  { id:"danse", label:"Danse" }, { id:"debout", label:"Debout" }, { id:"assise", label:"Assise" },
  { id:"fingerL1", label:"Frappe MG pouce" },  { id:"fingerL2", label:"Frappe MG index" },
  { id:"fingerL3", label:"Frappe MG majeur" }, { id:"fingerL4", label:"Frappe MG annul." },
  { id:"fingerL5", label:"Frappe MG auric." },
  { id:"fingerR1", label:"Frappe MD pouce" },  { id:"fingerR2", label:"Frappe MD index" },
  { id:"fingerR3", label:"Frappe MD majeur" }, { id:"fingerR4", label:"Frappe MD annul." },
  { id:"fingerR5", label:"Frappe MD auric." },
  { id:"pinchL1", label:"Pincement MG index" }, { id:"pinchL2", label:"Pincement MG majeur" },
  { id:"pinchL3", label:"Pincement MG annul." }, { id:"pinchL4", label:"Pincement MG auric." },
  { id:"pinchR1", label:"Pincement MD index" }, { id:"pinchR2", label:"Pincement MD majeur" },
  { id:"pinchR3", label:"Pincement MD annul." }, { id:"pinchR4", label:"Pincement MD auric." },
  { id:"__custom__", label:"Personnalisé…" }
];

export const MATRIX_MOD_TARGETS = {
  kick:["none","amp","pan","rev"], hats:["none","amp","pan","rev"], clap:["none","amp","pan","rev"], perc:["none","amp","cutoff","pan","rev"],
  sub:["none","amp","pan","rev"], acid:["none","amp","cutoff","pan","rev"], arp:["none","amp","cutoff","pan","rev"],
  lead:["none","amp","cutoff","pan","rev"], stab:["none","amp","cutoff","pan","rev"], pad:["none","amp","cutoff","pan","rev"],
  ride:["none","amp","pan","rev"], rim:["none","amp","pan","rev"], tom:["none","amp","pan","rev"], reese:["none","amp","cutoff","pan","rev"],
  bells:["none","amp","pan","rev"], sweep:["none","amp","pan","rev"],
  melody:["none","amp","cutoff","pan","rev"], chord:["none","amp","cutoff","pan","rev"],
  fx:["none","amp","pan","rev"], snare:["none","amp","pan","rev"],
  crash:["none","amp","pan","rev"], shaker:["none","amp","pan","rev"]
};

// Canonical 6-colour palette for the matrix grid (index 1-6, 0 = off).
export const PALETTE = ["#c22","#1a8","#25b","#990","#c60","#82a"];

// Voice classification: "drum" | "melodic" | "semi"
export const VOICE_CLASS = {
  kick:"drum",  hats:"drum",   clap:"drum",    perc:"semi",    sub:"melodic", acid:"melodic",
  arp:"melodic", lead:"melodic", stab:"melodic", pad:"melodic",  ride:"drum",  rim:"drum",
  tom:"semi",   reese:"melodic", bells:"melodic", sweep:"drum",  melody:"melodic",
  chord:"melodic", fx:"drum",  snare:"drum",   crash:"drum",   shaker:"drum",
};

export function isMelodic(v) { return VOICE_CLASS[v] === "melodic"; }
export function defaultStepMode(v) { return VOICE_CLASS[v] === "melodic" ? "pitch" : "drum"; }

// Color-definition factory. res/rev are reserved extension fields (future use).
export const mkColor = (stretch, octave, amp, inst, cutoff, pan) =>
  ({stretch, octave, amp, inst, cutoff, pan, mod:null, pose:[], steps:new Array(16).fill(null), res:null, rev:null});

// --- Mutable state ---
// Exported as named `let` bindings so consumers read live values via import.
// Reassignments happen only inside this module (loadMatState / resetMatGrid),
// so ES-module live-binding semantics are sufficient — main.js never rebinds.
// Exception: the matrix-clear button originally did `matGrid = newArray` in
// main.js; that is now delegated to resetMatGrid() exported below.

export let matInst = new Array(MATRIX_VOICES.length).fill("default");

export let matColorDefs = Array.from({ length: MATRIX_VOICES.length }, () =>
  [null,
   mkColor(1.0, 0, 1.0,"default",-1,-2),
   mkColor(0.5, 0, 1.0,"default",-1,-2),
   mkColor(1.0, 1, 1.0,"default",-1,-2),
   mkColor(2.0, 0, 1.0,"default",-1,-2),
   mkColor(1.0,-1, 1.05,"default",-1,-2),
   mkColor(0.5, 0, 1.2,"default",-1,-2)]);

export let matGrid = Array.from({ length: MATRIX_VOICES.length }, () => new Array(MATRIX_BARS).fill(0));

// Reset matGrid to all-zeros (used by the clear button in main.js instead of
// direct reassignment, which is forbidden on an imported binding).
export function resetMatGrid() {
  matGrid = Array.from({ length: MATRIX_VOICES.length }, () => new Array(MATRIX_BARS).fill(0));
}

// --- Per-voice mod/pose state (live bindings, separate from per-colour matColorDefs) ---
export let matVoiceMods  = Array.from({ length: MATRIX_VOICES.length }, () => []); // [{source,target,depth}]
export let matVoicePoses = Array.from({ length: MATRIX_VOICES.length }, () => []); // [{poseId,action}]
export function resetVoiceMaps() {
  matVoiceMods  = Array.from({ length: MATRIX_VOICES.length }, () => []);
  matVoicePoses = Array.from({ length: MATRIX_VOICES.length }, () => []);
}

export function parseVoiceMod(args) {
  const vi = Math.round(Number(args[0]));
  const n = Math.round(Number(args[1]));
  const list = [];
  for (let k = 0; k < n; k++) {
    const b = 2 + k * 3;
    list.push({ source: String(args[b]), target: String(args[b + 1]), depth: Number(args[b + 2]) });
  }
  return { vi, list };
}
export function parseVoicePose(args) {
  const vi = Math.round(Number(args[0]));
  const n = Math.round(Number(args[1]));
  const list = [];
  for (let k = 0; k < n; k++) {
    const b = 2 + k * 2;
    list.push({ poseId: String(args[b]), action: String(args[b + 1]) });
  }
  return { vi, list };
}
export function parseModValues(args) {
  const m = {};
  for (let i = 0; i < MOD_SOURCE_ORDER.length; i++) m[MOD_SOURCE_ORDER[i]] = Number(args[i]) || 0;
  return m;
}

export function saveMatState() {
  try { localStorage.setItem(MATRIX_STORAGE_KEY,
    JSON.stringify({ grid: matGrid, inst: matInst, cdef: matColorDefs,
                     vmod: matVoiceMods, vpose: matVoicePoses })); } catch (_e) {}
}

export function loadMatState() {
  try {
    const raw = JSON.parse(localStorage.getItem(MATRIX_STORAGE_KEY));
    if (raw && Array.isArray(raw.grid) && raw.grid.length === MATRIX_VOICES.length) { matGrid = raw.grid;
      if (Array.isArray(raw.inst) && raw.inst.length === MATRIX_VOICES.length) matInst = raw.inst;
      if (Array.isArray(raw.cdef) && raw.cdef.length === MATRIX_VOICES.length) {
        matColorDefs = raw.cdef;
        for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
          for (let c = 1; c <= 6; c++) {
            if (matColorDefs[vi][c]) {
              if (!matColorDefs[vi][c].steps) matColorDefs[vi][c].steps = new Array(16).fill(null);
              if (!matColorDefs[vi][c].pose)  matColorDefs[vi][c].pose  = [];
              if (matColorDefs[vi][c].mod  === undefined) matColorDefs[vi][c].mod  = null;
              if (matColorDefs[vi][c].res  === undefined) matColorDefs[vi][c].res  = null;
              if (matColorDefs[vi][c].rev  === undefined) matColorDefs[vi][c].rev  = null;
            }
          }
        }
      }
      // Restore voice mod/pose display caches when present with correct length.
      // SC remains authoritative; these are UI display caches only.
      if (Array.isArray(raw.vmod) && raw.vmod.length === MATRIX_VOICES.length) matVoiceMods = raw.vmod;
      if (Array.isArray(raw.vpose) && raw.vpose.length === MATRIX_VOICES.length) matVoicePoses = raw.vpose;
      return; }
    if (Array.isArray(raw) && raw.length === MATRIX_VOICES.length) { matGrid = raw; return; }   // legacy: bare grid
  } catch (_e) {}
  matGrid = Array.from({ length: MATRIX_VOICES.length }, () => new Array(MATRIX_BARS).fill(0));
}
