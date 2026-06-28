import { test } from "node:test";
import assert from "node:assert";
import { nextGlow, GLOW_DECAY, GLOW_MIN } from "../public/control/matrix_glow.js";

test("one 60fps frame decays by exactly GLOW_DECAY", () => {
  const frame = 1000 / 60;
  assert.ok(Math.abs(nextGlow(1, frame) - GLOW_DECAY) < 1e-9);
});

test("decay is frame-rate independent (two half-frames ~= one frame)", () => {
  const frame = 1000 / 60;
  const oneStep = nextGlow(1, frame);
  const twoSteps = nextGlow(nextGlow(1, frame / 2), frame / 2);
  assert.ok(Math.abs(oneStep - twoSteps) < 1e-9);
});

test("level at or below GLOW_MIN snaps to 0", () => {
  assert.strictEqual(nextGlow(GLOW_MIN, 1000 / 60), 0);
  assert.strictEqual(nextGlow(GLOW_MIN / 2, 1000 / 60), 0);
});

test("a full level decays to 0 within ~300 ms", () => {
  let lvl = 1;
  for (let t = 0; t < 450; t += 1000 / 60) lvl = nextGlow(lvl, 1000 / 60);
  assert.strictEqual(lvl, 0);
});
