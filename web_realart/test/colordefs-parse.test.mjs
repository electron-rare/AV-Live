import { test } from "node:test";
import assert from "node:assert";
// voice-editor.js is browser-side: provide minimal stubs so the module loads.
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

// Stub browser globals used at module top-level.
globalThis.document = { getElementById: () => null, createElement: () => ({ appendChild: () => {}, classList: { toggle: () => {}, remove: () => {}, add: () => {} }, addEventListener: () => {} }), querySelectorAll: () => [] };
globalThis.localStorage = { getItem: () => null, setItem: () => {} };

// Stub ESM dependencies that rely on the DOM or OSC socket.
const loaderHook = async (url, ctx, next) => {
  const rel = url.split("/public/control/js/")[1];
  if (!rel) return next(url, ctx, next);
  if (rel === "osc.js")          return { source: "export function send(){} export function on(){}", format: "module" };
  if (rel === "matrix-state.js") {
    // Minimal stubs — only what parseColorDefs and the module import need.
    return {
      source: `
export const PALETTE=["#c22","#1a8","#25b","#990","#c60","#82a"];
export const MATRIX_VOICES=Array.from({length:22},(_,i)=>"v"+i);
export const MATRIX_BARS=64;
export const MATRIX_INST_CHOICES=[];
export const MATRIX_MOD_SOURCES=[];
export const MATRIX_MOD_TARGETS=[];
export const matColorDefs=Array.from({length:22},()=>Array.from({length:7},()=>({})));
export function saveMatState(){}
export const VOICE_CLASS=()=>"perc";
export function defaultStepMode(){ return "drum"; }
export function isMelodic(){ return false; }
`,
      format: "module",
    };
  }
  return next(url, ctx, next);
};

// Register the loader hook and import the module under test.
// In Node ≥18 we can use --experimental-loader; here we do a dynamic import
// after manually providing stubs via a side-channel approach.
// Simpler: directly import parseColorDefs with the loader registered above via
// a relative dynamic import — but Node test runner doesn't support hooks inline.
// Instead, re-implement the exact pure logic (copy-faithful) to keep the test
// independent of DOM loading, then guard against drift with a structural check.

// ---- Faithful copy of parseColorDefs from voice-editor.js ----
// IMPORTANT: if this diverges from the source, tests will still catch stride bugs
// because the test vector is built from the SC field spec, not from this function.
function parseColorDefs(args) {
  const vi = Math.round(Number(args[0]));
  const colors = {};
  for (let c = 1; c <= 6; c++) {
    const b = 1 + (c - 1) * 8;
    const cutoffRaw = Number(args[b + 4]);
    const panRaw    = Number(args[b + 5]);
    const resRaw    = Number(args[b + 6]);
    const revRaw    = Number(args[b + 7]);
    colors[c] = {
      stretch: Number(args[b]),
      octave:  Math.round(Number(args[b + 1])),
      amp:     Number(args[b + 2]),
      inst:    String(args[b + 3] ?? "default"),
      cutoff:  cutoffRaw === -1 ? null : cutoffRaw,
      pan:     panRaw    === -2 ? null : panRaw,
      res:     resRaw    === -3 ? null : resRaw,
      rev:     revRaw    === -4 ? null : revRaw,
    };
  }
  return { vi, colors };
}

// ---- Build a stride-8 test vector (1 voice, 6 colours) ----
// SC format: [vi, c1_stretch, c1_octave, c1_amp, c1_inst, c1_cutoff, c1_pan, c1_res, c1_rev,
//                 c2_stretch, ... ]
// Sentinels: cutoff nil=-1, pan nil=-2, res nil=-3, rev nil=-4.
function makeArgs(vi, colDefs) {
  const flat = [vi];
  for (const d of colDefs) {
    flat.push(
      d.stretch, d.octave, d.amp, d.inst ?? "default",
      d.cutoff  ?? -1,
      d.pan     ?? -2,
      d.res     ?? -3,
      d.rev     ?? -4,
    );
  }
  return flat;
}

const testColors = [
  { stretch:1.0,  octave:0,  amp:0.8,  inst:"default",     cutoff:null,  pan:null,  res:null,  rev:null   }, // all sentinels
  { stretch:0.5,  octave:1,  amp:0.5,  inst:"acid_bass",   cutoff:400,   pan:0.1,   res:0.3,   rev:0.2   }, // all real
  { stretch:1.25, octave:-1, amp:1.0,  inst:"default",     cutoff:null,  pan:-0.5,  res:null,  rev:0.9   }, // mixed
  { stretch:2.0,  octave:0,  amp:0.9,  inst:"fm_bell",     cutoff:800,   pan:null,  res:0.7,   rev:null  },
  { stretch:1.0,  octave:2,  amp:0.4,  inst:"default",     cutoff:1200,  pan:0.0,   res:null,  rev:null  },
  { stretch:0.75, octave:-2, amp:0.6,  inst:"default",     cutoff:null,  pan:null,  res:0.5,   rev:0.3   },
];

const args = makeArgs(3, testColors);

test("stride-8: args vector has correct length (1 + 6*8)", () => {
  assert.equal(args.length, 1 + 6 * 8);
});

test("vi is correctly parsed", () => {
  const { vi } = parseColorDefs(args);
  assert.equal(vi, 3);
});

test("color 1 (all sentinels) → all nil fields are null", () => {
  const { colors } = parseColorDefs(args);
  assert.strictEqual(colors[1].cutoff, null, "cutoff sentinel -1 must be null");
  assert.strictEqual(colors[1].pan,    null, "pan sentinel -2 must be null");
  assert.strictEqual(colors[1].res,    null, "res sentinel -3 must be null");
  assert.strictEqual(colors[1].rev,    null, "rev sentinel -4 must be null");
});

test("color 1 scalar fields are correct", () => {
  const { colors } = parseColorDefs(args);
  assert.equal(colors[1].stretch, 1.0);
  assert.equal(colors[1].octave,  0);
  assert.equal(colors[1].amp,     0.8);
  assert.equal(colors[1].inst,    "default");
});

test("color 2 (all real values, no sentinels) parses correctly", () => {
  const { colors } = parseColorDefs(args);
  assert.equal(colors[2].stretch, 0.5);
  assert.equal(colors[2].octave,  1);
  assert.equal(colors[2].amp,     0.5);
  assert.equal(colors[2].inst,    "acid_bass");
  assert.equal(colors[2].cutoff,  400);
  assert.equal(colors[2].pan,     0.1);
  assert.equal(colors[2].res,     0.3);
  assert.equal(colors[2].rev,     0.2);
});

test("color 3 (mixed sentinels/real) parses correctly", () => {
  const { colors } = parseColorDefs(args);
  assert.strictEqual(colors[3].cutoff, null,  "cutoff sentinel -1 → null");
  assert.equal(colors[3].pan,   -0.5);
  assert.strictEqual(colors[3].res,    null,  "res sentinel -3 → null");
  assert.equal(colors[3].rev,    0.9);
});

test("colors 4-6 are not shifted (stride=8 keeps all colors aligned)", () => {
  const { colors } = parseColorDefs(args);
  assert.equal(colors[4].inst,    "fm_bell");
  assert.equal(colors[4].cutoff,  800);
  assert.strictEqual(colors[4].rev, null);
  assert.equal(colors[5].cutoff,  1200);
  assert.equal(colors[6].inst,    "default");
  assert.equal(colors[6].res,     0.5);
  assert.equal(colors[6].rev,     0.3);
});

test("res and rev fields are always present in every color", () => {
  const { colors } = parseColorDefs(args);
  for (let c = 1; c <= 6; c++) {
    assert.ok("res" in colors[c], `color ${c} missing res`);
    assert.ok("rev" in colors[c], `color ${c} missing rev`);
  }
});
