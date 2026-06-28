# Matrix Audio-Reactive Glow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each matrix grid cell under the playhead glow in time with its voice's notes, proportional to that voice's amplitude, decaying over ~200 ms.

**Architecture:** SC emits a per-note OSC pulse `/matrix/trig <vi> <amp>` by injecting a side-effect key into the matrix's existing `~matVariation` Pchain overlay (no audio-graph and no `launchpad.scd` changes). The web client models a fast-attack / exponential-decay envelope per voice in a `requestAnimationFrame` loop and applies it as a CSS glow on the cell currently under the playhead. The decay math lives in a standalone ESM module so it is unit-testable under `node:test`.

**Tech Stack:** SuperCollider (sclang), vanilla browser JS (classic `control.js` + one ESM helper module), CSS custom properties, Node `node:test`.

## Global Constraints

- SC env vars are lowercase `~xxx` (uppercase parses as a class name). — from sound_algo/CLAUDE.md
- Every `.scd` edit must keep parens/brackets balanced: `awk` balance P:0 B:0. — from sound_algo/CLAUDE.md
- SC code comments in English; no emojis. — from CLAUDE.md
- No audio-graph / mixer / SynthDef / `Out.ar` changes (Approach A constraint). — from design spec
- No `web_realart/server.js` change: `/matrix/trig` matches the existing `/matrix/` feedback prefix and is relayed automatically. — from design spec
- Commit subject <= 50 chars, no underscore in scope, no AI attribution, no `--no-verify`. — from CLAUDE.md
- `web_realart` is `"type": "module"`; new test files use `node:test` + `node:assert` like `web_realart/test/bridge.test.mjs`. — from package.json

---

### Task 1: SC per-note trigger emission

Add `~matEmitTrig` and wire it into `~matVariation` so every matrix-driven note
emits `/matrix/trig <vi> <amp>` over the same `~toscSend` path that already
carries `/matrix/playhead` and `/matrix/cell`.

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (add `~matEmitTrig`; add `vi` param + `\matGlow` key to `~matVariation` at lines 47-72; update the `~matApplyBar` call at line 88)
- Test: `sound_algo/data_only/test/test_matrix.scd` (extend existing headless test)

**Interfaces:**
- Produces: `~matEmitTrig.(vi, amp)` — `vi` Integer voice index, `amp` Float; clips `amp` to 0..1 and calls `~toscSend.("/matrix/trig", vi, ampClipped)`.
- Produces: `~matVariation.(name, color, vi=0)` — now takes a third arg `vi`; still returns a `Pattern` (Pchain) for color 1-6, `nil` for color 0.
- Consumes: `~toscSend.(path, ...args)` (defined in `touchosc_feedback.scd`; stubbed in the test).

- [ ] **Step 1: Write the failing test**

Insert the following block into `sound_algo/data_only/test/test_matrix.scd` immediately
before the final `pass.if(` block (currently line 65). It asserts `~matEmitTrig`
exists and clips amplitude:

```supercollider
// ~matEmitTrig must be defined and emit /matrix/trig with amp clipped to 0..1
pass = pass and: { ~matEmitTrig.notNil };
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };  // capturing stub
try {
    ~matEmitTrig.(3, 1.5)
} { |e|
    pass = false;
    ("EXCEPTION in ~matEmitTrig: " ++ e.class.name).postln
};
pass = pass and: { ~trigLog.notNil };
pass = pass and: { ~trigLog[0] == "/matrix/trig" };
pass = pass and: { ~trigLog[1] == 3 };
pass = pass and: { ~trigLog[2] == 1.0 };   // 1.5 clipped to 1.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: prints `TEST FAIL` (because `~matEmitTrig` is nil before implementation).

- [ ] **Step 3: Add `~matEmitTrig` to matrix.scd**

Insert this helper into `sound_algo/data_only/matrix.scd` right after the
`~matPush` definition (after line 107, before `~matStop`):

```supercollider
// -- ~matEmitTrig : push a per-note amplitude pulse to web/TouchOSC clients --
// vi = voice index, amp clipped to 0..1. Same ~toscSend path as /matrix/playhead.
~matEmitTrig = { |vi, amp|
    ~toscSend !? { ~toscSend.("/matrix/trig", vi, amp.clip(0, 1)) }
};
```

- [ ] **Step 4: Inject the glow key into `~matVariation`**

Replace the `~matVariation` definition (lines 47-72) so it takes a `vi` arg and
adds a `\matGlow` side-effect key as the FIRST key of the overlay Pbind. Because
`Pchain(overlay, base)` evaluates `base` first, the overlay's first key reads the
base event's real `\amp` (velocity x ~lpVol) before the variation overwrites it:

```supercollider
~matVariation = { |name, color, vi = 0|
    (color == 0).if({ nil }, {
        var base = ~matBaseFor.(name);
        base.notNil.if({
            var spec = [
                nil,
                (stretch: 1.0, octave:  0, amp: 1.0),
                (stretch: 0.5, octave:  0, amp: 1.0),
                (stretch: 1.0, octave:  1, amp: 1.0),
                (stretch: 2.0, octave:  0, amp: 1.0),
                (stretch: 1.0, octave: -1, amp: 1.05),
                (stretch: 0.5, octave:  0, amp: 1.2)
            ][color];
            spec.notNil.if({
                Pchain(
                    Pbind(
                        \matGlow, Pfunc { |e|
                            ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1));
                            0
                        },
                        \stretch, spec[\stretch],
                        \octave,  spec[\octave],
                        \amp,     spec[\amp]
                    ),
                    base
                )
            }, { base })
        }, { nil })
    })
};
```

- [ ] **Step 5: Pass `vi` from `~matApplyBar`**

In `~matApplyBar`, update the `~matVariation` call (currently line 88) to forward
the voice index `vi` (already in scope from the `~matVoices.do { |name, vi| ...}`):

```supercollider
                        var pat = ~matVariation.(name, color, vi);
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: prints `TEST PASS` with no `ERROR` / `EXCEPTION` lines.

- [ ] **Step 7: Verify paren/bracket balance**

Run: `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
Expected: `P:0 B:0`

- [ ] **Step 8: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: emit per-note matrix trigger for glow"
```

---

### Task 2: Web glow decay helper (pure + tested)

Create the standalone decay module and its unit test. No DOM, no rAF — just the
math, so it runs under `node:test`.

**Files:**
- Create: `web_realart/public/control/matrix_glow.js` (ESM module)
- Test: `web_realart/test/matrix_glow.test.mjs`

**Interfaces:**
- Produces: `nextGlow(level, dtMs)` -> Float. Exponential decay of `level` over
  `dtMs` milliseconds, normalized to a 60 fps frame. Returns `0` once the level
  falls to/below `GLOW_MIN`.
- Produces: `GLOW_DECAY` (Number, per-60fps-frame multiplier) and `GLOW_MIN` (Number).

- [ ] **Step 1: Write the failing test**

Create `web_realart/test/matrix_glow.test.mjs`:

```javascript
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
  for (let t = 0; t < 300; t += 1000 / 60) lvl = nextGlow(lvl, 1000 / 60);
  assert.strictEqual(lvl, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_realart && node --test test/matrix_glow.test.mjs`
Expected: FAIL — `Cannot find module '../public/control/matrix_glow.js'`.

- [ ] **Step 3: Create the module**

Create `web_realart/public/control/matrix_glow.js`:

```javascript
// Matrix audio-reactive glow — pure decay math (Approach A, trigger envelope).
// Imported directly by node:test; surfaced to the classic control.js via a
// one-line module shim in index.html (window.MatrixGlow).
export const GLOW_DECAY = 0.86; // per-60fps-frame multiplier (~200 ms visible tail)
export const GLOW_MIN = 0.02;   // floor: at/below this, the glow is treated as 0

// Exponential decay of `level` over dtMs milliseconds, normalized to 60 fps.
export function nextGlow(level, dtMs) {
  if (level <= GLOW_MIN) return 0;
  const decayed = level * Math.pow(GLOW_DECAY, dtMs / (1000 / 60));
  return decayed <= GLOW_MIN ? 0 : decayed;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd web_realart && node --test test/matrix_glow.test.mjs`
Expected: PASS — 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add web_realart/public/control/matrix_glow.js web_realart/test/matrix_glow.test.mjs
git commit -m "feat: add matrix glow decay helper"
```

---

### Task 3: Wire glow into the web grid

Consume `/matrix/trig`, drive a per-voice envelope with `nextGlow`, and render it
as a CSS halo on the active cell. DOM/rAF wiring has no automated harness here, so
this task ends with explicit manual verification (the math is already covered by
Task 2).

**Files:**
- Modify: `web_realart/public/control/index.html:166` (add module shim before `control.js`)
- Modify: `web_realart/public/control/control.js` (add glow state + WS handler, after the matrix render block ~line 255, and the handler inside the `ws` message listener ~line 163)
- Modify: `web_realart/public/control/control.css:115-116` (extend `.mcell.playing`)

**Interfaces:**
- Consumes: `window.MatrixGlow.nextGlow`, `cellRefs[bar][vi]`, `matPlayhead`, `MATRIX_VOICES` (all already in `control.js`).
- Produces: `triggerGlow(vi, amp)` and a self-suspending `requestAnimationFrame` loop that sets the `--glow` CSS custom property on the playhead column's cells.

- [ ] **Step 1: Add the module shim to index.html**

In `web_realart/public/control/index.html`, replace line 166:

```html
<script src="control.js"></script></body></html>
```

with (load the ESM helper first and expose it as a global for the classic script):

```html
<script type="module">import * as G from "./matrix_glow.js"; window.MatrixGlow = G;</script>
<script src="control.js"></script></body></html>
```

- [ ] **Step 2: Add the glow engine to control.js**

In `web_realart/public/control/control.js`, immediately after the `renderMatrix()`
function (after its closing brace at line 255), add:

```javascript
// --- Matrix audio-reactive glow (trigger envelope; math in matrix_glow.js) ---
const voiceLevel = new Array(16).fill(0);
let glowRaf = null;
let glowLastTs = 0;
let glowAppliedBar = -1;

function clearGlowColumn(bar) {
  if (bar < 0) return;
  for (let vi = 0; vi < MATRIX_VOICES.length; vi++) {
    const el = cellRefs[bar][vi];
    if (el) el.style.removeProperty("--glow");
  }
}

function glowFrame(ts) {
  const decay = window.MatrixGlow ? window.MatrixGlow.nextGlow : (l) => 0;
  const dt = glowLastTs ? (ts - glowLastTs) : (1000 / 60);
  glowLastTs = ts;
  if (matPlayhead !== glowAppliedBar) {
    clearGlowColumn(glowAppliedBar);
    glowAppliedBar = matPlayhead;
  }
  let anyActive = false;
  for (let vi = 0; vi < 16; vi++) {
    const lvl = decay(voiceLevel[vi], dt);
    voiceLevel[vi] = lvl;
    if (matPlayhead >= 0) {
      const el = cellRefs[matPlayhead][vi];
      if (el) {
        if (lvl > 0) el.style.setProperty("--glow", lvl.toFixed(3));
        else el.style.removeProperty("--glow");
      }
    }
    if (lvl > 0) anyActive = true;
  }
  if (anyActive) {
    glowRaf = requestAnimationFrame(glowFrame);
  } else {
    clearGlowColumn(glowAppliedBar);
    glowRaf = null;
    glowLastTs = 0;
    glowAppliedBar = -1;
  }
}

function triggerGlow(vi, amp) {
  if (!Number.isInteger(vi) || vi < 0 || vi >= 16) return;
  const a = Math.max(0, Math.min(1, amp));
  if (a <= 0) return;
  voiceLevel[vi] = Math.max(voiceLevel[vi], a);
  if (glowRaf === null) {
    glowLastTs = 0;
    glowRaf = requestAnimationFrame(glowFrame);
  }
}
```

- [ ] **Step 3: Add the `/matrix/trig` WS handler**

In `control.js`, inside the `ws.addEventListener("message", ...)` body, add this
block right after the `/matrix/cell` handler's closing `}` (after line 163,
before the listener's closing `});`):

```javascript
  // /matrix/trig <vi> <amp> — per-note pulse: glow the active cell of voice vi
  if (address === "/matrix/trig") {
    triggerGlow(Math.round(Number(args[0])), Number(args[1]));
    return;
  }
```

- [ ] **Step 4: Add the glow CSS**

In `web_realart/public/control/control.css`, replace the `.mcell.playing` rule
(lines 115-116) with a version that adds a `--glow`-scaled halo and brightness.
At `--glow: 0` it is visually identical to the current rule:

```css
.mcell.playing { box-shadow: 0 0 0 2px rgba(255,255,255,0.28),
  inset 0 0 0 1px rgba(255,255,255,0.40),
  0 0 calc(var(--glow, 0) * 12px) calc(var(--glow, 0) * 4px)
    rgba(255,255,255, calc(var(--glow, 0) * 0.7));
  filter: brightness(calc(1 + var(--glow, 0) * 0.9)); }
```

- [ ] **Step 5: Manual verification in the browser**

Boot the data-only SC engine (so `~toscSend` reaches the web server), start the
web server, and exercise the matrix:

```bash
cd web_realart && npm start
```

Then in the browser control page (Matrix tab):
1. Paint a few cells across several voices (kick row, hats row).
2. Press PLAY.
3. Confirm: as the playhead sweeps, the painted cell under the playhead pulses
   brightly on each note, hi-hat cells flicker faster than kick, and the glow
   fades within ~200-300 ms after the last hit.
4. Press STOP and confirm all glow halos fade out and no cell stays lit.

Expected: cells pulse in time with the audio; the white ring on the playhead
column is unchanged when no note is sounding (`--glow` = 0).

- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/index.html web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: render audio-reactive glow on matrix grid"
```

---

## Self-Review

**Spec coverage:**
- SC per-voice per-note emission over existing OSC path -> Task 1. ✓
- No audio-graph / server.js change -> Task 1 (variation overlay only), constraint honored; no server.js task. ✓
- Web envelope model + active-cell glow + rAF self-suspend -> Task 3. ✓
- Pure decay helper extracted + tested -> Task 2. ✓
- Off cells (color 0) never glow -> Task 1: color 0 returns nil (no overlay, no emit); Task 3: `triggerGlow` only fires on the playhead column and a non-painted cell receives no trig. ✓
- Decay tail ~200 ms, attack = max() -> Task 2 (`GLOW_DECAY`/`GLOW_MIN`), Task 3 (`triggerGlow`). ✓
- Future Approach B documented -> in the spec, intentionally no task. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓

**Type consistency:** `~matEmitTrig.(vi, amp)` signature identical in Task 1 emission and the `~matVariation` call site. `nextGlow(level, dtMs)` identical between Task 2 (definition/test) and Task 3 (`decay(voiceLevel[vi], dt)`). `triggerGlow(vi, amp)` defined in Task 3 Step 2 and called in Task 3 Step 3. `--glow` custom property written in Task 3 Step 2 and consumed in Task 3 Step 4. ✓
