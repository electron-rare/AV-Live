# Matrix global actions — pinch triggers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trigger the global matrix actions from finger pinches (8 slots = 4 per hand) instead of open/closed hand, removing the open/close detection + its threshold settings; also drop in the matrix tempo slider.

**Architecture:** Extend the existing `/pose/pinch` OSCdef to map `(hand, finger)` → slot `0..7` and fire `~matFireGlobal`; remove `~matHandFlip`/`~matHandState` and the `openThresh`/`closeThresh` settings; grow `~matGlobalActions` to 8. The generator, web state, panel (8 dropdowns, trimmed Réglages, tempo slider), and launcher (`FINGER_PIANO=1`) follow.

**Tech Stack:** SuperCollider (sclang), Python 3 (`uv run python`), vanilla ES modules + `node --test`, zsh launcher.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` stays ONE top-level block — `awk` balance `P:0 B:0` after every edit:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
- sclang: `/Applications/SuperCollider.app/Contents/MacOS/sclang <file>` (NOT on PATH; no `timeout`). Harness: `cd sound_algo/data_only/matrix_presets && sclang test_global_actions.scd` → `GLOBALACT PASS`.
- Python via uv. Web tests: `cd web_realart && node --test test/*.test.mjs` (GLOB).
- Commit subject ≤ 50, no underscore in scope, no AI attribution, no `--no-verify`. No emojis.
- **Slot model:** index = `hand*4 + (finger-1)`; `0..3` = MG (index/majeur/annulaire/auriculaire), `4..7` = MD. `/pose/pinch` msg: `hand = msg[2]` (0=L,1=R), `finger = msg[3]` (1-4).
- **Default 8-slot mapping (EXACT):** `[\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next]`.
- **`~matGlobalSettings` keys after trim:** `transientBars: 1`, `breakdownKeep: [\kick, \sub]` (NO thresholds). `/matrix/globalsettings` arg layout becomes `[transientBars, keepN, keep0..]`.
- Action ids unchanged: `none, fill, drop, breakdown, evolve, muteDrums, muteMelo, doubleTime, halfTime, washReverb, next`.
- Per-voice pinch bindings (`~matPoseFire`) and `lOpen`/`rOpen` mod sources stay. No `data_only_viz` code change. Deploy on user request only (live rig).

## File Structure

- `sound_algo/data_only/matrix.scd` — pinch→global in `\mat_ev_pinch`; remove `~matHandFlip`/`~matHandState` + the two `/pose/hands` calls; trim `~matGlobalSettings` + push + `\mat_globalsettings` OSCdef + load-restore; 8-slot default + push(8) + `slot<8`.
- `sound_algo/data_only/matrix_presets/test_global_actions.scd` — remove groups G + J, trim K, add pinch group P.
- `sound_algo/data_only/matrix_presets/generate_presets.py` — 8-slot `globalActions` + trimmed `globalSettings`.
- `sound_algo/data_only/matrix_presets/test_global_actions.py` — new expected literals.
- `web_realart/public/control/js/matrix-state.js` — 8 `GLOBAL_SLOTS`, 8-elem default, trimmed `matGlobalSettings` + `parseGlobalSettings`, `setGlobalAction` slot<8, load length 8.
- `web_realart/public/control/js/morceau-panel.js` — slot<8 inbound; Réglages drop thresholds; new `sendSettings` layout; tempo slider.
- `web_realart/public/control/index.html` + `control.css` — tempo control + styles.
- `web_realart/test/matrix-state.test.mjs` — 8 slots + new settings layout.
- `launcher/concert/launch_concert.sh` — `export FINGER_PIANO=1`.

---

### Task 1: SC — pinch triggers + remove open/close + trim settings

**Files:** Modify `sound_algo/data_only/matrix.scd` + `sound_algo/data_only/matrix_presets/test_global_actions.scd`.

**Interfaces:**
- Consumes: `~matFireGlobal`, `~matEventPinch`, `~matPoseFire`, `~matGlobalActions`, `~matGlobalSettings`, `~matSetTransient`, `~matSave`/`~matLoadFile`.
- Produces: `/pose/pinch` fires global actions by slot `0..7`; `~matGlobalActions` is 8-element; `~matGlobalSettings` has only `transientBars`+`breakdownKeep`; `~matHandFlip`/`~matHandState` removed.

- [ ] **Step 1: Edit the harness (failing).** In `test_global_actions.scd`:
  (a) DELETE the entire `// -- G:` block (the `~matHandFlip` flip-detection checks, through to just before `// -- H:`).
  (b) DELETE the entire `// -- J:` block (the settings-threshold checks, through to just before `// -- K:`).
  (c) In the `// -- K:` block, change the saved settings line and drop the openThresh assertion. Replace:
```supercollider
~matGlobalSettings = (openThresh: 0.7, closeThresh: 0.25, transientBars: 2, breakdownKeep: [\kick, \hats]);
~matSave.("zz_gset_test");
~matGlobalSettings = (openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]);
~matLoadFile.(~matDir +/+ "zz_gset_test.matrix");
(~matGlobalSettings[\openThresh] == 0.7).not.if({ pass = false; "FAIL: openThresh not restored".postln });
(~matGlobalSettings[\transientBars] == 2).not.if({ pass = false; "FAIL: transientBars not restored".postln });
```
  with:
```supercollider
~matGlobalSettings = (transientBars: 2, breakdownKeep: [\kick, \hats]);
~matSave.("zz_gset_test");
~matGlobalSettings = (transientBars: 1, breakdownKeep: [\kick, \sub]);
~matLoadFile.(~matDir +/+ "zz_gset_test.matrix");
(~matGlobalSettings[\transientBars] == 2).not.if({ pass = false; "FAIL: transientBars not restored".postln });
```
  (d) ADD a pinch group before the final `pass.if(...)`:
```supercollider
// -- P: a pinch fires the mapped global action (slot = hand*4 + finger-1) --
~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];
~matTransient = nil;
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 0, 1]);   // L index -> slot 0 -> fill
(~matTransient.notNil and: { ~matTransient[\kind] == \fill }).not.if({ pass = false; "FAIL: L-index pinch != fill".postln });
~matTransient = nil;
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 1]);   // R index -> slot 4 -> muteDrums (kind \mute)
(~matTransient.notNil and: { ~matTransient[\kind] == \mute }).not.if({ pass = false; "FAIL: R-index pinch != muteDrums".postln });
~matTransient = nil;
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 3]);   // R ring -> slot 6 -> washReverb
(~matTransient.notNil and: { ~matTransient[\kind] == \washReverb }).not.if({ pass = false; "FAIL: R-ring pinch != washReverb".postln });
~matTransient = nil;
```

- [ ] **Step 2: Run — expect FAIL** (`~matHandFlip` still referenced by removed groups is gone, but the pinch OSCdef does not yet fire global → group P fails; also K asserts the new layout not yet saved).
Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: `GLOBALACT FAIL` (P assertions fail / K mismatch). If an error about `~matHandFlip` appears it means a G/J reference was missed — remove it.

- [ ] **Step 3: Extend `\mat_ev_pinch` to fire global actions.** In `matrix.scd`, replace:
```supercollider
OSCdef(\mat_ev_pinch,  { |msg| ~matPoseFire.(~matEventPinch.(msg[2] ? 0, msg[3] ? 1)) }, '/pose/pinch');
```
with:
```supercollider
OSCdef(\mat_ev_pinch, { |msg|
    var hand = (msg[2] ? 0).asInteger;
    var finger = (msg[3] ? 1).asInteger;
    ~matPoseFire.(~matEventPinch.(hand, finger));          // per-voice pinch bindings (unchanged)
    ~matFireGlobal.((hand * 4) + (finger - 1));            // global action by pinch slot 0..7
}, '/pose/pinch');
```

- [ ] **Step 4: Grow the default mapping + push + slot range.**
Replace `~matGlobalActions = ~matGlobalActions ? [\fill, \drop, \evolve, \breakdown];  // slots 0..3` with:
```supercollider
~matGlobalActions = ~matGlobalActions ? [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];  // 8 pinch slots 0..7
```
In `~matGlobalActionsPush`, change `4.do` to `8.do`.
In the `\mat_globalaction` OSCdef, change `(slot >= 0 and: { slot < 4 })` to `(slot >= 0 and: { slot < 8 })`.
In `~matLoadFile`'s globalActions restore, change the default + bound. Replace:
```supercollider
            ~matGlobalActions = [\fill, \drop, \evolve, \breakdown];
            ((raw.isArray.not) and: { raw[\globalActions].notNil and: { raw[\globalActions].isArray } }).if({
                raw[\globalActions].do { |s, i| (i < 4 and: { s.notNil }).if({ ~matGlobalActions[i] = s.asSymbol }) }
            });
```
with:
```supercollider
            ~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];
            ((raw.isArray.not) and: { raw[\globalActions].notNil and: { raw[\globalActions].isArray } }).if({
                raw[\globalActions].do { |s, i| (i < 8 and: { s.notNil }).if({ ~matGlobalActions[i] = s.asSymbol }) }
            });
```

- [ ] **Step 5: Remove open/close detection.**
Delete `~matHandState     = ~matHandState     ? IdentityDictionary[\L -> \unknown, \R -> \unknown];` (line near the settings).
Delete the whole `~matHandFlip = { ... };` definition (its comment `// derive open/closed per hand ...` through the closing `};`).
In the `/pose/hands` OSCdef (`\mat_mod_hands`), delete the two lines:
```supercollider
    ~matHandFlip.(\L, msg[2] ? 0, msg[4] ? 0, 0, 1);
    ~matHandFlip.(\R, msg[6] ? 0, msg[8] ? 0, 2, 3);
```

- [ ] **Step 6: Trim the settings (drop thresholds).**
Replace the settings Event:
```supercollider
~matGlobalSettings = ~matGlobalSettings ? (
    openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]
);
```
with:
```supercollider
~matGlobalSettings = ~matGlobalSettings ? ( transientBars: 1, breakdownKeep: [\kick, \sub] );
```
Replace `~matGlobalSettingsPush`:
```supercollider
~matGlobalSettingsPush = {
    var s = ~matGlobalSettings; var keep = s[\breakdownKeep] ? [];
    ~toscSend !? { ~toscSend.valueArray(["/matrix/globalsettings",
        s[\openThresh], s[\closeThresh], s[\transientBars], keep.size] ++ keep.collect({ |v| v.asString })) }
};
```
with:
```supercollider
~matGlobalSettingsPush = {
    var s = ~matGlobalSettings; var keep = s[\breakdownKeep] ? [];
    ~toscSend !? { ~toscSend.valueArray(["/matrix/globalsettings",
        s[\transientBars], keep.size] ++ keep.collect({ |v| v.asString })) }
};
```
Replace the `\mat_globalsettings` OSCdef:
```supercollider
OSCdef(\mat_globalsettings, { |msg, time, addr|
    var op = (msg[1] ? 0.65).asFloat.clip(0.5, 0.95);
    var cl = (msg[2] ? 0.30).asFloat.clip(0.05, 0.6);
    var tb = (msg[3] ? 1).asInteger.clip(1, 8);
    var keepN = (msg[4] ? 0).asInteger.clip(0, 22);
    ~toscTouch !? { ~toscTouch.(addr) };
    cl = cl.min(op - 0.05);                                 // enforce close < open (deadband)
    ~matGlobalSettings[\openThresh] = op;
    ~matGlobalSettings[\closeThresh] = cl;
    ~matGlobalSettings[\transientBars] = tb;
    (keepN > 0).if({
        ~matGlobalSettings[\breakdownKeep] = (0..(keepN - 1)).collect({ |k| (msg[5 + k] ? \kick).asSymbol })
    });
    ~matGlobalSettingsPush.()
}, '/matrix/globalsettings');
```
with:
```supercollider
OSCdef(\mat_globalsettings, { |msg, time, addr|
    var tb = (msg[1] ? 1).asInteger.clip(1, 8);
    var keepN = (msg[2] ? 0).asInteger.clip(0, 22);
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalSettings[\transientBars] = tb;
    (keepN > 0).if({
        ~matGlobalSettings[\breakdownKeep] = (0..(keepN - 1)).collect({ |k| (msg[3 + k] ? \kick).asSymbol })
    });
    ~matGlobalSettingsPush.()
}, '/matrix/globalsettings');
```
Replace the `~matLoadFile` settings restore:
```supercollider
            ~matGlobalSettings = (openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]);
            ((raw.isArray.not) and: { raw[\globalSettings].notNil and: { raw[\globalSettings].isKindOf(Event) } }).if({
                var g = raw[\globalSettings];
                g[\openThresh].notNil.if({ ~matGlobalSettings[\openThresh] = g[\openThresh].asFloat });
                g[\closeThresh].notNil.if({ ~matGlobalSettings[\closeThresh] = g[\closeThresh].asFloat });
                g[\transientBars].notNil.if({ ~matGlobalSettings[\transientBars] = g[\transientBars].asInteger });
                (g[\breakdownKeep].notNil and: { g[\breakdownKeep].isArray }).if({
                    ~matGlobalSettings[\breakdownKeep] = g[\breakdownKeep].collect({ |v| v.asSymbol }) });
            });
```
with:
```supercollider
            ~matGlobalSettings = ( transientBars: 1, breakdownKeep: [\kick, \sub] );
            ((raw.isArray.not) and: { raw[\globalSettings].notNil and: { raw[\globalSettings].isKindOf(Event) } }).if({
                var g = raw[\globalSettings];
                g[\transientBars].notNil.if({ ~matGlobalSettings[\transientBars] = g[\transientBars].asInteger });
                (g[\breakdownKeep].notNil and: { g[\breakdownKeep].isArray }).if({
                    ~matGlobalSettings[\breakdownKeep] = g[\breakdownKeep].collect({ |v| v.asSymbol }) });
            });
```

- [ ] **Step 7: Balance + harness.**
`awk` balance → `P:0 B:0`. Grep to confirm no surviving `~matHandFlip`/`~matHandState`/`openThresh`/`closeThresh` in `matrix.scd`:
`grep -nE "matHandFlip|matHandState|openThresh|closeThresh" sound_algo/data_only/matrix.scd` → no matches.
Then `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–F, H, K, L, M, N, O, P).

- [ ] **Step 8: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): pinch-triggered global actions"
```

---

### Task 2: Generator — 8-slot actions + trimmed settings

**Files:** Modify `generate_presets.py` (`to_sc`), `test_global_actions.py`; regenerate `*.matrix`.

**Interfaces:**
- Consumes: `to_sc`'s `globalActions`/`globalSettings` emission.
- Produces: every `.matrix` carries the 8-symbol `globalActions` + the trimmed `globalSettings`.

- [ ] **Step 1: Update the Python test (failing).** In `test_global_actions.py`, replace the `EXPECT` and `EXPECT_SET` literals:
```python
EXPECT = r"'globalActions': [ \fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next ]"
EXPECT_SET = "'globalSettings': ( 'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )"
```
(leave the `check(...)`/`missing`/`missing_set` logic that uses them unchanged.)

- [ ] **Step 2: Run — expect FAIL** (old literals emitted).
Run: `cd sound_algo/data_only/matrix_presets && uv run python test_global_actions.py`
Expected: `FAIL: to_sc output missing globalActions default`.

- [ ] **Step 3: Update `to_sc` emission.** Replace:
```python
            "'globalActions': [ \\fill, \\drop, \\evolve, \\breakdown ],\n"
            "'globalSettings': ( 'openThresh': 0.65, 'closeThresh': 0.3, "
            "'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )\n)\n"
```
with:
```python
            "'globalActions': [ \\fill, \\drop, \\breakdown, \\evolve, "
            "\\muteDrums, \\muteMelo, \\washReverb, \\next ],\n"
            "'globalSettings': ( 'transientBars': 1, "
            "'breakdownKeep': [ \\kick, \\sub ] )\n)\n"
```

- [ ] **Step 4: Regenerate (twice) + gates.**
`uv run python generate_presets.py` (twice, deterministic). Then `uv run python test_global_actions.py` (`GLOBALACT-PY PASS`), `uv run python test_sections.py` (`TEST PASS`), `uv run python test_families.py` (`TEST PASS`), and `/Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd` (`GLOBALACT PASS` — a freshly generated default still loads).

- [ ] **Step 5: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_global_actions.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): 8-slot pinch actions + trim settings"
```

---

### Task 3: Web — 8 slots + trimmed settings state

**Files:** Modify `web_realart/public/control/js/matrix-state.js`, `web_realart/test/matrix-state.test.mjs`.

**Interfaces:**
- Consumes: `saveMatState`/`loadMatState`.
- Produces: 8-entry `GLOBAL_SLOTS`, 8-element `matGlobalActions` default, `setGlobalAction` slot<8, trimmed `matGlobalSettings`, `parseGlobalSettings` new layout, `loadMatState` gact length 8.

- [ ] **Step 1: Update tests (failing).** In `matrix-state.test.mjs`, replace the existing "four gesture slots" + "default mapping" + "default global settings" + "parseGlobalSettings" tests with:
```javascript
test("eight pinch gesture slots in fixed order", () => {
  assert.equal(GLOBAL_SLOTS.length, 8);
  assert.deepEqual(GLOBAL_SLOTS.map((s) => s.key), [0, 1, 2, 3, 4, 5, 6, 7]);
});
test("default mapping is the 8-finger spread", () => {
  assert.deepEqual(matGlobalActions,
    ["fill", "drop", "breakdown", "evolve", "muteDrums", "muteMelo", "washReverb", "next"]);
});
test("default global settings (no thresholds)", () => {
  assert.equal(matGlobalSettings.transientBars, 1);
  assert.deepEqual(matGlobalSettings.breakdownKeep, ["kick", "sub"]);
  assert.equal(matGlobalSettings.openThresh, undefined);
});
test("parseGlobalSettings decodes [transientBars, keepN, keep0..]", () => {
  const s = parseGlobalSettings([3, 2, "kick", "snare"]);
  assert.equal(s.transientBars, 3);
  assert.deepEqual(s.breakdownKeep, ["kick", "snare"]);
});
```
(Keep the `setGlobalSetting`/`setGlobalAction` mutation tests; update the `setGlobalAction` one to use slot `7`.)

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: failures (4 slots / 4-element default / thresholds present).

- [ ] **Step 3: Update the state.** In `matrix-state.js`:
Replace `GLOBAL_SLOTS`:
```javascript
export const GLOBAL_SLOTS = [
  { key: 0, label: "Pince MG index" }, { key: 1, label: "Pince MG majeur" },
  { key: 2, label: "Pince MG annulaire" }, { key: 3, label: "Pince MG auriculaire" },
  { key: 4, label: "Pince MD index" }, { key: 5, label: "Pince MD majeur" },
  { key: 6, label: "Pince MD annulaire" }, { key: 7, label: "Pince MD auriculaire" },
];
```
Replace the `matGlobalActions` default + `resetGlobalActions` body + `setGlobalAction` bound:
```javascript
export let matGlobalActions = ["fill", "drop", "breakdown", "evolve", "muteDrums", "muteMelo", "washReverb", "next"];
export function setGlobalAction(slot, id) { if (slot >= 0 && slot < 8) matGlobalActions[slot] = id; }
export function resetGlobalActions() {
  matGlobalActions = ["fill", "drop", "breakdown", "evolve", "muteDrums", "muteMelo", "washReverb", "next"];
}
```
Replace `matGlobalSettings` default + `resetGlobalSettings` + `parseGlobalSettings`:
```javascript
export let matGlobalSettings = { transientBars: 1, breakdownKeep: ["kick", "sub"] };
export function setGlobalSetting(key, value) { matGlobalSettings[key] = value; }
export function resetGlobalSettings() { matGlobalSettings = { transientBars: 1, breakdownKeep: ["kick", "sub"] }; }
// Decode /matrix/globalsettings args: [transientBars, keepN, keep0..]
export function parseGlobalSettings(args) {
  const transientBars = Math.round(Number(args[0]));
  const keepN = Math.round(Number(args[1])) || 0;
  const breakdownKeep = [];
  for (let k = 0; k < keepN; k++) breakdownKeep.push(String(args[2 + k]));
  return { transientBars, breakdownKeep };
}
```
In `loadMatState`, change the gact length guard from `=== 4` to `=== 8`.

- [ ] **Step 4: Run target + full suite — PASS.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs` then `node --test test/*.test.mjs` → all green.

- [ ] **Step 5: Commit.**
```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): 8 pinch slots + trim settings state"
```

---

### Task 4: Web — panel (8 dropdowns auto, trimmed Réglages, tempo)

**Files:** Modify `web_realart/public/control/js/morceau-panel.js`, `web_realart/public/control/index.html`, `web_realart/public/control/control.css`. Do NOT modify `main.js`.

**Interfaces:**
- Consumes: `GLOBAL_SLOTS` (now 8), `matGlobalSettings`/`parseGlobalSettings` (trimmed), the SC `/matrix/bpm` route.
- Produces: 8 gesture dropdowns (auto from `GLOBAL_SLOTS`), Réglages without threshold sliders, the `/matrix/globalsettings` send with the new layout, and a `#matrix-bpm` tempo slider.

- [ ] **Step 1: Fix the inbound slot bound + the settings send/sliders in `morceau-panel.js`.**
In the `on("/matrix/globalaction", ...)` handler, change `slot < 4` to `slot < 8`.
In the Réglages block: remove the two `slider("openThresh", ...)` and `slider("closeThresh", ...)` lines and their `ctl` entries (keep only `transientBars`). Update the inbound `on("/matrix/globalsettings", ...)` to no longer reference `ctl.openThresh`/`ctl.closeThresh`. Change `sendSettings` to the new arg layout:
```javascript
    const sendSettings = () => {
      const s = matGlobalSettings;
      send("/matrix/globalsettings", s.transientBars, s.breakdownKeep.length, ...s.breakdownKeep);
      saveMatState();
    };
```
And the inbound handler body becomes:
```javascript
    on("/matrix/globalsettings", (args) => {
      const s = parseGlobalSettings(args);
      setGlobalSetting("transientBars", s.transientBars);
      setGlobalSetting("breakdownKeep", s.breakdownKeep);
      ctl.transientBars.inp.value = s.transientBars; ctl.transientBars.out.textContent = s.transientBars;
      MATRIX_VOICES.forEach((v) => { keepBoxes[v].checked = s.breakdownKeep.includes(v); });
      saveMatState();
    });
```
(Keep the `ctl = { transientBars: slider("transientBars", "Durée (mesures)", 1, 8, 1) }` line — drop the two threshold sliders from that object.)

- [ ] **Step 2: Add the tempo slider.** In `index.html`, as the FIRST child of `#morceau-panel`, add:
```html
    <div class="morceau-global">
      <label class="morceau-bpm">Tempo <input id="matrix-bpm" type="range" min="20" max="300" step="1" value="120"><output id="matrix-bpm-out">120</output></label>
    </div>
```
In `morceau-panel.js`, after the Réglages block (before `init()` ends), add:
```javascript
  const bpm = document.getElementById("matrix-bpm");
  const bpmOut = document.getElementById("matrix-bpm-out");
  if (bpm) {
    bpm.addEventListener("input", () => { if (bpmOut) bpmOut.textContent = bpm.value; });
    bpm.addEventListener("change", () => send("/matrix/bpm", +bpm.value));
    on("/matrix/bpm", (args) => {
      const v = Math.round(Number(args[0]));
      if (Number.isFinite(v)) { bpm.value = v; if (bpmOut) bpmOut.textContent = v; }
    });
    onOpen(() => send("/matrix/bpm/get"));
    send("/matrix/bpm/get");
  }
```

- [ ] **Step 3: Style.** Append to `control.css`:
```css
.morceau-global { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-bottom: 8px; }
.morceau-global .morceau-bpm { display: inline-flex; align-items: center; gap: 4px; font-size: 12px; color: #ccc; }
.morceau-global .morceau-bpm output { min-width: 2.5em; text-align: right; color: #8c8; }
```

- [ ] **Step 4: Parse + suite.**
Run: `cd web_realart && node --check public/control/js/morceau-panel.js` (no output) and `node --test test/*.test.mjs` (all green). Confirm `grep -c 'id="matrix-bpm"' public/control/index.html` → `1`.

- [ ] **Step 5: Commit.**
```bash
git add web_realart/public/control/js/morceau-panel.js web_realart/public/control/index.html web_realart/public/control/control.css
git commit -m "feat(control): 8 pinch slots panel + tempo"
```

---

### Task 5: Launcher — enable pinch detection

**Files:** Modify `launcher/concert/launch_concert.sh`.

- [ ] **Step 1: Enable FINGER_PIANO.** After the `export MEDIAPIPE_DELEGATE=...` line, add:
```bash
# Finger pinches drive the matrix global actions (8 slots). Enabling the pinch
# detector also enables the air-piano finger-strike detector, inert unless a
# voice has a finger binding (none by default).
export FINGER_PIANO="${FINGER_PIANO:-1}"
```

- [ ] **Step 2: Lint.** `zsh -n launcher/concert/launch_concert.sh` → no output (valid syntax).

- [ ] **Step 3: Commit.**
```bash
git add launcher/concert/launch_concert.sh
git commit -m "feat(launcher): enable pinch detection for matrix"
```

---

### Task 6: Deploy + live smoke (macm1)

**Files:** none.

- [ ] **Step 1:** On user OK: `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'`. Because `FINGER_PIANO` is new, restart the FULL stack via the launcher (it relaunches the pose pipeline with `FINGER_PIANO=1`) OR restart the pose pipeline with the env set + SC-only reboot. Simplest: re-run `launch_concert.sh` on macm1 (kills + relaunches iPhone app, SC engine, pose pipeline). Confirm `[matrix] ready` + the pose pipeline logs pinch detection.
- [ ] **Step 2:** Hard-reload the web page → the Morceau panel shows 8 pinch dropdowns + a Tempo slider + Réglages (duration + kept-voices, NO threshold sliders). Pinch each finger (thumb↔finger), L and R → the mapped global action fires (fill/drop/breakdown/evolve, muteDrums/muteMelo/washReverb/next). Open/close hand no longer triggers. Re-map a slot + save/reload. Tempo slider changes the matrix speed. Report to the user.

---

## Self-review

**Spec coverage:** pinch→global 8 slots → Task 1 Step 3-4; remove open/close + thresholds → Task 1 Step 5-6; generator 8 + trim → Task 2; web 8 slots + trim → Task 3; panel 8 + Réglages trim + tempo → Task 4; FINGER_PIANO → Task 5; smoke → Task 6. ✓

**Placeholder scan:** all code present; slot math, default mapping, arg layouts, FINGER_PIANO concrete; no TBD.

**Type consistency:** slot index `hand*4+(finger-1)` (Task 1 Step 3) ranges 0..7, matching `~matGlobalActions` 8-element (Step 4), `slot < 8` guard (Step 4), `GLOBAL_SLOTS` keys 0..7 (Task 3), `setGlobalAction` <8 (Task 3), panel inbound `slot < 8` (Task 4). Default mapping `[fill,drop,breakdown,evolve,muteDrums,muteMelo,washReverb,next]` identical across SC (Step 4), generator literal (Task 2), web (Task 3). `globalSettings` arg layout `[transientBars, keepN, keep0..]` identical in `~matGlobalSettingsPush`/`\mat_globalsettings` (Task 1 Step 6), `parseGlobalSettings`/`sendSettings` (Task 3-4). `globalSettings` keys (`transientBars`,`breakdownKeep`) consistent SC↔generator↔web. `/matrix/bpm` single-Float contract (Task 4 Step 2) matches the route shipped in the bpm commit.
