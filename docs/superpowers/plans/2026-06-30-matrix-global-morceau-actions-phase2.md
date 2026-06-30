# Matrix global morceau actions — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the global-action thresholds/duration/kept-voices editable per morceau (the "Réglages" — including the close-hand sensitivity the user asked for), and extend the action vocabulary with mute-drums, mute-mélo, double-time, half-time, wash-reverb, and "next preset".

**Architecture:** Phase 1's four hard-coded constants (`~matOpenThresh`/`~matCloseThresh`/`~matTransientBars`/`~matBreakdownKeep`) become one editable `~matGlobalSettings` Event, synced over `/matrix/globalsettings`, saved per `.matrix`, generated as a default, and edited by a new "Réglages" group in the Morceau panel. The transient primitive gains two param channels (a global stretch factor + a rev boost read in `~matVariation`) so double/half-time and wash-reverb express through it; mute-groups reuse the colour-level override (`~matEffColor` `\mute` kind over a voice group); "next" loads the next preset in the sorted list.

**Tech Stack:** SuperCollider (sclang), Python 3 (`uv run python`), vanilla ES modules + `node --test`.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` stays ONE top-level block — `awk` balance `P:0 B:0` after every edit. Validate with:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
- sclang: `/Applications/SuperCollider.app/Contents/MacOS/sclang <file>` (NOT on PATH; no `timeout`). SC harness: `cd sound_algo/data_only/matrix_presets && sclang test_global_actions.scd` → expect `GLOBALACT PASS`.
- Python via uv. Web tests: `cd web_realart && node --test test/*.test.mjs` (GLOB form) or a specific file.
- Commit subject ≤ 50 chars, no underscore in commit scope, no AI attribution, no `--no-verify`. No emojis.
- `~matGlobalSettings` keys + defaults (EXACT): `openThresh: 0.65`, `closeThresh: 0.30`, `transientBars: 1`, `breakdownKeep: [\kick, \sub]`. Invariant `openThresh > closeThresh` (hysteresis deadband) must be enforced on set.
- Action symbols (Phase 1 + new): `none, fill, drop, breakdown, evolve, muteDrums, muteMelo, doubleTime, halfTime, washReverb, next` — identical strings across SC, generator, web.
- Transient param channels: `doubleTime` → stretch ×0.5, `halfTime` → stretch ×2.0, `washReverb` → rev +0.4 (clamped 0..1). Mute-groups and the Phase-1 colour transients leave stretch=1.0, rev=0.0.
- Voice groups (mirror the web `VOICE_CLASS`; "semi" perc/tom group WITH drums for mute purposes): `~matDrumVoices = [\kick,\hats,\clap,\ride,\rim,\sweep,\fx,\snare,\crash,\shaker,\perc,\tom]`, `~matMeloVoices = [\sub,\acid,\arp,\lead,\stab,\pad,\reese,\bells,\melody,\chord]`.
- `~matTransient` never edits `~lp[\matrix]`. No `data_only_viz` changes. Deploy on user request only (live rig).

## File Structure

- `sound_algo/data_only/matrix.scd` — `~matGlobalSettings` + settings-aware `~matHandFlip`/`~matSetTransient`/breakdown; `/matrix/globalsettings[/get]`; save/load. Then: `~matEffColor` `\mute`; transient stretch/rev factors in `~matVariation`/`~matVariationOverlay`/`~matColorStepPattern`; `~matDrumVoices`/`~matMeloVoices`; `~matCurrentName`/`~matAllNames`/`~matNextPreset`; extended `~matFireGlobal`.
- `sound_algo/data_only/matrix_presets/generate_presets.py` — `to_sc` emits the default `globalSettings`.
- `sound_algo/data_only/matrix_presets/test_global_actions.{py,scd}` — extended.
- `web_realart/public/control/js/matrix-state.js` — `matGlobalSettings` + setters + persistence; extended `GLOBAL_ACTION_CHOICES`.
- `web_realart/public/control/js/morceau-panel.js` — new "Réglages" group.
- `web_realart/public/control/control.css` — Réglages styles.
- `web_realart/test/matrix-state.test.mjs` — settings + new choices coverage.

---

### Task 1: SC — `~matGlobalSettings` editable settings

**Files:** Modify `sound_algo/data_only/matrix.scd` (global-actions block ~line 326-345; `~matHandFlip`; `~matSetTransient`; `~matFireGlobal` breakdown; OSCdefs near `\mat_globalaction` ~line 950; `~matSave` payload; `~matLoadFile` tail). Modify `sound_algo/data_only/matrix_presets/test_global_actions.scd`.

**Interfaces:**
- Consumes (Phase 1): `~matHandFlip`, `~matSetTransient`, `~matFireGlobal`, `~matGlobalActionsPush`, `~matSave`, `~matLoadFile`, `~toscSend`/`~toscTouch`.
- Produces: `~matGlobalSettings` (Event `(openThresh:, closeThresh:, transientBars:, breakdownKeep:[Symbol])`), `~matGlobalSettingsPush.()`, OSC `/matrix/globalsettings` (set+echo) + `/matrix/globalsettings/get`, `globalSettings` saved/restored in `.matrix`.

- [ ] **Step 1: Append failing harness checks** to `test_global_actions.scd`, immediately before the final `pass.if(...)` line:

```supercollider
// -- J: settings drive detection thresholds + transient duration --
~matGlobalSettings[\openThresh] = 0.8; ~matGlobalSettings[\closeThresh] = 0.2;
~matHandState[\L] = \unknown;
~matHandFlip.(\L, 0.5, 0.5, 0, 1);     // 0.5 is in the new deadband -> stays unknown, no fire
~fired = nil; ~matFireGlobal = { |slot| ~fired = slot };
~matHandFlip.(\L, 0.5, 0.85, 0, 1);    // >=0.8 open -> baseline (from unknown, no fire)
(~fired.isNil).not.if({ pass = false; "FAIL: settings open baseline fired".postln });
~matHandFlip.(\L, 0.5, 0.15, 0, 1);    // <=0.2 -> closed -> fire slot1
(~fired == 1).not.if({ pass = false; "FAIL: settings close threshold no fire".postln });
~matGlobalSettings[\transientBars] = 3;
~matFireGlobal = { |slot| };           // restore no-op-ish (real one not needed here)
~matSetTransient.(\drop, []);
(~matTransient[\bars] == 3).not.if({ pass = false; "FAIL: transientBars not from settings".postln });
~matTransient = nil;
// -- K: settings save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalSettings = (openThresh: 0.7, closeThresh: 0.25, transientBars: 2, breakdownKeep: [\kick, \hats]);
~matSave.("zz_gset_test");
~matGlobalSettings = (openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]);
~matLoadFile.(~matDir +/+ "zz_gset_test.matrix");
(~matGlobalSettings[\openThresh] == 0.7).not.if({ pass = false; "FAIL: openThresh not restored".postln });
(~matGlobalSettings[\transientBars] == 2).not.if({ pass = false; "FAIL: transientBars not restored".postln });
(~matGlobalSettings[\breakdownKeep] == [\kick, \hats]).not.if({ pass = false; "FAIL: breakdownKeep not restored".postln });
("rm -f '" ++ (~matDir +/+ "zz_gset_test.matrix") ++ "'").systemCmd;
```

- [ ] **Step 2: Run — expect FAIL** (`~matGlobalSettings` undefined / thresholds still hard-coded).

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: error on `~matGlobalSettings` or `GLOBALACT FAIL`.

- [ ] **Step 3: Replace the four Phase-1 constants with the settings Event.** In `matrix.scd`, find the global-actions state block and replace these four lines:
```supercollider
~matTransientBars = ~matTransientBars ? 1;            // Phase 1: 1 bar (Phase 2 reads settings)
~matBreakdownKeep = ~matBreakdownKeep ? [\kick, \sub];
~matOpenThresh    = ~matOpenThresh    ? 0.65;
~matCloseThresh   = ~matCloseThresh   ? 0.30;
```
with:
```supercollider
~matGlobalSettings = ~matGlobalSettings ? (
    openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]
);
```

- [ ] **Step 4: Read settings in the three consumers.**
In `~matSetTransient`, change `bars: ~matTransientBars` to `bars: (~matGlobalSettings[\transientBars] ? 1)`.
In `~matFireGlobal`, change the breakdown line to:
```supercollider
    (act == \breakdown).if({ ~matSetTransient.(\breakdown, ~matGlobalSettings[\breakdownKeep] ? [\kick, \sub]) });
```
In `~matHandFlip`, change the two threshold comparisons:
```supercollider
        (openness >= (~matGlobalSettings[\openThresh] ? 0.65)).if({ \open },
        { (openness <= (~matGlobalSettings[\closeThresh] ? 0.30)).if({ \closed }, { prev }) })
```

- [ ] **Step 5: Add the settings push + OSC routes.** Append to the global-actions block (after `~matGlobalActionsPush`):
```supercollider

// push settings to surfaces: openThresh, closeThresh, transientBars, keepN, keep0..
~matGlobalSettingsPush = {
    var s = ~matGlobalSettings; var keep = s[\breakdownKeep] ? [];
    ~toscSend !? { ~toscSend.valueArray(["/matrix/globalsettings",
        s[\openThresh], s[\closeThresh], s[\transientBars], keep.size] ++ keep.collect({ |v| v.asString })) }
};
```
Add the OSCdefs just after `\mat_globalaction_get`:
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
OSCdef(\mat_globalsettings_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalSettingsPush.()
}, '/matrix/globalsettings/get');
```

- [ ] **Step 6: Persist in `~matSave`.** In the `payload` Event, add after `globalActions: ~matGlobalActions`:
```supercollider
        globalActions: ~matGlobalActions,
        globalSettings: ~matGlobalSettings
```
(i.e. add a comma after the `globalActions` line and the `globalSettings` line below it.)

- [ ] **Step 7: Restore in `~matLoadFile`.** Just after the `globalActions` restore block added in Phase 1, add:
```supercollider
            // restore global settings (default when absent/legacy)
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
Then, just after `~matGlobalActionsPush.();` (added in Phase 1), add `~matGlobalSettingsPush.();`.

- [ ] **Step 8: Balance + harness.**
Run the `awk` balance check → `P:0 B:0`. Then `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–K).

- [ ] **Step 9: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): editable global settings + thresholds"
```

---

### Task 2: Generator — emit default `globalSettings`

**Files:** Modify `generate_presets.py` (`to_sc` return ~line 1147-1150); modify `test_global_actions.py`; regenerate `*.matrix`.

**Interfaces:**
- Consumes: `to_sc`, the Phase-1 `globalActions` emission.
- Produces: every `.matrix` carries `'globalSettings': ( 'openThresh': 0.65, 'closeThresh': 0.3, 'transientBars': 1, 'breakdownKeep': [ \kick, \sub ] )`.

- [ ] **Step 1: Extend the Python test (failing).** In `test_global_actions.py`, add a second expected literal + check, after the existing `EXPECT` block:
```python
EXPECT_SET = ("'globalSettings': ( 'openThresh': 0.65, 'closeThresh': 0.3, "
              "'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )")
check(EXPECT_SET in sample, "to_sc output missing globalSettings default")
missing_set = [os.path.basename(f) for f in files
               if EXPECT_SET not in open(f, encoding="utf-8").read()]
check(not missing_set, "globalSettings missing in: %s" % missing_set[:5])
```

- [ ] **Step 2: Run — expect FAIL** (`to_sc` lacks the field).
Run: `cd sound_algo/data_only/matrix_presets && uv run python test_global_actions.py`
Expected: `FAIL: to_sc output missing globalSettings default`.

- [ ] **Step 3: Emit the field.** In `to_sc`, change the return to append `globalSettings` after `globalActions`. Replace:
```python
            "'voicePoses': [ %s ],\n"
            "'globalActions': [ \\fill, \\drop, \\evolve, \\breakdown ]\n)\n"
            % (rows, isyms, cds, vms, vps))
```
with:
```python
            "'voicePoses': [ %s ],\n"
            "'globalActions': [ \\fill, \\drop, \\evolve, \\breakdown ],\n"
            "'globalSettings': ( 'openThresh': 0.65, 'closeThresh': 0.3, "
            "'transientBars': 1, 'breakdownKeep': [ \\kick, \\sub ] )\n)\n"
            % (rows, isyms, cds, vms, vps))
```

- [ ] **Step 4: Regenerate (twice — deterministic) + verify.**
`uv run python generate_presets.py` (twice; second run leaves files byte-identical). Then `uv run python test_global_actions.py` → `GLOBALACT-PY PASS`; `uv run python test_sections.py` → `TEST PASS`; `uv run python test_families.py` → `TEST PASS`.

- [ ] **Step 5: Confirm a generated preset still loads in SC with settings intact.**
Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd` → `GLOBALACT PASS`.

- [ ] **Step 6: Commit.**
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_global_actions.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): emit default global settings"
```

---

### Task 3: Web — settings state + persistence

**Files:** Modify `web_realart/public/control/js/matrix-state.js`; modify `web_realart/test/matrix-state.test.mjs`.

**Interfaces:**
- Consumes: `saveMatState`/`loadMatState` (extend blob with `gset`).
- Produces: `matGlobalSettings` (`{openThresh, closeThresh, transientBars, breakdownKeep:[String]}`), `setGlobalSetting(key, value)`, `parseGlobalSettings(args)` → `{openThresh, closeThresh, transientBars, breakdownKeep}`, `resetGlobalSettings()`.

- [ ] **Step 1: Failing test.** Append to `matrix-state.test.mjs`:
```javascript
import { matGlobalSettings, setGlobalSetting, parseGlobalSettings }
  from "../public/control/js/matrix-state.js";

test("default global settings", () => {
  assert.equal(matGlobalSettings.openThresh, 0.65);
  assert.equal(matGlobalSettings.closeThresh, 0.30);
  assert.equal(matGlobalSettings.transientBars, 1);
  assert.deepEqual(matGlobalSettings.breakdownKeep, ["kick", "sub"]);
});
test("setGlobalSetting mutates one key", () => {
  setGlobalSetting("closeThresh", 0.4);
  assert.equal(matGlobalSettings.closeThresh, 0.4);
  setGlobalSetting("closeThresh", 0.30);
});
test("parseGlobalSettings decodes the OSC arg layout", () => {
  const s = parseGlobalSettings([0.7, 0.2, 3, 2, "kick", "snare"]);
  assert.equal(s.openThresh, 0.7);
  assert.equal(s.closeThresh, 0.2);
  assert.equal(s.transientBars, 3);
  assert.deepEqual(s.breakdownKeep, ["kick", "snare"]);
});
```

- [ ] **Step 2: Run — expect FAIL** (exports undefined).
Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: import failures.

- [ ] **Step 3: Add the settings state.** In `matrix-state.js`, after the `matGlobalActions` block, add:
```javascript
export let matGlobalSettings = { openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: ["kick", "sub"] };
export function setGlobalSetting(key, value) { matGlobalSettings[key] = value; }
export function resetGlobalSettings() {
  matGlobalSettings = { openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: ["kick", "sub"] };
}
// Decode /matrix/globalsettings args: [openThresh, closeThresh, transientBars, keepN, keep0..]
export function parseGlobalSettings(args) {
  const openThresh = Number(args[0]);
  const closeThresh = Number(args[1]);
  const transientBars = Math.round(Number(args[2]));
  const keepN = Math.round(Number(args[3])) || 0;
  const breakdownKeep = [];
  for (let k = 0; k < keepN; k++) breakdownKeep.push(String(args[4 + k]));
  return { openThresh, closeThresh, transientBars, breakdownKeep };
}
```

- [ ] **Step 4: Persist `gset`.** In `saveMatState`, add `gset: matGlobalSettings` to the JSON blob (after `gact: matGlobalActions`). In `loadMatState`, after the `gact` restore line, add:
```javascript
      if (raw.gset && typeof raw.gset === "object" && Array.isArray(raw.gset.breakdownKeep))
        matGlobalSettings = raw.gset;
```

- [ ] **Step 5: Run target + full suite — expect PASS.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs` then `node --test test/*.test.mjs` → all green.

- [ ] **Step 6: Commit.**
```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): global settings state + persistence"
```

---

### Task 4: Web — the "Réglages" panel group (close sensitivity)

**Files:** Modify `web_realart/public/control/js/morceau-panel.js`; modify `web_realart/public/control/index.html` (add a `#morceau-settings` host inside `#morceau-panel`); modify `web_realart/public/control/control.css`.

**Interfaces:**
- Consumes: `matGlobalSettings`, `setGlobalSetting`, `parseGlobalSettings`, `saveMatState`, `MATRIX_VOICES` from `matrix-state.js`; `send`/`on`/`onOpen` from `osc.js`.
- Produces: a Réglages group rendering 2 threshold sliders (open/close), a transient-bars number input, and a kept-voices checkbox grid; sends `/matrix/globalsettings`; syncs from `on("/matrix/globalsettings")`.

- [ ] **Step 1: Add the container.** In `index.html`, inside `#morceau-panel`, after `<div id="morceau-slots" ...></div>`, add:
```html
    <div class="morceau-title">Réglages</div>
    <div id="morceau-settings" class="morceau-settings"></div>
```

- [ ] **Step 2: Render the Réglages group in `morceau-panel.js`.** At the end of `init()` (before the `onOpen`/`get` lines for globalaction), add a settings renderer + sync. Insert:
```javascript
  // --- Réglages: thresholds, transient duration, breakdown kept-voices ---
  const sHost = document.getElementById("morceau-settings");
  if (sHost) {
    const sendSettings = () => {
      const s = matGlobalSettings;
      send("/matrix/globalsettings", s.openThresh, s.closeThresh, s.transientBars,
           s.breakdownKeep.length, ...s.breakdownKeep);
      saveMatState();
    };
    const slider = (key, label, min, max, step) => {
      const row = document.createElement("label");
      row.className = "morceau-set-row";
      const span = document.createElement("span"); span.textContent = label;
      const inp = document.createElement("input");
      inp.type = "range"; inp.min = min; inp.max = max; inp.step = step;
      inp.value = matGlobalSettings[key];
      const out = document.createElement("output"); out.textContent = matGlobalSettings[key];
      inp.addEventListener("input", () => { out.textContent = inp.value; });
      inp.addEventListener("change", () => {
        setGlobalSetting(key, key === "transientBars" ? Math.round(+inp.value) : +inp.value);
        sendSettings();
      });
      row.append(span, inp, out);
      sHost.appendChild(row);
      return { inp, out };
    };
    const ctl = {
      openThresh: slider("openThresh", "Seuil ouvert", 0.5, 0.95, 0.01),
      closeThresh: slider("closeThresh", "Seuil fermé (sensibilité)", 0.05, 0.6, 0.01),
      transientBars: slider("transientBars", "Durée (mesures)", 1, 8, 1),
    };
    const keepWrap = document.createElement("div");
    keepWrap.className = "morceau-keep";
    const keepTitle = document.createElement("span");
    keepTitle.textContent = "Voix gardées (breakdown)";
    keepWrap.appendChild(keepTitle);
    const keepBoxes = {};
    MATRIX_VOICES.forEach((v) => {
      const lab = document.createElement("label"); lab.className = "morceau-keep-box";
      const cb = document.createElement("input"); cb.type = "checkbox"; cb.value = v;
      cb.checked = matGlobalSettings.breakdownKeep.includes(v);
      cb.addEventListener("change", () => {
        const keep = MATRIX_VOICES.filter((x) => keepBoxes[x].checked);
        setGlobalSetting("breakdownKeep", keep);
        sendSettings();
      });
      keepBoxes[v] = cb;
      lab.append(cb, document.createTextNode(v));
      keepWrap.appendChild(lab);
    });
    sHost.appendChild(keepWrap);
    on("/matrix/globalsettings", (args) => {
      const s = parseGlobalSettings(args);
      setGlobalSetting("openThresh", s.openThresh);
      setGlobalSetting("closeThresh", s.closeThresh);
      setGlobalSetting("transientBars", s.transientBars);
      setGlobalSetting("breakdownKeep", s.breakdownKeep);
      ctl.openThresh.inp.value = s.openThresh; ctl.openThresh.out.textContent = s.openThresh;
      ctl.closeThresh.inp.value = s.closeThresh; ctl.closeThresh.out.textContent = s.closeThresh;
      ctl.transientBars.inp.value = s.transientBars; ctl.transientBars.out.textContent = s.transientBars;
      MATRIX_VOICES.forEach((v) => { keepBoxes[v].checked = s.breakdownKeep.includes(v); });
      saveMatState();
    });
    onOpen(() => send("/matrix/globalsettings/get"));
    send("/matrix/globalsettings/get");
  }
```
Add the new imports at the top of `morceau-panel.js`:
```javascript
import {
  GLOBAL_ACTION_CHOICES, GLOBAL_SLOTS, matGlobalActions, setGlobalAction, saveMatState,
  matGlobalSettings, setGlobalSetting, parseGlobalSettings,
} from "./matrix-state.js";
import { MATRIX_VOICES } from "./matrix-state.js";
```
(Replace the existing single import block with the combined one — do not import `saveMatState` twice.)

- [ ] **Step 3: Style it.** Append to `control.css`:
```css
.morceau-settings { display: flex; flex-direction: column; gap: 4px; margin-top: 4px; }
.morceau-set-row { display: grid; grid-template-columns: 1fr 2fr auto; align-items: center; gap: 6px; font-size: 12px; color: #ccc; }
.morceau-set-row output { min-width: 2.5em; text-align: right; color: #8c8; }
.morceau-keep { display: flex; flex-wrap: wrap; gap: 2px 8px; margin-top: 4px; font-size: 11px; color: #aaa; }
.morceau-keep > span { flex-basis: 100%; color: #888; }
.morceau-keep-box { display: inline-flex; align-items: center; gap: 2px; }
```

- [ ] **Step 4: Parse + suite.**
Run: `cd web_realart && node --check public/control/js/morceau-panel.js` (no output) and `node --test test/*.test.mjs` (all green).

- [ ] **Step 5: Commit.**
```bash
git add web_realart/public/control/js/morceau-panel.js web_realart/public/control/index.html web_realart/public/control/control.css
git commit -m "feat(control): reglages group in morceau panel"
```

---

### Task 5: SC — extended action vocabulary

**Files:** Modify `sound_algo/data_only/matrix.scd` (global-actions block; `~matEffColor`; `~matVariationOverlay` ~line 219; `~matColorStepPattern` ~line 248; `~matVariation` rev cdPairs ~line 277; `~matLoad` ~line 869; `~matFireGlobal`). Modify `test_global_actions.scd`.

**Interfaces:**
- Consumes: `~matSetTransient`, `~matEffColor`, `~matTransient`, `~matVariation`, `~matNames`, `~matPresetDir`/`~matDir`, `~matLoad`, `~matFireGlobal`, `~matGlobalSettings`.
- Produces: `~matDrumVoices`/`~matMeloVoices`, `~matEffColor` `\mute` kind, transient `stretch`/`rev` channels (read in `~matVariation`), `~matTxStretch`/`~matTxRev`, `~matCurrentName`, `~matAllNames.()`, `~matNextPreset.()`, extended `~matFireGlobal` (muteDrums/muteMelo/doubleTime/halfTime/washReverb/next).

- [ ] **Step 1: Append failing harness checks** to `test_global_actions.scd`, before the final `pass.if(...)`:
```supercollider
// -- L: mute group silences only its voices --
~matSetTransient.(\mute, ~matDrumVoices);
(~matEffColor.(\kick, 0, 3) == 0).not.if({ pass = false; "FAIL: muteDrums keeps kick".postln });
(~matEffColor.(\sub, 4, 3) == 3).not.if({ pass = false; "FAIL: muteDrums silenced melo sub".postln });
~matTransient = nil;
// -- M: param transients set stretch / rev channels (via ~matSetTransient directly;
//       ~matFireGlobal was stubbed by earlier groups, and the 6 dispatch lines are
//       trivial transcription verified live in Task 7) --
~matSetTransient.(\doubleTime, []);
(~matTxStretch.value == 0.5).not.if({ pass = false; "FAIL: doubleTime stretch != 0.5".postln });
~matTransient = nil;
~matSetTransient.(\washReverb, []);
(~matTxRev.value > 0).not.if({ pass = false; "FAIL: washReverb rev not boosted".postln });
~matTransient = nil;
~matSetTransient.(\halfTime, []);
(~matTxStretch.value == 2.0).not.if({ pass = false; "FAIL: halfTime stretch != 2.0".postln });
~matTransient = nil;
// -- N: next loads the following preset in sorted order --
~loaded = nil; ~matLoadReal = ~matLoad; ~matLoad = { |n| ~loaded = n.asSymbol };
~matAllNames = { [\aaa_x, \bbb_y, \ccc_z] };            // stub the list deterministically
~matCurrentName = \aaa_x;
~matNextPreset.();
(~loaded == \bbb_y).not.if({ pass = false; "FAIL: next did not load bbb_y".postln });
~matCurrentName = \ccc_z;                               // wrap to first
~matNextPreset.();
(~loaded == \aaa_x).not.if({ pass = false; "FAIL: next did not wrap to aaa_x".postln });
~matLoad = ~matLoadReal;
```

- [ ] **Step 2: Run — expect FAIL** (`~matDrumVoices`/`~matTxStretch`/`~matNextPreset` undefined).
Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: error / `GLOBALACT FAIL`.

- [ ] **Step 3: Add voice groups + transient param accessors + `\mute`.** In the global-actions block, after `~matGlobalSettings`, add:
```supercollider
~matDrumVoices = ~matDrumVoices ? [\kick,\hats,\clap,\ride,\rim,\sweep,\fx,\snare,\crash,\shaker,\perc,\tom];
~matMeloVoices = ~matMeloVoices ? [\sub,\acid,\arp,\lead,\stab,\pad,\reese,\bells,\melody,\chord];
// transient param channels read by ~matVariation (1.0/0.0 when no transient or a colour-only kind)
~matTxStretch = { (~matTransient.notNil).if({ ~matTransient[\stretch] ? 1.0 }, { 1.0 }) };
~matTxRev     = { (~matTransient.notNil).if({ ~matTransient[\rev] ? 0.0 }, { 0.0 }) };
```
In `~matEffColor`, add a `\mute` branch before the final `base` fallback. Replace:
```supercollider
        (k == \breakdown).if({ ((t[\voices] ? []).includes(name)).if({ base }, { 0 }) },
        { base }) }) })
```
with:
```supercollider
        (k == \breakdown).if({ ((t[\voices] ? []).includes(name)).if({ base }, { 0 }) },
        { (k == \mute).if({ ((t[\voices] ? []).includes(name)).if({ 0 }, { base }) },
        { base }) }) }) })
```
(note the extra closing `)` to match the added nesting).

- [ ] **Step 4: Carry stretch/rev in the transient.** Change `~matSetTransient` to stamp the param channels by kind:
```supercollider
~matSetTransient = { |kind, voices|
    var stretch = (kind == \doubleTime).if({ 0.5 }, { (kind == \halfTime).if({ 2.0 }, { 1.0 }) });
    var rev = (kind == \washReverb).if({ 0.4 }, { 0.0 });
    ~matTransient = (kind: kind, voices: (voices ? []), bars: (~matGlobalSettings[\transientBars] ? 1),
                     stretch: stretch, rev: rev);
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    (~lp[\matPlaying] == true).if({ ~matApplyBar.(~lp[\matBar] ? 0) });
};
```

- [ ] **Step 5: Apply stretch in the two pattern builders.** In `~matVariationOverlay`, change `\stretch, spec[\stretch]` to `\stretch, (spec[\stretch] * ~matTxStretch.value)`. In `~matColorStepPattern`, change `\stretch, spec[\stretch]` to `\stretch, (spec[\stretch] * ~matTxStretch.value)`.

- [ ] **Step 6: Apply the rev boost in `~matVariation`.** Replace the rev cdPair block:
```supercollider
                (spec[\rev].notNil).if({
                    cdPairs = cdPairs ++ [\rev, spec[\rev]] });
```
with:
```supercollider
                ((spec[\rev].notNil) or: { ~matTxRev.value > 0 }).if({
                    cdPairs = cdPairs ++ [\rev, ((spec[\rev] ? 0) + ~matTxRev.value).clip(0, 1)] });
```

- [ ] **Step 7: Track current name + next-preset.** In `~matLoad`, add as its first line `~matCurrentName = ~matSafeName.(name).asSymbol;`. In the global-actions block, after `~matGlobalSettingsPush` (or near `~matFireGlobal`), add:
```supercollider
~matCurrentName = ~matCurrentName ? nil;
~matAllNames = { (~matNames.(~matPresetDir) ++ ~matNames.(~matDir)).as(Set).asArray.sort };
~matNextPreset = {
    var names = ~matAllNames.value;
    (names.size > 0).if({
        var i = names.indexOf(~matCurrentName) ? -1;
        var nxt = names[(i + 1) % names.size];
        ~matLoad.(nxt);
        ~toscSend !? { ~toscSend.("/matrix/loaded", nxt.asString) };
    });
};
```

- [ ] **Step 8: Extend `~matFireGlobal` dispatch.** After the `\evolve` line, add:
```supercollider
    (act == \muteDrums).if({ ~matSetTransient.(\mute, ~matDrumVoices) });
    (act == \muteMelo).if({ ~matSetTransient.(\mute, ~matMeloVoices) });
    (act == \doubleTime).if({ ~matSetTransient.(\doubleTime, []) });
    (act == \halfTime).if({ ~matSetTransient.(\halfTime, []) });
    (act == \washReverb).if({ ~matSetTransient.(\washReverb, []) });
    (act == \next).if({ ~matNextPreset.() });
```

- [ ] **Step 9: Balance + harness.**
`awk` balance → `P:0 B:0`; `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–N).

- [ ] **Step 10: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): mute groups, time-warp, wash, next"
```

---

### Task 6: Web — extended action choices

**Files:** Modify `web_realart/public/control/js/matrix-state.js` (`GLOBAL_ACTION_CHOICES`); modify `web_realart/test/matrix-state.test.mjs`.

**Interfaces:**
- Consumes: `GLOBAL_ACTION_CHOICES`.
- Produces: the 6 new action ids in the dropdown vocabulary (the panel's dropdowns pick them up automatically).

- [ ] **Step 1: Failing test.** Append to `matrix-state.test.mjs`:
```javascript
test("extended action choices include phase-2 actions", () => {
  const ids = GLOBAL_ACTION_CHOICES.map((c) => c.id);
  for (const id of ["muteDrums", "muteMelo", "doubleTime", "halfTime", "washReverb", "next"])
    assert.ok(ids.includes(id), `missing action ${id}`);
});
```
(`GLOBAL_ACTION_CHOICES` is already imported in this file.)

- [ ] **Step 2: Run — expect FAIL** (ids absent).
Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: assertion failure on `muteDrums`.

- [ ] **Step 3: Extend the vocabulary.** In `matrix-state.js`, change `GLOBAL_ACTION_CHOICES` to append the 6 entries before the closing bracket:
```javascript
export const GLOBAL_ACTION_CHOICES = [
  { id: "none", label: "—" }, { id: "fill", label: "Fill" },
  { id: "drop", label: "Drop" }, { id: "breakdown", label: "Breakdown" },
  { id: "evolve", label: "Relance + evolve" },
  { id: "muteDrums", label: "Mute drums" }, { id: "muteMelo", label: "Mute mélo" },
  { id: "doubleTime", label: "Double-time" }, { id: "halfTime", label: "Half-time" },
  { id: "washReverb", label: "Wash reverb" }, { id: "next", label: "Suivant" },
];
```

- [ ] **Step 4: Run target + full suite — expect PASS.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs` then `node --test test/*.test.mjs` → all green.

- [ ] **Step 5: Commit.**
```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): extended global action choices"
```

---

### Task 7: Deploy + live smoke (macm1)

**Files:** none.

- [ ] **Step 1:** On user OK: `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'` (the committed `.matrix` already carry the new field; regen optional). SC engine reboot (kill `sclang boot.scd` + `scsynth`, relaunch `cd ~/Documents/Projets/AV-Live/sound_algo/data_only && MATRIX_ONLY=1 nohup script -q /tmp/sc_boot.log /Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd & ; wait for `[matrix] ready`).
- [ ] **Step 2:** Reglages: drop the "Seuil fermé (sensibilité)" slider and confirm the closed-hand fires more/less easily; raise transient duration and confirm the effect lasts longer; toggle a kept-voice and confirm breakdown keeps it. Save → reload → settings persist.
- [ ] **Step 3:** Vocabulary: map slots to muteDrums / muteMelo / doubleTime / halfTime / washReverb / next and confirm each by ear (drums cut, melo cut, tempo doubles/halves for the transient, reverb swells, next preset loads). Report to the user.

---

## Self-review

**Spec coverage (Phase 2 of the design):** `~matGlobalSettings` + thresholds (incl. close sensitivity) + duration + kept-voices → Task 1; generator default → Task 2; web settings state → Task 3; Réglages UI → Task 4; extended vocabulary muteDrums/muteMelo/doubleTime/halfTime/washReverb/next → Task 5; web choices → Task 6; smoke → Task 7. ✓

**Placeholder scan:** all code present; thresholds, factors (0.5/2.0/0.4), voice groups, OSC arg layouts are concrete; no TBD.

**Type consistency:** `~matGlobalSettings` keys (`openThresh`/`closeThresh`/`transientBars`/`breakdownKeep`) identical across SC (Task 1), generator literal (Task 2), web `matGlobalSettings`/`parseGlobalSettings` (Task 3-4). OSC arg layout `[openThresh, closeThresh, transientBars, keepN, keep0..]` identical in `~matGlobalSettingsPush`/`\mat_globalsettings` (SC) and `parseGlobalSettings`/`sendSettings` (web). Action ids (`muteDrums/muteMelo/doubleTime/halfTime/washReverb/next`) identical across `~matFireGlobal` (Task 5), `GLOBAL_ACTION_CHOICES` (Task 6). Transient `stretch`/`rev` keys set in `~matSetTransient` (Task 5 Step 4) and read by `~matTxStretch`/`~matTxRev` (Step 3) → used in `~matVariation*` (Steps 5-6). `~matDrumVoices`/`~matMeloVoices` defined Step 3, used Step 8. `~matCurrentName` set in `~matLoad` (Step 7), read in `~matNextPreset` (Step 7). `gset` persistence key matches in `saveMatState`/`loadMatState` (Task 3).
