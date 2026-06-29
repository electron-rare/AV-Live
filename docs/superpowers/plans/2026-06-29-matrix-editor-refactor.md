# Matrix Instrument + Colour Editor Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tangled per-voice instrument + per-(voice,colour) modal editor with an inline-accordion, tabbed voice editor (adaptive pitch/drum step sequencer + synth/FX tab), split `control.js` into ES modules, and extend the SC engine with per-colour `res`/`rev`.

**Architecture:** Three phases. **A** extends `matrix.scd` (res/rev colour-def fields) — backend, testable headless. **B** splits `control.js` (1151 lines) into ES modules with **behaviour unchanged** (the old modal still works) — pure refactor, verifiable by smoke test. **C** replaces the modal with the inline accordion + tabs + adaptive step editor + synth/FX tab. Each phase ships working software.

**Tech Stack:** Vanilla JS ES modules (no bundler/framework/build step), Node `--test` for pure-logic unit tests, Playwright (Chrome) for browser smoke, SuperCollider (`sclang`) headless for engine tests. WebSocket→OSC bridge via `web_realart/server.js`.

## Global Constraints

- Vanilla **ES modules only** — no bundler, no framework, no build step. `index.html` loads `<script type="module" src="js/main.js">`.
- **OSC protocol addresses unchanged**. Only the `colordef` field set gains `res`/`rev` values. SC side stays backward-compatible (missing fields → nil).
- **localStorage key `avlive.matrix` shape preserved**: `{grid, inst, cdef}`; colour defs may gain optional `res`/`rev` (back-filled to `null` on load).
- **22 voices × 64 bars** (`MATRIX_BARS = 64`). Fix stale "16×32" comments.
- **Single colour palette source of truth**: `['#c22','#1a8','#25b','#990','#c60','#82a']` (m1..m6).
- Code, comments, commits, docs in **English**.
- Commits: subject ≤ 50 chars, body ≤ 72/line, **no AI attribution**, **no underscore in scope**, never `--no-verify` (git hooks enforce).
- SC convention: env vars `~lowercase`; `.load` files one top-level block; balance parens (P:0 B:0).
- Run SC with `/Applications/SuperCollider.app/Contents/MacOS/sclang`.
- Work on `main` (consolidated at `04ff9ce`). The user iterates in parallel — coordinate before large edits.

---

## Phase A — Engine extension (res / rev)

### Task A1: Add per-colour `res` and `rev` to the matrix engine

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matDefaultColorDefs` ~l.48-56; `~matVariationOverlay` ~l.178-213; `~matColorStepPattern` ~l.218-250; `~matLoadFile` field-copy ~l.629; `~matSave` ~l.584)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: colour-def Events now carry `res` (Float|nil) and `rev` (Float 0..1|nil). Pushed to the Pbind as `\res`/`\rev` when non-nil and the voice supports them. OSC `/matrix/colordef vi colour \res value` and `\rev` accepted (no new address). `/matrix/colordefs` bulk push gains two trailing fields per colour.
- Consumes: existing SynthDef args `res`, `rev` (verified present on `tb303, ms20, minimoog, supersaw, juno, lp_acid, lp_lead, lp_pad`).

- [ ] **Step 1: Add a res-capable voice set near the top of matrix.scd**

After `~matModNeutralCut` (~l.45), add:

```supercollider
// voices whose SynthDef has a resonant filter (res param). rev (reverb send)
// is accepted by all lp_/classic synths, so it is not gated by voice.
~matResVoices = ~matResVoices ? [\sub, \acid, \arp, \lead, \stab, \pad, \reese, \bells, \melody, \chord];
```

- [ ] **Step 2: Add res/rev to default colour defs**

In `~matDefaultColorDefs` (~l.50-55), add `res: nil, rev: nil,` to each of the six colour Events (after `pan: nil,`). Example for colour 1:

```supercollider
(stretch: 1.0, octave: 0, amp: 1.0, inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil)),
```

- [ ] **Step 3: Push \res and \rev in the overlay variation**

In `~matVariationOverlay`, where `cdPairs` is assembled (the `cutoff`/`pan` block ~l.270-273 in `~matVariation`; mirror it inside the overlay's `cdPairs`), add after the pan push:

```supercollider
(spec[\res].notNil and: { ~matResVoices.includes(name) }).if({
    cdPairs = cdPairs ++ [\res, spec[\res]] });
(spec[\rev].notNil).if({
    cdPairs = cdPairs ++ [\rev, spec[\rev]] });
```

(Place this in the same scope that builds `cdPairs` for both overlay and step paths — in `~matVariation` ~l.269-273, so both render modes inherit it.)

- [ ] **Step 4: Restore res/rev on load**

In `~matLoadFile`, the per-colour field copy loop (~l.629) currently lists `[\stretch, \octave, \amp, \inst, \cutoff, \pan]`. Change to:

```supercollider
[\stretch, \octave, \amp, \inst, \cutoff, \pan, \res, \rev].do { |f|
    d[f].notNil.if({ ~matColorDefs[vi][ci + 1][f] = d[f] })
};
```

- [ ] **Step 5: Include res/rev in the colordefs OSC push**

Find `~matColorDefPush` (~l.499-508). It flattens per-colour fields to `/matrix/colordefs`. Add `res` and `rev` to the flattened field list (append after `pan`), keeping the receiver (`control.js`) arg layout in sync — document the new per-colour stride in a comment (was 6 scalars: stretch,octave,amp,cutoff,pan,+? → now include res,rev). Quote the exact existing layout before editing and extend it by two.

- [ ] **Step 6: Add test assertions**

In `test/test_matrix.scd`, after the existing colordef test, add:

```supercollider
// res/rev round-trip through a colour def
~matColorDefs[5][1][\res] = 0.7;   // acid, colour 1
~matColorDefs[5][1][\rev] = 0.3;
variation = ~matVariation.(\acid, 1, 5);
pass = pass and: { variation.notNil and: { variation.isKindOf(Pattern) } };
// stream one event, must not raise
try { variation.asStream.next(()) } { |e| pass = false;
    ("EXCEPTION res/rev stream: " ++ e.errorString).postln };
```

- [ ] **Step 7: Run the engine test**

Run: `cd sound_algo/data_only && /Applications/SuperCollider.app/Contents/MacOS/sclang test/test_matrix.scd 2>&1 | grep -iE "TEST PASS|FAIL|ERROR"`
Expected: `TEST PASS`, no ERROR lines.

- [ ] **Step 8: Re-validate the 28 presets against the extended engine**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang /private/tmp/.../scratchpad/validate_presets.scd 2>&1 | grep -iE "Loaded OK|PASS|FAIL"` (or recreate the validator: interpret + `~matLoadFile` each `matrix_presets/*.matrix`, assert 28/28 load).
Expected: `Loaded OK via ~matLoadFile: 28 / 28`, `VALIDATION PASS`.

- [ ] **Step 9: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: per-colour res and rev in matrix engine"
```

---

## Phase B — Modularisation (behaviour unchanged)

Goal of Phase B: `control.js` becomes `js/main.js` importing focused modules; the **UI and behaviour are byte-for-byte equivalent** (old modal still works). No feature change. Verify by browser smoke after each extraction. Order: most-isolated first.

### Task B1: Bootstrap ES modules + OSC module with dispatch registry

**Files:**
- Create: `web_realart/public/control/js/osc.js`
- Create: `web_realart/public/control/js/main.js`
- Modify: `web_realart/public/control/index.html` (l.190: `<script src="control.js">` → `<script type="module" src="js/main.js">`)
- Modify: `web_realart/public/control/control.js` → moved verbatim to `js/main.js` initially, minus the WS plumbing (which moves to osc.js).

**Interfaces:**
- Produces (`osc.js`): `export function send(address, ...args)`; `export function on(address, handler)` registers a handler `(args:Array)=>void`; `export function onOpen(fn)`; internal single `ws` dispatches incoming `{address,args}` to all registered handlers for that address. `send` JSON-encodes `{address,args}`.

- [ ] **Step 1: Write osc.js**

```js
// js/osc.js — WebSocket↔OSC bridge with an address dispatch registry.
const ws = new WebSocket(`ws://${location.host}`);
const handlers = new Map();       // address -> Set<fn(args)>
const openFns = [];

export function on(address, fn) {
  if (!handlers.has(address)) handlers.set(address, new Set());
  handlers.get(address).add(fn);
}
export function onOpen(fn) { openFns.push(fn); }
export function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
ws.addEventListener("open", () => openFns.forEach((f) => f()));
ws.addEventListener("message", (ev) => {
  let msg; try { msg = JSON.parse(ev.data); } catch (_e) { return; }
  const set = handlers.get(msg.address);
  if (set) for (const fn of set) fn(msg.args || []);
});
```

- [ ] **Step 2: Move control.js → js/main.js and rewire transport**

`git mv web_realart/public/control/control.js web_realart/public/control/js/main.js`. At the top of `main.js` add `import { send, on, onOpen } from "./osc.js";`. Delete the old `ws`/`send`/`dot` declarations (l.1-7) and the `ws.addEventListener("message", …)` mega-switch (l.34-286): replace each `if (address === "/x") { … }` branch with `on("/x", (args) => { … })` registrations (mechanical: the branch body becomes the handler body; `args[i]` references already match). Replace the `ws.addEventListener("open", …)` with `onOpen(() => send("/matrix/list"))`.

- [ ] **Step 3: Point index.html at the module**

`index.html` l.190: replace `<script src="control.js"></script>` with `<script type="module" src="js/main.js"></script>`. The `matrix_glow.js` import line (l.189) stays.

- [ ] **Step 4: Browser smoke test**

Run the bridge (`cd web_realart && node server.js`) with SC booted (or stub), open `http://localhost:4400/control/`. Verify: page loads with no console errors, tabs switch, matrix grid renders, clicking a cell sends `/matrix/cell` (check Network/console), the colordef modal still opens. Expected: identical behaviour to before.

- [ ] **Step 5: Commit**

```bash
git add web_realart/public/control/
git commit -m "refactor: split osc transport into es module"
```

### Task B2: Extract matrix-state.js (data, palette, persistence, classification)

**Files:**
- Create: `web_realart/public/control/js/matrix-state.js`
- Modify: `js/main.js` (remove the moved declarations; import from matrix-state)
- Test: `web_realart/test/matrix-state.test.mjs`

**Interfaces:**
- Produces: `export const MATRIX_VOICES` (22), `MATRIX_BARS = 64`, `MATRIX_INST_CHOICES`, `MATRIX_MOD_SOURCES`, `MATRIX_MOD_TARGETS`, `PALETTE` (`['#c22','#1a8','#25b','#990','#c60','#82a']`), `VOICE_CLASS` (`{kick:'drum', acid:'melodic', perc:'semi', …}`), `mkColor()`, `matGrid`, `matInst`, `matColorDefs` (exported as mutable via accessor object `state`), `saveMatState()`, `loadMatState()`, `isMelodic(voice)`, `defaultStepMode(voice)` (`'pitch'|'drum'`).

- [ ] **Step 1: Write the failing unit test**

```js
// web_realart/test/matrix-state.test.mjs
import { test } from "node:test";
import assert from "node:assert";
import { PALETTE, VOICE_CLASS, defaultStepMode, MATRIX_VOICES, MATRIX_BARS } from "../public/control/js/matrix-state.js";

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
```

- [ ] **Step 2: Run it, verify it fails**

Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: FAIL — cannot import (module not created yet).

- [ ] **Step 3: Create matrix-state.js**

Move from `main.js` l.288-367 verbatim: `MATRIX_VOICES`, `MATRIX_INST_CHOICES`, `MATRIX_MOD_SOURCES/TARGETS`, `matInst`, `matColorDefs`, `mkColor`, `matGrid`, `MATRIX_BARS`, `saveMatState`, `loadMatState` (drop `cellRefs`/`matPlayhead`/`cdEditVoice` — those stay UI-side). Add and export:

```js
export const PALETTE = ["#c22","#1a8","#25b","#990","#c60","#82a"];
export const VOICE_CLASS = {
  kick:"drum", hats:"drum", clap:"drum", perc:"semi", sub:"melodic", acid:"melodic",
  arp:"melodic", lead:"melodic", stab:"melodic", pad:"melodic", ride:"drum", rim:"drum",
  tom:"semi", reese:"melodic", bells:"melodic", sweep:"drum", melody:"melodic",
  chord:"melodic", fx:"drum", snare:"drum", crash:"drum", shaker:"drum",
};
export function isMelodic(v) { return VOICE_CLASS[v] === "melodic"; }
export function defaultStepMode(v) { return VOICE_CLASS[v] === "melodic" ? "pitch" : "drum"; }
```
Make the mutable arrays exported `let` with named exports, or wrap in an exported `state` object — pick the pattern `main.js` can consume cleanly. Add `res:null, rev:null` to `mkColor()`'s returned shape, and back-fill them in `loadMatState` alongside steps/pose/mod.

- [ ] **Step 4: Run the test, verify it passes**

Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Import into main.js, smoke test browser**

Replace moved declarations in `main.js` with `import { … } from "./matrix-state.js";`. Browser smoke (as B1 Step 4): identical behaviour.

- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/js/matrix-state.js web_realart/public/control/js/main.js web_realart/test/matrix-state.test.mjs
git commit -m "refactor: extract matrix state and palette module"
```

### Task B3: Single palette via CSS custom properties

**Files:**
- Modify: `web_realart/public/control/control.css` (`.mcell.m1..m6` l.109-114; `.cd-row.m*`/`.seq-row.m*` l.178-192)
- Modify: `js/matrix-state.js` (write CSS vars from `PALETTE` at load)

**Interfaces:** Consumes `PALETTE` from matrix-state. Produces CSS vars `--m1..--m6` on `:root`.

- [ ] **Step 1: Emit CSS vars from PALETTE**

In `matrix-state.js`, add and call once on import:

```js
export function installPaletteVars() {
  const r = document.documentElement.style;
  PALETTE.forEach((c, i) => r.setProperty(`--m${i + 1}`, c));
}
installPaletteVars();
```

- [ ] **Step 2: Replace hard-coded colours in CSS with vars**

`control.css`: change `.mcell.m1 { background:#c22; border-color:#e44; }` … to `.mcell.m1 { background:var(--m1); border-color:var(--m1); filter:brightness(1.2); }` for m1..m6 (keep a readable border via `brightness`). Do the same for `.cd-row.m*` / `.seq-row.mN .seq-cell.on`. Remove the now-duplicate hex values.

- [ ] **Step 3: Remove the JS COLORS array**

In the (now in voice-editor / still in main) `renderColorSel`, replace the local `const COLORS = [...]` with `import { PALETTE } from "./matrix-state.js"` usage. (If still in main.js at this point, import there.)

- [ ] **Step 4: Browser smoke** — cells m1..m6 and the colour selector render with identical colours. Expected: visually unchanged.

- [ ] **Step 5: Commit**

```bash
git add web_realart/public/control/
git commit -m "refactor: single colour palette via css vars"
```

### Task B4: Extract mixer.js, transport.js, scenes.js, sequencer.js, launchpad.js

**Files:**
- Create: `js/mixer.js`, `js/transport.js`, `js/scenes.js`, `js/sequencer.js`, `js/launchpad.js`
- Modify: `js/main.js` (import + call each module's `init()`)

**Interfaces:** Each module exports `export function init()` that renders its DOM and registers its own `on(...)` OSC handlers and DOM event listeners, importing `send/on` from `./osc.js` and shared data from `./matrix-state.js`. No module reaches into another's internals.

- [ ] **Step 1: Extract mixer.js** — move `mixerLevel`, `mixerMuted`, `renderMixer` (main.js l.711-772) + its `/launch/vol` sends; expose `export function init()`. (Most isolated — own state.)
- [ ] **Step 2: Extract transport.js** — beat/rms/tempo handlers (l.54-74) + quant/filter buttons; register `on("/sync/beat")`, `on("/sync/rms")`.
- [ ] **Step 3: Extract scenes.js** — `sceneMode`, `setSceneMode`, `/scene/state` handler, `[data-scene]` wiring (l.120-129, 1093-1111).
- [ ] **Step 4: Extract sequencer.js** — rhythm+melody editors (l.76-118, 830-973, 1011-1027, 1068-1091) + its `avlive.seq` persistence + `/seq/*` handlers.
- [ ] **Step 5: Extract launchpad.js** — `armed`, `clipState`, `togglePad`, `/armed/` handler, `[data-pad]` wiring (l.8-28, 42-52, 1029-1066).
- [ ] **Step 6: Wire in main.js** — `import` each, call `init()` in the `DOMContentLoaded` bootstrap. Keep tab switching + `[data-osc]` generic buttons in main.js.
- [ ] **Step 7: Browser smoke** — every tab and control works identically (mixer faders, transport, scenes, sequencer pads, launchpad clips).
- [ ] **Step 8: Commit**

```bash
git add web_realart/public/control/
git commit -m "refactor: extract mixer transport scenes seq pads"
```

### Task B5: Extract matrix-grid.js and voice-editor.js (modal as-is)

**Files:**
- Create: `js/matrix-grid.js` (grid render, `applyMatCellColor`, `cellRefs`, glow, timeline — l.369-448, 610-709, 774-828)
- Create: `js/voice-editor.js` (the current modal: `renderColorSel`, `renderPattern`, `openColorDef`, `closeColorDef`, `setCD` + `cdEditVoice/cdColor/cdAuditioning` + the `/matrix/colordefs|steps|colormod|colorpose` handlers — l.450-608, 235-285)
- Modify: `js/main.js` (import + init; main.js is now just bootstrap + tabs + generic buttons)

**Interfaces:**
- `matrix-grid.js`: `export function renderMatrix()`, `export function init()`, `export function triggerGlow(...)`; owns `cellRefs`, `matPlayhead`. `renderMatrix` calls `voiceEditor.openFor(vi)` on the edit button (import).
- `voice-editor.js`: `export function init()`, `export function openFor(vi)`, `export function isOpenFor(vi)` (replaces the `!getElementById('colordef-modal').hidden` checks). Registers its own OSC handlers.

- [ ] **Step 1: Extract matrix-grid.js** with the exports above; replace the inbound matrix handlers it needs (`/matrix/cell`, `/matrix/grid`, `/matrix/instrument(s)`) with `on(...)` registrations inside its `init()`.
- [ ] **Step 2: Extract voice-editor.js** moving the modal functions verbatim; replace the 5 modal-DOM open-checks with `isOpenFor(vi)`; register `/matrix/colordefs|steps|colormod|colorpose` here.
- [ ] **Step 3: main.js final shape** — imports osc, matrix-state, and every module; bootstrap calls each `init()`; retains tab switching + `[data-osc]` wiring only. Confirm `main.js` is now < ~120 lines.
- [ ] **Step 4: Full browser smoke** — grid, playhead, glow, timeline drag, mixer, and the **modal editor** (open, colour select, steps, mod, pose, audition) all behave identically.
- [ ] **Step 5: Keep matrix_glow test green** — Run: `cd web_realart && node --test test/matrix_glow.test.mjs` → PASS.
- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/
git commit -m "refactor: extract matrix grid and voice editor"
```

---

## Phase C — New editor UX

Phase C changes behaviour. After B, `voice-editor.js` is the only file that defines the editor — all C work is contained there + `index.html` markup + `control.css`.

### Task C1: Inline accordion (replace the modal)

**Files:**
- Modify: `index.html` (remove `#colordef-modal` block l.180-188; the editor now renders into an expandable row inside `#matrix-grid`)
- Modify: `js/matrix-grid.js` (grid row gains the unified instrument dropdown + a `▷` expand toggle; renders an editor container row under the expanded voice)
- Modify: `js/voice-editor.js` (`openFor(vi)` renders into the inline container, not the modal; track single `expandedVoice`)
- Modify: `control.css` (drop `.cd-modal`/`.cd-panel`; add `.voice-editor-row`, `.voice-expand-btn`)

**Interfaces:** `voice-editor.js`: `openFor(vi, containerEl)` renders into `containerEl`; `collapse()` clears it; only one voice expanded (opening another collapses prior). The per-voice instrument dropdown stays in the grid row (single source) and is the only instrument selector.

- [ ] **Step 1: Grid row markup** — in `renderMatrix`, after the instrument dropdown add a `<button class="voice-expand-btn">▷</button>`; below each voice row, an empty `<div class="voice-editor-row" hidden>`. Clicking the button (or label) calls `voiceEditor.toggle(vi, rowEl)`.
- [ ] **Step 2: voice-editor toggle** — `toggle(vi, el)`: if `expandedVoice === vi` collapse; else collapse previous, set `expandedVoice = vi`, render editor into `el`, fetch state (`send("/matrix/colordefs/get", vi)` etc.).
- [ ] **Step 3: Remove modal** — delete `#colordef-modal` from index.html; delete `openColorDef`/`closeColorDef` modal-specific DOM code; the colour selector + AUDITION render at the top of the inline editor.
- [ ] **Step 4: CSS** — `.voice-editor-row { background:#141414; border-left:3px solid; padding:8px; }`; `.voice-expand-btn` rotates ▷→▼ on expand.
- [ ] **Step 5: Browser smoke** — expanding a voice shows the editor inline; grid stays visible; opening another voice collapses the first; instrument dropdown drives `/matrix/instrument`; all colour/step/mod/pose edits still send correct OSC.
- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/
git commit -m "feat: inline accordion voice editor"
```

### Task C2: Tabs inside the editor (STEPS / SYNTH-FX / MOD-POSE)

**Files:** Modify `js/voice-editor.js`, `control.css`.

**Interfaces:** editor renders a tab bar; `activeTab` per editor instance (default `steps`). Tab render functions: `renderStepsTab(vi)`, `renderSynthFxTab(vi)`, `renderModPoseTab(vi)`.

- [ ] **Step 1: Tab bar** — three buttons (STEPS, SYNTH/FX, MOD/POSE) above the colour selector; clicking sets `activeTab` and re-renders the tab body. Reuse existing `.tab-btn`/`.tab-btn.active` styles.
- [ ] **Step 2: Split current renderPattern** — move the 16-step sub-editor into `renderStepsTab`; the var-row (stretch/oct/amp/cutoff/pan) into `renderSynthFxTab`; mod + pose into `renderModPoseTab`. No new fields yet (just reorganised).
- [ ] **Step 3: Browser smoke** — tabs switch; each tab edits the same data as before; colour selector applies across tabs.
- [ ] **Step 4: Commit**

```bash
git add web_realart/public/control/
git commit -m "feat: tabbed voice editor"
```

### Task C3: Adaptive step sequencer — Drum + Pitch (piano-roll) + toggle

**Files:** Modify `js/voice-editor.js`, `control.css`. Consumes `defaultStepMode`/`isMelodic` from matrix-state.

**Interfaces:** `renderStepsTab(vi)` branches on a per-voice `stepMode` (`'pitch'|'drum'`, init from `defaultStepMode(voice)`, with a toggle button). Both write `steps[s] = {degree, vel}` via `send("/matrix/step", vi, colour, s, degree, vel)` (degree=0 in drum).

- [ ] **Step 1: Drum mode** — render 16 `.seq-cell` on/off pads (current behaviour) with a 3-level accent (click cycles off→soft→loud → vel 0/0.6/0.95, degree 0). Send `/matrix/step`.
- [ ] **Step 2: Pitch mode (piano-roll)** — render a grid: rows = scale degrees (default range 0..14, i.e. 2 octaves; show low extension for sub/reese, high for bells via `VOICE_CLASS`), cols = 16 steps. A cell at (degree d, step s) toggles `steps[s] = {degree:d, vel}` (one note per step; clicking another degree in the same column moves it). Velocity via wheel on the active note. Vertical scroll for out-of-range degrees.

```js
function renderPitchRoll(vi, colour, body) {
  const def = state.matColorDefs[vi][colour];
  const degrees = [14,13,12,11,10,9,8,7,6,5,4,3,2,1,0]; // top=high
  const grid = document.createElement("div"); grid.className = "pianoroll";
  for (const d of degrees) {
    const rowEl = document.createElement("div"); rowEl.className = "pr-row";
    for (let s = 0; s < 16; s++) {
      const cell = document.createElement("button");
      cell.className = "pr-cell";
      const st = def.steps[s];
      if (st && st.degree === d) cell.classList.add("on");
      cell.addEventListener("click", () => {
        const cur = def.steps[s];
        const vel = cur ? cur.vel : 0.8;
        def.steps[s] = (cur && cur.degree === d) ? null : { degree: d, vel };
        saveMatState();
        send("/matrix/step", vi, colour, s, def.steps[s] ? d : -99, vel);
        renderStepsTab(vi);
      });
      rowEl.appendChild(cell);
    }
    grid.appendChild(rowEl);
  }
  body.appendChild(grid);
}
```

- [ ] **Step 3: Toggle** — a `Pitch | Drum` switch in the steps tab header; `semi` voices (`perc`,`tom`) start in drum but can switch; melodic default pitch, drum voices stay drum (toggle hidden or disabled for pure drums).
- [ ] **Step 4: CSS** — `.pianoroll{display:flex;flex-direction:column;gap:1px}` `.pr-row{display:flex;gap:1px}` `.pr-cell{width:20px;height:14px;background:#1c1c1c}` `.pr-cell.on{background:var(--m1)}` (use active colour var).
- [ ] **Step 5: Browser smoke + audition** — for `acid`: pitch roll places notes, AUDITION plays the melody at the right pitches; for `kick`: drum pads toggle, audition plays the rhythm. Confirm `/matrix/step` args match (degree, vel).
- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/
git commit -m "feat: adaptive pitch-roll and drum step modes"
```

### Task C4: SYNTH/FX tab — cutoff, res, reverb, pan, amp, octave, stretch

**Files:** Modify `js/voice-editor.js`, `control.css`. Consumes Phase A engine `res`/`rev`; `MATRIX_MOD_TARGETS`/`matResVoices`-equivalent classification from matrix-state.

**Interfaces:** `renderSynthFxTab(vi)` renders per-(voice,colour) controls; each calls `setCD(colour, field, value)` → `send("/matrix/colordef", vi, colour, field, value)`. Fields: `octave` (select -1..1), `stretch` (select .5/1/2), `amp` (range 0..1.5), `cutoff` (range 200..6000, melodic+semi only), `res` (range 0..1, res-capable voices only), `rev` (range 0..1, all), `pan` (range -1..1).

- [ ] **Step 1: Render controls** — labelled rows; gate `cutoff`/`res` on voice class (`isMelodic(voice) || VOICE_CLASS[voice]==='semi'`), `pan`/`rev`/`amp`/`octave`/`stretch` always. Each input `change` → `setCD`.

```js
function fxRow(label, input) { const r=document.createElement("div"); r.className="fx-row";
  const l=document.createElement("span"); l.textContent=label; r.append(l,input); return r; }
// res example:
const res = document.createElement("input"); res.type="range"; res.min=0; res.max=1; res.step=0.02;
res.value = def.res ?? 0.3;
res.addEventListener("change", () => setCD(colour, "res", +res.value));
```

- [ ] **Step 2: Reverb control** — `rev` range 0..1 labelled "REVERB"; `setCD(colour,"rev",value)`.
- [ ] **Step 3: Persist + echo** — confirm `setCD` writes `matColorDefs[vi][colour][field]`, `saveMatState()`, sends OSC; the `/matrix/colordefs` inbound (Phase A extended push) updates res/rev when SC echoes.
- [ ] **Step 4: Browser + audio smoke** — for `acid`: raise res → audible resonance; raise reverb → audible tail (requires SC booted on macm1). Confirm `/matrix/colordef vi colour res` / `rev` egress.
- [ ] **Step 5: Commit**

```bash
git add web_realart/public/control/
git commit -m "feat: synth and fx tab with res and reverb"
```

### Task C5: Cleanup + final verification

- [ ] **Step 1: Fix stale comments** — `js/matrix-state.js` / `matrix-grid.js`: any "16×32" → "22×64".
- [ ] **Step 2: Run all JS unit tests** — `cd web_realart && node --test test/` → all PASS.
- [ ] **Step 3: Run SC engine test + preset validator** — both PASS (as Phase A steps 7-8).
- [ ] **Step 4: Full browser smoke on macm1** — boot the matrix (`launch_concert.sh` mechanism), load `acid_journey`, open the editor, edit a pitch step + res + reverb live, confirm audio changes and zero console errors.
- [ ] **Step 5: Commit + push**

```bash
git add -A web_realart/ sound_algo/
git commit -m "chore: matrix editor refactor cleanup"
git push origin main
```

---

## Self-review notes

- **Spec coverage:** accordion (C1), tabs (C2), pitch/drum steps (C3), synth/fx + res/rev engine (A1, C4), ES modules (B1-B5), single palette (B3), OSC registry (B1), voice classification (B2). All spec sections mapped.
- **Behaviour-preserving boundary:** Phase B ends with identical UX; the only behaviour change is Phase C. This lets a reviewer reject C work without losing the modularisation.
- **Type consistency:** `steps[s] = {degree, vel}` used identically in A1/C3; `setCD(colour, field, value)` signature stable across B5/C4; `openFor`/`toggle` introduced in C1 and used by matrix-grid.
- **Engine/front contract:** `/matrix/colordef vi colour field value` carries `res`/`rev` (A1 step 5 extends the bulk push; C4 sends the singular set).
