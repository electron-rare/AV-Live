# Matrix fist-held gestures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A held closed fist fires a global action per hand — left fist → reload the current matrix, right fist → next preset — detected SC-side from hand openness, with a live sensitivity slider and per-hand progress indicators.

**Architecture:** The `/pose/hands` openness (`lOpen`/`rOpen`, already in `~matModCache`) drives an SC fist edge detector (`~matFistEdge`, hysteresis + presence guard); the existing 30 Hz pinch poller also runs `~matFistTick`, which fires the action once the fist is held ≥ `~matPinchHoldMs` and streams `/matrix/fistprogress`. A `~matFistThresh` sensitivity is a live menu slider, saved per `.matrix`.

**Tech Stack:** SuperCollider (sclang), Python 3 (uv), vanilla ES modules + `node --test`.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` ONE top-level block — `awk` balance `P:0 B:0` after every edit:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
- sclang: `/Applications/SuperCollider.app/Contents/MacOS/sclang <file>` (NOT on PATH; no `timeout`). Harness: `cd sound_algo/data_only/matrix_presets && sclang test_global_actions.scd` → `GLOBALACT PASS`.
- Python via uv; web `cd web_realart && node --test test/*.test.mjs` (GLOB). No `data_only_viz` / launcher change (openness already flows). Deploy = SC reboot + web reload (NO full launcher restart).
- Commit subject ≤ 50, no underscore in scope, no AI attribution, no `--no-verify`. No emojis. NOTE: keep `git commit` on its OWN command line (a compound `grep ... && git commit` trips the block-no-verify hook).
- Fist: hand 0 = screen-left (`lOpen`, `x=lHandX`), hand 1 = screen-right. Engage `openness <= ~matFistThresh`, release `openness >= ~matFistThresh + 0.15`, presence `x > 0.001`. Hold reuses `~matPinchHoldMs`. `~matFistThresh` default 0.15, clamp 0.05..0.5, saved per `.matrix` as top-level `fistThresh`. pointG (hand 0) = reload current (`~matCurrentName`); pointD (hand 1) = `~matNextPreset`.

## File Structure

- `sound_algo/data_only/matrix.scd` — `~matFistThresh`/state/`~matFistEdge`/`~matFistTick`/`~matFistReloadCurrent`/`~matFistThreshPush`; `/pose/hands` edge calls; poller adds `~matFistTick`; `/matrix/fisthresh[/get]`; `/matrix/fistprogress`; save/load.
- `sound_algo/data_only/matrix_presets/{generate_presets.py,test_global_actions.{py,scd}}` — `fistThresh` emit + harness Q.
- `web_realart/public/control/{js/matrix-state.js,js/morceau-panel.js,index.html,control.css}` + `web_realart/test/matrix-state.test.mjs`.

---

### Task 1: SC — fist detection + hold-to-fire + progress

**Files:** Modify `sound_algo/data_only/matrix.scd` + `sound_algo/data_only/matrix_presets/test_global_actions.scd`.

**Interfaces:**
- Consumes: `~matModCache`, `~matPinchHoldMs`, `~matCurrentName`, `~matNextPreset`, `~matLoad`, `~matSave`/`~matLoadFile`, `~toscSend`/`~toscTouch`, the pinch poller `~matPinchRoutine`.
- Produces: `~matFistThresh`, `~matFistState`/`~matFistHeld`/`~matFistFired`, `~matFistEdge.(hand,x,openness)`, `~matFistTick`, `~matFistReloadCurrent`, `~matFistThreshPush`; `/matrix/fisthresh[/get]` set+echo; `/matrix/fistprogress [hand, prog]`; `fistThresh` saved per `.matrix`.

- [ ] **Step 1: Append failing harness group Q** to `test_global_actions.scd`, before the final `pass.if(...)`:
```supercollider
// -- Q: fist hold-to-fire (engage records, tick fires, release/absent cancel, threshold, save) --
~matPinchRoutine !? { ~matPinchRoutine.stop };
~matPinchHoldMs = 300; ~matFistThresh = 0.15;
~matFistState = Array.fill(2, \unknown); ~matFistHeld = Array.fill(2, nil); ~matFistFired = Array.fill(2, false);
~loadedFist = nil; ~matCurrentName = \zztest_morceau;
~matLoadReal = ~matLoad; ~matLoad = { |n| ~loadedFist = n.asSymbol };
~matFistEdge.(0, 0.5, 0.05);                              // L fist engage -> held, no fire
(~matFistHeld[0].isNil).if({ pass = false; "FAIL: L fist engage not held".postln });
~matFistTick.();
(~loadedFist.notNil).if({ pass = false; "FAIL: L fist fired before hold".postln });
~matFistHeld[0] = Main.elapsedTime - 0.5;                 // 500ms held (> 300)
~matFistTick.();
(~loadedFist == \zztest_morceau).not.if({ pass = false; "FAIL: L fist hold did not reload current".postln });
~loadedFist = nil; ~matFistState = Array.fill(2, \unknown); ~matFistHeld = Array.fill(2, nil); ~matFistFired = Array.fill(2, false);
~matFistEdge.(1, 0.5, 0.05);                              // R fist engage
~matFistEdge.(1, 0.5, 0.40);                              // open (>= 0.30) -> release
~matFistTick.();
(~matFistHeld[1].isNil).not.if({ pass = false; "FAIL: R fist release did not clear".postln });
~matFistState = Array.fill(2, \unknown); ~matFistHeld = Array.fill(2, nil);
~matFistEdge.(0, 0.0, 0.0);                               // absent hand (x=0, openness 0) must NOT engage
(~matFistHeld[0].isNil).not.if({ pass = false; "FAIL: absent hand engaged a fist".postln });
OSCdef(\mat_fisthresh).func.value(['/matrix/fisthresh', 0.25]);
(~matFistThresh == 0.25).not.if({ pass = false; "FAIL: fisthresh not set".postln });
~matFistThresh = 0.15; ~matLoad = ~matLoadReal;
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matFistThresh = 0.22; ~matSave.("zz_fth_test"); ~matFistThresh = 0.15;
~matLoadFile.(~matDir +/+ "zz_fth_test.matrix");
(~matFistThresh == 0.22).not.if({ pass = false; "FAIL: fistThresh not restored".postln });
("rm -f '" ++ (~matDir +/+ "zz_fth_test.matrix") ++ "'").systemCmd;
```

- [ ] **Step 2: Run — expect FAIL** (`~matFistEdge`/`~matFistTick` undefined).
Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: error / `GLOBALACT FAIL`.

- [ ] **Step 3: Add the fist state + detection + tick.** In the global-actions block (after `~matPinchHoldPush` / the pinch state), add:
```supercollider
~matFistThresh = ~matFistThresh ? 0.15;
~matFistState  = ~matFistState  ? Array.fill(2, \unknown);
~matFistHeld   = ~matFistHeld   ? Array.fill(2, nil);
~matFistFired  = ~matFistFired  ? Array.fill(2, false);
~matFistThreshPush = { ~toscSend !? { ~toscSend.("/matrix/fisthresh", ~matFistThresh) } };
~matFistReloadCurrent = {
    ~matCurrentName.notNil.if({
        ~matLoad.(~matCurrentName);
        ~toscSend !? { ~toscSend.("/matrix/loaded", ~matCurrentName.asString) };
    });
};
// fist edge from openness (hysteresis + presence guard). hand 0 = L, 1 = R.
~matFistEdge = { |hand, x, openness|
    var present = x > 0.001;
    var prev = ~matFistState[hand] ? \unknown;
    var cur = present.if({
        (openness <= ~matFistThresh).if({ \fist },
        { (openness >= (~matFistThresh + 0.15)).if({ \open }, { prev }) })
    }, { \unknown });
    ((prev != \fist) and: { cur == \fist }).if({
        ~matFistHeld[hand] = Main.elapsedTime; ~matFistFired[hand] = false;
    });
    ((prev == \fist) and: { cur != \fist }).if({
        ~matFistHeld[hand] = nil; ~matFistFired[hand] = false;
        ~toscSend !? { ~toscSend.("/matrix/fistprogress", hand, 0) };
    });
    ~matFistState[hand] = cur;
};
~matFistTick = {
    2.do { |hand|
        (~matFistHeld[hand].notNil).if({
            var prog = (((Main.elapsedTime - ~matFistHeld[hand]) * 1000) / ~matPinchHoldMs).clip(0, 1);
            ~toscSend !? { ~toscSend.("/matrix/fistprogress", hand, prog) };
            ((prog >= 1.0) and: { ~matFistFired[hand].not }).if({
                ~matFistFired[hand] = true;
                (hand == 0).if({ ~matFistReloadCurrent.() }, { ~matNextPreset.() });
            });
        });
    };
};
```

- [ ] **Step 4: Call the edge from `/pose/hands` + add to the poller.** In the `\mat_mod_hands` OSCdef, add before its closing `}, '/pose/hands');`:
```supercollider
    ~matFistEdge.(0, msg[2] ? 0, msg[4] ? 0);
    ~matFistEdge.(1, msg[6] ? 0, msg[8] ? 0);
```
Change the pinch poller line to also tick fists. Replace:
```supercollider
~matPinchRoutine = Routine({ loop { ~matPinchTick.(); (1/30).wait } }).play(AppClock);
```
with:
```supercollider
~matPinchRoutine = Routine({ loop { ~matPinchTick.(); ~matFistTick.(); (1/30).wait } }).play(AppClock);
```

- [ ] **Step 5: OSC routes.** After the `\mat_pinchhold_get` OSCdef, add:
```supercollider
OSCdef(\mat_fisthresh, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matFistThresh = (msg[1] ? 0.15).asFloat.clip(0.05, 0.5);
    ~matFistThreshPush.()
}, '/matrix/fisthresh');
OSCdef(\mat_fisthresh_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matFistThreshPush.()
}, '/matrix/fisthresh/get');
```

- [ ] **Step 6: Save/load `fistThresh`.** In `~matSave`'s `payload`, add after `pinchHoldMs: ~matPinchHoldMs`:
```supercollider
        pinchHoldMs: ~matPinchHoldMs,
        fistThresh: ~matFistThresh
```
In `~matLoadFile`, just after the `pinchHoldMs` restore line, add:
```supercollider
            ~matFistThresh = ((raw.isArray.not) and: { raw[\fistThresh].notNil }).if({ raw[\fistThresh].asFloat.clip(0.05, 0.5) }, { 0.15 });
```
And after `~matPinchHoldPush.();` add `~matFistThreshPush.();`.

- [ ] **Step 7: Balance + harness.**
`awk` balance → `P:0 B:0`; `sclang test_global_actions.scd` → `GLOBALACT PASS` (A–Q).

- [ ] **Step 8: Commit** (own command line):
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): fist-held gestures (reload/next)"
```

---

### Task 2: Generator — emit `fistThresh`

**Files:** Modify `generate_presets.py` (`to_sc`), `test_global_actions.py`; regenerate `*.matrix`.

- [ ] **Step 1: Test (failing).** In `test_global_actions.py`, add after the `EXPECT_PHMS` block:
```python
EXPECT_FTH = "'fistThresh': 0.15"
check(EXPECT_FTH in sample, "to_sc output missing fistThresh")
missing_fth = [os.path.basename(f) for f in files
               if EXPECT_FTH not in open(f, encoding="utf-8").read()]
check(not missing_fth, "fistThresh missing in: %s" % missing_fth[:5])
```

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd sound_algo/data_only/matrix_presets && uv run python test_global_actions.py`
Expected: `FAIL: to_sc output missing fistThresh`.

- [ ] **Step 3: Emit it.** In `to_sc`, change the tail so `pinchHoldMs` ends with a comma and `fistThresh` is last. Replace:
```python
            "'pinchHoldMs': 300\n)\n"
```
with:
```python
            "'pinchHoldMs': 300,\n"
            "'fistThresh': 0.15\n)\n"
```

- [ ] **Step 4: Regen (twice) + gates.**
`uv run python generate_presets.py` (twice). Then `uv run python test_global_actions.py` (`GLOBALACT-PY PASS`), `uv run python test_sections.py` (`TEST PASS`), `uv run python test_families.py` (`TEST PASS`), `/Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd` (`GLOBALACT PASS`).

- [ ] **Step 5: Commit** (own command line):
```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_global_actions.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): emit default fist threshold"
```

---

### Task 3: Web — fist sensitivity slider + fist indicators

**Files:** Modify `web_realart/public/control/js/matrix-state.js`, `js/morceau-panel.js`, `index.html`, `control.css`, `web_realart/test/matrix-state.test.mjs`.

**Interfaces:**
- Consumes: SC `/matrix/fisthresh` + `/matrix/fistprogress`.
- Produces: `matFistThresh` state + persistence; a "Sensibilité poing" slider; two fist indicator rows with progress fill.

- [ ] **Step 1: State test (failing).** Append to `matrix-state.test.mjs`:
```javascript
import { matFistThresh, setFistThresh } from "../public/control/js/matrix-state.js";
test("default fist threshold + setter", () => {
  assert.equal(matFistThresh, 0.15);
  setFistThresh(0.3);
  assert.equal(matFistThresh, 0.3);
  setFistThresh(0.15);
});
```

- [ ] **Step 2: Run — expect FAIL.**
Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: import failure.

- [ ] **Step 3: Add state.** In `matrix-state.js`, after `matPinchHoldMs`, add:
```javascript
export let matFistThresh = 0.15;
export function setFistThresh(v) { matFistThresh = v; }
```
In `saveMatState`, add `fth: matFistThresh` to the blob; in `loadMatState`, after the `phms` restore, add:
```javascript
      if (Number.isFinite(raw.fth)) matFistThresh = raw.fth;
```

- [ ] **Step 4: Container.** In `index.html`, inside `#morceau-panel` after `#morceau-settings`, add:
```html
    <div class="morceau-title">Poings</div>
    <div id="morceau-fists" class="morceau-fists"></div>
```

- [ ] **Step 5: Render fist indicators + sensitivity slider in `morceau-panel.js`.** After the Réglages block (and the pinch-hold slider), add:
```javascript
  // --- Sensibilite poing slider (in Reglages) ---
  if (sHost) {
    const fRow = document.createElement("label");
    fRow.className = "morceau-set-row";
    const fSpan = document.createElement("span"); fSpan.textContent = "Sensibilité poing";
    const fInp = document.createElement("input");
    fInp.type = "range"; fInp.min = 0.05; fInp.max = 0.5; fInp.step = 0.01; fInp.value = matFistThresh;
    const fOut = document.createElement("output"); fOut.textContent = matFistThresh;
    fInp.addEventListener("input", () => { fOut.textContent = fInp.value; });
    fInp.addEventListener("change", () => { setFistThresh(+fInp.value); send("/matrix/fisthresh", +fInp.value); saveMatState(); });
    fRow.append(fSpan, fInp, fOut);
    sHost.appendChild(fRow);
    on("/matrix/fisthresh", (args) => {
      const v = Number(args[0]);
      if (Number.isFinite(v)) { fInp.value = v; fOut.textContent = v; setFistThresh(v); saveMatState(); }
    });
    onOpen(() => send("/matrix/fisthresh/get"));
    send("/matrix/fisthresh/get");
  }
  // --- Fist indicators (hand 0 = Poing G -> charger, hand 1 = Poing D -> suivant) ---
  const fistHost = document.getElementById("morceau-fists");
  if (fistHost) {
    const fistFills = [];
    [["Poing G → charger"], ["Poing D → suivant"]].forEach((lbl, hand) => {
      const row = document.createElement("div");
      row.className = "morceau-fist";
      row.textContent = lbl[0];
      const fl = document.createElement("div");
      fl.className = "morceau-slot-fill";
      row.appendChild(fl);
      fistFills[hand] = fl;
      fistHost.appendChild(row);
    });
    on("/matrix/fistprogress", (args) => {
      const hand = Math.round(Number(args[0]));
      const prog = Number(args[1]) || 0;
      const fl = fistFills[hand];
      if (!fl) return;
      fl.style.width = (prog * 100) + "%";
      fl.classList.toggle("fired", prog >= 1);
    });
  }
```
Add `matFistThresh, setFistThresh` to the `matrix-state.js` import.

- [ ] **Step 6: Style.** Append to `control.css`:
```css
.morceau-fists { display: flex; flex-direction: column; gap: 4px; }
.morceau-fist { position: relative; font-size: 12px; color: #ccc; padding: 2px 4px;
  background: #1c1c1c; border-radius: 4px; }
```
(`.morceau-slot-fill` + `.fired` already exist from the pinch work.)

- [ ] **Step 7: Parse + suite.**
Run: `cd web_realart && node --check public/control/js/morceau-panel.js` (no output) and `node --test test/*.test.mjs` (all green).

- [ ] **Step 8: Commit** (own command line):
```bash
git add web_realart/public/control/js/matrix-state.js web_realart/public/control/js/morceau-panel.js web_realart/public/control/index.html web_realart/public/control/control.css web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): fist sensitivity slider + indicators"
```

---

### Task 4: Deploy + live smoke (macm1)

**Files:** none.

- [ ] **Step 1:** On user OK: `git push origin main`; `ssh macm1 'cd ~/Documents/Projets/AV-Live && git pull --ff-only'`. No launcher restart needed — SC-only reboot (kill `sclang boot.scd` + `scsynth`; relaunch `cd ~/Documents/Projets/AV-Live/sound_algo/data_only && MATRIX_ONLY=1 nohup script -q /tmp/sc_boot.log /Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd &`; wait `[matrix] ready`). Hard-reload the web page (the pose pipeline keeps running; openness keeps flowing).
- [ ] **Step 2:** Hold a LEFT fist → the "Poing G" cell fills then reloads the current morceau; hold a RIGHT fist → next preset; the "Sensibilité poing" slider changes how low the openness must drop; a brief/open fist does nothing; hands out of frame never trigger. Report to the user.

---

## Self-review

**Spec coverage:** fist detection (hysteresis + presence) → Task 1 Step 3-4; hold-to-fire reusing `~matPinchHoldMs` + actions (reload-current / next) → Task 1 Step 3; progress stream → Task 1 Step 3-4; `/matrix/fisthresh` + save/load → Task 1 Steps 5-6; generator `fistThresh` → Task 2; web sensitivity slider + indicators → Task 3; smoke → Task 4. ✓

**Placeholder scan:** complete code; threshold 0.15/clamp 0.05-0.5, hysteresis +0.15, hand 0/1 indices concrete; no TBD.

**Type consistency:** `~matFistEdge.(hand, x, openness)` called with L `(0, msg[2], msg[4])` / R `(1, msg[6], msg[8])` (Task 1 Step 4). `~matFistTick` fires hand 0 → `~matFistReloadCurrent` (uses `~matCurrentName` + `~matLoad`), hand 1 → `~matNextPreset` (both exist). `/matrix/fistprogress [hand, prog]` emitted (Task 1) ↔ web `on("/matrix/fistprogress")` `fistFills[hand]` (Task 3). `/matrix/fisthresh` single-Float (SC clamp 0.05-0.5 ↔ web slider 0.05-0.5). `fistThresh` save field consistent SC ↔ generator literal. Hold reuses `~matPinchHoldMs` (no new hold setting). `.morceau-slot-fill`/`.fired` reused from the pinch CSS.
