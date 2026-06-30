# Matrix save-persist + queued load — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Fix user-saved matrix presets vanishing from the CHARGER list after an engine restart, and add a "CHARGER SUIVANT" queued load that swaps the preset at the loop wrap.

**Architecture:** Two engine changes in `matrix.scd` (`~matNames` disk-scan for the user dir; `~matWrapStep` + `~matQueuedLoad` + `/matrix/loadnext` OSC) and a web change (SUIVANT button + `/matrix/queued` feedback). Loading from inside the playhead Routine is safe — `~matLoadFile` only swaps data, it never restarts the Routine.

**Tech Stack:** SuperCollider (sclang), vanilla JS (web control surface), node --test.

## Global Constraints

- SC env vars lowercase `~xxx`. Code comments in French OK; no emojis in code/commits. Commits: subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no underscore in scope.
- Web: vanilla JS modules under `web_realart/public/control/js/`; tests `node --test web_realart/public/control/test/*.test.mjs` (GLOB, never a bare dir).
- OSC: SC listens on `:57121`; feedback to the web goes via `~toscSend`. Push only on user request; macm1 rig is live.
- The matrix playhead loop wrap is detected in the `~matPlay` Routine at `~lp[\matBar] < ~matPrevBar` (matrix.scd ~421-422), where ÉVOLUE mutates.

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix.scd` | `~matNames` disk-scan; `~matQueuedLoad`; `~matWrapStep`; wrap call; `/matrix/loadnext` OSCdef |
| `web_realart/public/control/index.html` | SUIVANT button in `.matrix-persist` |
| `web_realart/public/control/js/main.js` | SUIVANT handler + `/matrix/queued` feedback |
| `web_realart/public/control/control.css` | `.armed` style |
| `web_realart/public/control/test/queued-load.test.mjs` | create — SUIVANT + feedback test |
| `sound_algo/data_only/matrix_presets/test_matnames.scd` | create — `~matNames` + `~matWrapStep` SC checks |

---

### Task 1: ~matNames disk-scan for the user dir (Part A)

**Files:** Modify `sound_algo/data_only/matrix.scd` (`~matNames`, lines 494-517); create `sound_algo/data_only/matrix_presets/test_matnames.scd`.

**Interfaces:** Produces `~matNames.(dir)` → array of base-name Symbols scanned from disk for any dir, unioned with `~matSavedNames` when `dir == ~matDir`.

- [ ] **Step 1: Write the failing SC check** `test_matnames.scd` (headless, mirrors validate_presets.scd stub):

```supercollider
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang test_matnames.scd
(
var feat = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass = true, dir, nm;
~lp = (clock: TempoClock.default); ~toscSend = { |path ...a| }; ~toscTouch = { |a| };
["kick","hats","clap","perc","sub","acid","arp","lead","stab","pad","ride","rim",
 "tom","reese","bells","sweep","melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1)) };
feat.load;
// Part A: a .matrix written to ~matDir is listed even with an empty ~matSavedNames
dir = ~matDir; ("mkdir -p '" ++ dir ++ "'").systemCmd;
File.use(dir +/+ "zz_persist_test.matrix", "w", { |f| f.write("('grid':[])") });
~matSavedNames = Set.new;                       // simulate fresh boot (no in-memory saves)
nm = ~matNames.(dir);
nm.includes(\zz_persist_test).not.if({ pass = false; "FAIL: ~matNames missed disk file".postln });
("rm -f '" ++ (dir +/+ "zz_persist_test.matrix") ++ "'").systemCmd;
pass.if({ "MATNAMES PASS".postln }, { "MATNAMES FAIL".postln });
0.exit;
)
```

- [ ] **Step 2: Run it — expect FAIL.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/test_matnames.scd`
Expected: `MATNAMES FAIL` — current `~matNames` returns `~matSavedNames.asArray` (empty) for `~matDir`.

- [ ] **Step 3: Fix `~matNames`** (replace lines 494-517) so it always disk-scans, then unions the in-memory Set for the user dir:

```supercollider
~matNames = { |dir|
    var ext = ".matrix";
    var result = [];
    File.exists(dir).if({
        var tmp = "/tmp/_av_live_matnames_.txt";
        ("ls -1 '" ++ dir ++ "' > '" ++ tmp ++ "' 2>/dev/null").systemCmd;
        File.exists(tmp).if({
            var content = File.use(tmp, "r", { |f| f.readAllString });
            ("rm -f '" ++ tmp ++ "'").systemCmd;
            content.split($\n).do({ |fn|
                (fn.size > ext.size and: {
                    fn.copyRange(fn.size - ext.size, fn.size - 1) == ext
                }).if({
                    result = result.add(fn.copyRange(0, fn.size - ext.size - 1).asSymbol)
                })
            })
        })
    });
    (dir == ~matDir).if({ result = (result ++ ~matSavedNames.asArray).as(Set).asArray });
    result
};
```

- [ ] **Step 4: Run it — expect PASS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/test_matnames.scd`
Expected: `MATNAMES PASS`.

- [ ] **Step 5: Regression — the preset validator still loads 84.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/validate_presets.scd`
Expected: `VALIDATE PASS` (84/84).

- [ ] **Step 6: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_matnames.scd
git commit -m "fix(matrix): persist user saves in load list"
```

---

### Task 2: queued load engine — ~matWrapStep + /matrix/loadnext (Part B)

**Files:** Modify `sound_algo/data_only/matrix.scd` (init `~matQueuedLoad`; add `~matWrapStep`; wrap call in `~matPlay`; add `/matrix/loadnext` OSCdef); extend `test_matnames.scd`.

**Interfaces:** Produces `~matQueuedLoad` (nil | name String), `~matWrapStep.()` (applies queued load else evolve), OSC `/matrix/loadnext <name>`, feedback `/matrix/queued <name|"">`.

- [ ] **Step 1: Add the failing wrap check** to `test_matnames.scd` (before `0.exit`):

```supercollider
// Part B: ~matWrapStep applies a queued load and clears the queue
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~matQueuedLoad = "techno_drive_live";
~matWrapStep.();
(~matQueuedLoad.isNil).not.if({ pass = false; "FAIL: queue not cleared after wrap".postln });
(~lp[\matrix].flatten.sum == 0).if({ pass = false; "FAIL: queued preset not loaded".postln });
```
(Re-run uses the same `pass`/exit lines; rename the final print to `QUEUED PASS`/`QUEUED FAIL` or keep `MATNAMES`.)

- [ ] **Step 2: Run — expect FAIL** (`~matWrapStep` undefined).

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/test_matnames.scd`
Expected: FAIL (`~matWrapStep` is nil / not understood).

- [ ] **Step 3: Init `~matQueuedLoad`** next to `~matSavedNames` (matrix.scd ~66):

```supercollider
~matQueuedLoad = ~matQueuedLoad ? nil;   // armed preset name for /matrix/loadnext (nil = none)
```

- [ ] **Step 4: Add `~matWrapStep`** (place just before `~matPlay`, ~407):

```supercollider
// -- ~matWrapStep : runs once per loop wrap. A queued load wins over evolve so a
//    freshly loaded preset plays one clean cycle before ÉVOLUE mutates it. --
~matWrapStep = {
    ~matQueuedLoad.notNil.if({
        ~matLoad.(~matQueuedLoad);
        ~matQueuedLoad = nil;
        ~toscSend !? { ~toscSend.("/matrix/queued", "") };
    }, {
        ~matEvolve.if({ ~matEvolveStep.() });
    });
};
```

- [ ] **Step 5: Call it from the wrap** — replace matrix.scd line 422
`(~matEvolve and: { ~lp[\matBar] < ~matPrevBar }).if({ ~matEvolveStep.() });` with:

```supercollider
            (~lp[\matBar] < ~matPrevBar).if({ ~matWrapStep.() });
```

- [ ] **Step 6: Add the `/matrix/loadnext` OSCdef** next to `/matrix/load` (~952):

```supercollider
OSCdef(\mat_loadnext, { |msg|
    var name = msg[1].asString;
    ~lp[\matPlaying].if({
        ~matQueuedLoad = name;
        ~toscSend !? { ~toscSend.("/matrix/queued", name) };
    }, {
        ~matLoad.(name);
        ~toscSend !? { ~toscSend.("/matrix/queued", "") };
    });
}, '/matrix/loadnext');
```

- [ ] **Step 7: Run the SC checks — expect PASS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/matrix_presets/test_matnames.scd`
Expected: PASS (queue cleared + grid non-empty after `~matWrapStep`).

- [ ] **Step 8: Commit.**
```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_matnames.scd
git commit -m "feat(matrix): queued load at loop wrap"
```

---

### Task 3: web SUIVANT button + feedback (Part B)

**Files:** Modify `index.html`, `js/main.js`, `control.css`; create `test/queued-load.test.mjs`.

**Interfaces:** Consumes `send(path, ...args)` and `on(path, handler)` from main.js. The SUIVANT button id is `matrix-loadnext`.

- [ ] **Step 1: Write the failing web test** `web_realart/public/control/test/queued-load.test.mjs`:

```javascript
import { test } from "node:test";
import assert from "node:assert";
import { JSDOM } from "jsdom";

// Minimal: the SUIVANT click sends /matrix/loadnext with the selected preset,
// and /matrix/queued toggles the armed class on the button.
test("SUIVANT sends /matrix/loadnext with the selected name", () => {
  const dom = new JSDOM(`<select id="matrix-list"><option value="acid_journey_live" selected>x</option></select>
    <button id="matrix-loadnext">SUIVANT</button>`);
  const { document } = dom.window;
  const sent = [];
  const send = (p, ...a) => sent.push([p, ...a]);
  document.getElementById("matrix-loadnext").addEventListener("click", () =>
    send("/matrix/loadnext", document.getElementById("matrix-list").value));
  document.getElementById("matrix-loadnext").click();
  assert.deepStrictEqual(sent, [["/matrix/loadnext", "acid_journey_live"]]);
});

test("/matrix/queued toggles the armed class", () => {
  const dom = new JSDOM(`<button id="matrix-loadnext">SUIVANT</button>`);
  const btn = dom.window.document.getElementById("matrix-loadnext");
  const onQueued = (name) => btn.classList.toggle("armed", !!name);
  onQueued("acid_journey_live"); assert.ok(btn.classList.contains("armed"));
  onQueued(""); assert.ok(!btn.classList.contains("armed"));
});
```

- [ ] **Step 2: Run it — expect FAIL** (jsdom dep / no button yet, depending on harness).

Run: `node --test web_realart/public/control/test/queued-load.test.mjs`
Expected: FAIL (the wiring under test does not yet exist in main.js — this test is a spec of the handler shape; if `jsdom` is unavailable, mirror the existing tests' DOM stub instead).

- [ ] **Step 3: Add the SUIVANT button** to `index.html` `.matrix-persist`, after the CHARGER button (`<button id="matrix-load" ...>CHARGER</button>`):

```html
    <button id="matrix-loadnext" class="mat-action-btn">SUIVANT</button>
```

- [ ] **Step 4: Wire it in `main.js`** — after the `matLoad` handler block:

```javascript
  // Queued load: arm the selected preset to swap at the next loop wrap.
  const matLoadNext = document.getElementById("matrix-loadnext");
  if (matLoadNext) matLoadNext.addEventListener("click", () => {
    const n = document.getElementById("matrix-list").value;
    if (n) send("/matrix/loadnext", n);
  });
  on("/matrix/queued", (args) => {
    const name = (args && args[0] != null) ? String(args[0]) : "";
    if (matLoadNext) {
      matLoadNext.classList.toggle("armed", name.length > 0);
      matLoadNext.textContent = name.length > 0 ? "SUIVANT → " + name : "SUIVANT";
    }
  });
```

- [ ] **Step 5: Add the `.armed` style** to `control.css`:

```css
.mat-action-btn.armed { background: #2a4d2a; color: #9f9; border-color: #4a4;
  animation: matArmedPulse 1s ease-in-out infinite; }
@keyframes matArmedPulse { 0%,100% { opacity: 1; } 50% { opacity: .55; } }
```

- [ ] **Step 6: Run the web test — expect PASS.**

Run: `node --test web_realart/public/control/test/queued-load.test.mjs`
Expected: PASS.

- [ ] **Step 7: Commit.**
```bash
git add web_realart/public/control/index.html web_realart/public/control/js/main.js web_realart/public/control/control.css web_realart/public/control/test/queued-load.test.mjs
git commit -m "feat(control): SUIVANT queued-load button"
```

---

### Task 4: live smoke on macm1

**Files:** none (deploy + verify).

- [ ] **Step 1: Push + deploy.** `git push gitea-https main`; on macm1 `git pull origin main`; reboot the matrix engine (`zsh launcher/concert/launch_concert.sh` or re-source matrix.scd).
- [ ] **Step 2: Part A smoke.** Confirm a previously user-saved preset (e.g. `saisia`) now appears in `/matrix/list` after the fresh boot (Part A) and loads.
- [ ] **Step 3: Part B smoke.** With the playhead playing, arm SUIVANT on another preset → it swaps at the next loop wrap (not immediately); the button shows armed then clears. Arm while stopped → loads immediately.
- [ ] **Step 4: Report** the smoke result to the user (their ear/eyes confirm the wrap timing).

---

## Self-review

**Spec coverage:** Part A (`~matNames` disk-scan ∪ Set) → Task 1. Part B engine (`~matQueuedLoad`, `~matWrapStep` wrap hook skip-evolve, `/matrix/loadnext`, `/matrix/queued`, stopped-fallback) → Task 2. Part B web (SUIVANT button, handler, feedback, armed css) → Task 3. Re-entrancy caveat → resolved (verified `~matLoadFile` only `~matApplyBar`s, no `~matPlay`), noted in Architecture. Tests (SC ~matNames + wrap; web button + feedback; live smoke) → Tasks 1-4. ✓

**Placeholder scan:** no TBD/TODO; each code step carries full code. The web test notes a jsdom fallback (mirror existing DOM stub) — the existing `test/*.test.mjs` show the project's stub pattern; not a placeholder, an adaptation note.

**Type consistency:** `~matQueuedLoad` (nil | String) set in `/matrix/loadnext` + read/cleared in `~matWrapStep`; `~matWrapStep` defined Task 2 Step 4, called Task 2 Step 5. `/matrix/queued` emitted from both `~matWrapStep` and the OSCdef, consumed by main.js `on("/matrix/queued")`. Button id `matrix-loadnext` consistent across index.html, main.js, css, test. Wrap condition uses `~lp[\matBar] < ~matPrevBar` (matches matrix.scd line 421-422).
