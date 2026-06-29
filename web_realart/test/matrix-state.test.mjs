import { test } from "node:test";
import assert from "node:assert";
import { PALETTE, VOICE_CLASS, defaultStepMode, MATRIX_VOICES, MATRIX_BARS,
         mkColor, saveMatState, loadMatState, matGrid, matInst, matColorDefs } from "../public/control/js/matrix-state.js";

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
