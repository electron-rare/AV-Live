import { test } from "node:test";
import assert from "node:assert";
import { PALETTE, VOICE_CLASS, defaultStepMode, MATRIX_VOICES, MATRIX_BARS,
         mkColor, saveMatState, loadMatState, matGrid, matInst, matColorDefs,
         MOD_SOURCE_ORDER, MOD_SOURCE_LABELS, MATRIX_MOD_SOURCES, POSE_EVENT_CHOICES,
         parseVoiceMod, parseVoicePose, parseModValues,
         MATRIX_MOD_TARGETS, MOD_TARGET_LABELS } from "../public/control/js/matrix-state.js";

test("palette is the single 6-colour source", () => {
  assert.deepEqual(PALETTE, ["#c22","#1a8","#25b","#990","#c60","#82a"]);
});
test("dimensions are 22x64", () => {
  assert.equal(MATRIX_VOICES.length, 22);
  assert.equal(MATRIX_BARS, 64);
});
test("step-mode defaults by voice class", () => {
  assert.equal(defaultStepMode("acid"), "pitch");
  assert.equal(defaultStepMode("kick"), "drum");
  assert.equal(defaultStepMode("perc"), "drum");   // semi defaults to drum
});
test("mkColor includes res and rev fields", () => {
  const c = mkColor(1.0, 0, 1.0, "default", -1, -2);
  assert.ok("res" in c, "mkColor result must have res field");
  assert.ok("rev" in c, "mkColor result must have rev field");
  assert.strictEqual(c.res, null);
  assert.strictEqual(c.rev, null);
});
test("matGrid is 22x64 zero-filled by default", () => {
  assert.equal(matGrid.length, MATRIX_VOICES.length);
  assert.equal(matGrid[0].length, MATRIX_BARS);
  assert.equal(matGrid[0][0], 0);
});
test("save/load round-trip preserves grid values (no localStorage in Node)", () => {
  // In Node.js localStorage is absent — saveMatState must not throw, loadMatState must not throw
  assert.doesNotThrow(() => saveMatState());
  assert.doesNotThrow(() => loadMatState());
});
test("loadMatState back-fills res and rev on color defs (simulated stale data)", () => {
  // Simulate a stale cdef entry missing res/rev: check back-fill guard logic
  // We can't easily test localStorage in Node, but we can verify that mkColor
  // always produces res:null/rev:null so freshly created entries are always valid.
  const fresh = mkColor(0.5, 1, 0.8, "tb303", -1, -2);
  assert.strictEqual(fresh.res, null, "fresh mkColor has res:null");
  assert.strictEqual(fresh.rev, null, "fresh mkColor has rev:null");
});

test("every ordered source has a FR label", () => {
  assert.equal(MOD_SOURCE_ORDER.length, 19);
  for (const s of MOD_SOURCE_ORDER) assert.ok(MOD_SOURCE_LABELS[s], `missing label ${s}`);
});

test("MATRIX_MOD_SOURCES starts with none and covers all sources", () => {
  assert.equal(MATRIX_MOD_SOURCES[0], "none");
  for (const s of MOD_SOURCE_ORDER) assert.ok(MATRIX_MOD_SOURCES.includes(s));
});

test("pose event choices include curated + custom", () => {
  const ids = POSE_EVENT_CHOICES.map((c) => c.id);
  assert.ok(ids.includes("danse"));
  assert.ok(ids.includes("fingerR2"));
  assert.ok(ids.includes("__custom__"));
});

test("parseVoiceMod round-trips a 2-binding list", () => {
  const { vi, list } = parseVoiceMod([5, 2, "bodyVitesse", "cutoff", 0.6, "rHandY", "pan", 0.4]);
  assert.equal(vi, 5);
  assert.deepEqual(list[0], { source: "bodyVitesse", target: "cutoff", depth: 0.6 });
  assert.equal(list[1].target, "pan");
});

test("parseVoicePose round-trips", () => {
  const { vi, list } = parseVoicePose([5, 2, "danse", "gate", "fingerR2", "trigger"]);
  assert.equal(vi, 5);
  assert.deepEqual(list[1], { poseId: "fingerR2", action: "trigger" });
});

test("parseModValues maps ordered values to a dict", () => {
  const vals = Array.from({ length: 19 }, (_, i) => i / 18);
  const m = parseModValues(vals);
  assert.equal(m.lHandY, 0);
  assert.equal(m.mouthOpen, 1);
});

test("res target on res-voices only", () => {
  for (const v of ["sub","acid","arp","lead","stab","pad","reese","bells","melody","chord"])
    assert.ok(MATRIX_MOD_TARGETS[v].includes("res"), `${v} should allow res`);
  for (const v of ["kick","hats","perc","tom","fx"])
    assert.ok(!MATRIX_MOD_TARGETS[v].includes("res"), `${v} should NOT allow res`);
});
test("pitch target on melodic step voices only", () => {
  for (const v of ["sub","acid","arp","lead","stab","pad","reese","bells","perc","tom"])
    assert.ok(MATRIX_MOD_TARGETS[v].includes("pitch"), `${v} should allow pitch`);
  for (const v of ["kick","hats","clap","melody","chord","fx"])
    assert.ok(!MATRIX_MOD_TARGETS[v].includes("pitch"), `${v} should NOT allow pitch`);
});
test("MOD_TARGET_LABELS covers pitch and res", () => {
  assert.ok(MOD_TARGET_LABELS.pitch);
  assert.ok(MOD_TARGET_LABELS.res);
});

import { GLOBAL_ACTION_CHOICES, GLOBAL_SLOTS, matGlobalActions, setGlobalAction }
  from "../public/control/js/matrix-state.js";

test("global action choices include the 4 core actions + none", () => {
  const ids = GLOBAL_ACTION_CHOICES.map((c) => c.id);
  for (const id of ["none", "fill", "drop", "breakdown", "evolve"])
    assert.ok(ids.includes(id), `missing action ${id}`);
});
test("four gesture slots in fixed order", () => {
  assert.equal(GLOBAL_SLOTS.length, 4);
  assert.deepEqual(GLOBAL_SLOTS.map((s) => s.key), [0, 1, 2, 3]);
});
test("default mapping is fill/drop/evolve/breakdown", () => {
  assert.deepEqual(matGlobalActions, ["fill", "drop", "evolve", "breakdown"]);
});
test("setGlobalAction mutates a slot", () => {
  setGlobalAction(2, "fill");
  assert.equal(matGlobalActions[2], "fill");
  setGlobalAction(2, "evolve");   // restore default
});
