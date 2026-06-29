# Matrix generative per-cycle evolution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At each 64-bar loop wrap, recolour ~15% of active matrix cells from an immutable base snapshot so the cycle never repeats identically, staying close to the preset.

**Architecture:** Add `~matBaseGrid` (clean snapshot, taken on enable), `~matEvolve`/`~matEvolveRate`, a `~matEvolveStep` that re-derives the working grid `~lp[\matrix]` from the base each cycle (recolour active cells only, bounded), triggered at the loop wrap in `~matPlay`'s routine. Live edits dual-write to the base; save serializes the base. New OSC routes + a minor web toggle/slider.

**Tech Stack:** SuperCollider (sclang, no server for tests), vanilla ES + `node --test` (`web_realart`).

## Global Constraints

- No emojis in code/docs/commits. Commits: subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no `--no-verify`, no underscore in commit scope.
- `.scd` balanced P:0 B:0 — run `validating-scd-files` after every `.scd` edit.
- SC tests: `sound_algo/data_only/test/test_matrix.scd` (NO server; stubs `~toscSend`/`~toscTouch`; `pass = pass and:{...}` + `try{}`; ends `0.exit`; final `TEST PASS`). Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd` (binary not on PATH; no `timeout` binary).
- Web tests: `cd web_realart && node --test test/*.test.mjs` (GLOB form required).
- Defaults: `~matEvolve` false, `~matEvolveRate` 0.15 (env-tunable `? 0.15`). Recolour active cells only (0 stays 0); bounded (re-derive from base, no accumulation); mutated colour ≠ base and ∈ 1..6. Push only on user request. macm1 is the live host.

## Key existing code (anchors — line numbers drift, grep by name)

- `~matNextBar` (~290): `{ var nb = ~lp[\matBar]+1; ... wrap to ls; nb.clip(...) }`.
- `~matApplyBar` (~296): reads `~lp[\matrix][vi][bar]`, re-sources per `~matLastColor`.
- `~matPlay` routine (~368-375): `loop { ~matApplyBar.(~lp[\matBar]); ...playhead; ~matBeatsPerBar.wait; ~lp[\matBar] = ~matNextBar.value; }`.
- `~matSetCell` (~389): `~lp[\matrix][vi][bar] = color.clip(0,6).asInteger; ...; ~toscSend.("/matrix/cell"...)`.
- `~matGridPush` (~469): pushes the whole grid to surfaces.
- `~matSave` (~590): payload `(grid: ~lp[\matrix], instruments:..., colorDefs:..., voiceMods:..., voicePoses:...)`.
- `~matLoadFile` (~617): `~lp[\matrix] = grid`.
- Matrix OSCdefs region (~860): `\mat_cell` (`/matrix/cell`), `\mat_play` (`/matrix/play`).

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix.scd` | `~matEvolve`/`~matEvolveRate`/`~matBaseGrid` decls; `~matEvolveStep`; `~matSetEvolve`; `~matEvolvePush`; routine wrap-trigger; `~matSetCell` dual-write; `~matSave` base; `~matLoadFile` re-snapshot; OSCdefs `\mat_evolve`/`\mat_evolverate` |
| `sound_algo/data_only/test/test_matrix.scd` | evolve mutation + snapshot/restore + edit/save integration assertions |
| `web_realart/public/control/js/matrix-grid.js` (or transport area) | ÉVOLUE toggle + rate slider + `/matrix/evolve` echo handler |
| `web_realart/test/matrix-state.test.mjs` | (if a pure parse helper is added) payload shape |

---

### Task 1: evolve core — state, mutation, enable/disable, wrap trigger

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (decls near `~matBars`/`~matLastColor` ~20-27; new fns near `~matApplyBar` ~322; routine ~373)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matEvolve` (Bool), `~matEvolveRate` (Float), `~matBaseGrid` (2D Array or nil), `~matEvolveStep.()` (mutates `~lp[\matrix]` from `~matBaseGrid`), `~matSetEvolve.(onBool)` (snapshot/restore + push), `~matEvolvePush.()`.
- Consumes: `~lp[\matrix]`, `~matVoices`, `~matBars`, `~matGridPush`, `~matLastColor`, `~toscSend`.

- [ ] **Step 1: Write the failing test.** Add to `test_matrix.scd` (near the grid/cell tests):

```supercollider
// --- generative evolve (SP-B) ---
// build a base grid with known 0 and active cells (small 2-voice fixture in-place)
~evBase = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~evBase[0][0] = 3; ~evBase[0][1] = 0; ~evBase[0][2] = 5;   // kick: active,0,active
~evBase[1][0] = 0; ~evBase[1][4] = 2;                       // hats: 0,...,active
~matBaseGrid = ~evBase.collect({ |row| row.copy });
~lp[\matrix] = ~evBase.collect({ |row| row.copy });
~matEvolveRate = 1.0;   // mutate every active cell
~matEvolveStep.();
// density preserved: 0-cells stay 0, active stay active (1..6)
pass = pass and: { ~lp[\matrix][0][1] == 0 };       // base 0 stays 0
pass = pass and: { ~lp[\matrix][1][0] == 0 };
pass = pass and: { (~lp[\matrix][0][0] >= 1) and: { ~lp[\matrix][0][0] <= 6 } };
pass = pass and: { (~lp[\matrix][0][2] >= 1) and: { ~lp[\matrix][0][2] <= 6 } };
pass = pass and: { (~lp[\matrix][1][4] >= 1) and: { ~lp[\matrix][1][4] <= 6 } };
// recolour differs from base (rate 1.0 guarantees a change)
pass = pass and: { ~lp[\matrix][0][0] != 3 };
pass = pass and: { ~lp[\matrix][0][2] != 5 };
pass = pass and: { ~lp[\matrix][1][4] != 2 };
// rate 0 -> identical to base
~matEvolveRate = 0.0;
~lp[\matrix] = ~evBase.collect({ |row| row.copy });
~matEvolveStep.();
pass = pass and: { ~lp[\matrix][0][0] == 3 and: { ~lp[\matrix][0][2] == 5 } };
// bounded: base is untouched by mutation; setEvolve(false) restores base exactly
~matEvolveRate = 1.0;
~matSetEvolve.(true);                 // snapshots current ~lp[\matrix] as base
~evSnap = ~matBaseGrid.collect({ |row| row.copy });
~matEvolveStep.(); ~matEvolveStep.(); // two cycles
pass = pass and: { ~matBaseGrid == ~evSnap };   // base unchanged by steps
~matSetEvolve.(false);                // restore
pass = pass and: { ~lp[\matrix] == ~evSnap };   // working grid back to base
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL`/exception — `~matEvolveStep`/`~matSetEvolve` undefined.

- [ ] **Step 3: Add state + functions.** After `~matApplyBar` (matrix.scd ~322), insert:

```supercollider
// -- generative per-cycle evolution (SP-B) --
~matEvolve     = ~matEvolve     ? false;
~matEvolveRate = ~matEvolveRate ? 0.15;   // fraction of active cells recoloured per cycle
~matBaseGrid   = ~matBaseGrid   ? nil;     // immutable clean snapshot while evolving

// re-derive ~lp[\matrix] from ~matBaseGrid: recolour active cells (0 stays 0),
// mutated colour differs from base and is in 1..6. Bounded (always from base).
~matEvolveStep = {
    ~matBaseGrid.notNil.if({
        ~matVoices.do { |name, vi|
            ~matBars.do { |b|
                var base = ~matBaseGrid[vi][b];
                ((base != 0) and: { 1.0.rand < ~matEvolveRate }).if({
                    ~lp[\matrix][vi][b] = (1..6).reject({ |c| c == base }).choose
                }, {
                    ~lp[\matrix][vi][b] = base
                })
            }
        };
        ~matVoices.size.do { |i| ~matLastColor[i] = -1 };   // force re-source next bar
        ~matGridPush.()
    })
};

// push evolve state to surfaces
~matEvolvePush = {
    ~toscSend !? { ~toscSend.("/matrix/evolve", ~matEvolve.if({ 1 }, { 0 }), ~matEvolveRate) }
};

// enable/disable: snapshot base on enable; restore clean grid on disable
~matSetEvolve = { |on|
    on.asBoolean.if({
        ~matEvolve   = true;
        ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy });
    }, {
        ~matEvolve = false;
        ~matBaseGrid.notNil.if({
            ~lp[\matrix] = ~matBaseGrid.collect({ |row| row.copy });
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
            ~matGridPush.()
        });
        ~matBaseGrid = nil;
    });
    ~matEvolvePush.()
};
```

- [ ] **Step 4: Wire the wrap trigger into `~matPlay`.** In the routine loop (matrix.scd ~373), replace:

```supercollider
            ~matBeatsPerBar.wait;
            ~lp[\matBar] = ~matNextBar.value;
```
with:
```supercollider
            ~matBeatsPerBar.wait;
            ~matPrevBar  = ~lp[\matBar];
            ~lp[\matBar] = ~matNextBar.value;
            // loop wrapped (playhead jumped backward) -> mutate one cycle
            (~matEvolve and: { ~lp[\matBar] < ~matPrevBar }).if({ ~matEvolveStep.() });
```

- [ ] **Step 5: Balance check.** `validating-scd-files` on `matrix.scd` and `test_matrix.scd`. Expected `P:0 B:0` each.

- [ ] **Step 6: Run to verify it PASSES.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`, zero `ERROR`, clean exit.

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat(matrix): generative per-cycle evolve core"
```

---

### Task 2: persistence integration + OSC routes

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` — `~matSetCell`, `~matSave`, `~matLoadFile`, + OSCdefs
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Consumes Task 1's `~matEvolve`/`~matBaseGrid`/`~matSetEvolve`/`~matEvolveRate`.
- Produces: `~matSetCell` dual-writes the base while evolving; `~matSave` serializes the base while evolving; `~matLoadFile` re-snapshots if evolving; OSCdefs `\mat_evolve` (`/matrix/evolve [0/1]`), `\mat_evolverate` (`/matrix/evolverate [0..1]`).

- [ ] **Step 1: Write the failing test.** Add to `test_matrix.scd` after Task 1's block:

```supercollider
// edit during evolve writes through to the base (survives next cycle)
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~lp[\matrix][0][0] = 1;
~matSetEvolve.(true);                 // base = current grid
~matSetCell.(0, 0, 4);                // edit while evolving
pass = pass and: { ~matBaseGrid[0][0] == 4 };       // base updated, not just working grid
// save serializes the base, not the mutated working grid
~matEvolveRate = 1.0; ~matEvolveStep.();              // working grid now mutated
~matSave.("ev_tmp");
~evRaw = File.use(~matDir +/+ "ev_tmp.matrix", "r", { |f| f.readAllString }).interpret;
pass = pass and: { ~evRaw[\grid][0][0] == 4 };       // saved = base value, not the mutated one
File.delete(~matDir +/+ "ev_tmp.matrix");
~matSetEvolve.(false);
// OSCdefs route through to the setters
OSCdef(\mat_evolverate).func.value(['/matrix/evolverate', 0.42]);
pass = pass and: { (~matEvolveRate - 0.42).abs < 0.001 };
OSCdef(\mat_evolve).func.value(['/matrix/evolve', 1]);
pass = pass and: { ~matEvolve == true and: { ~matBaseGrid.notNil } };
OSCdef(\mat_evolve).func.value(['/matrix/evolve', 0]);
pass = pass and: { ~matEvolve == false };
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL` — setCell doesn't touch base; save uses working grid; OSCdefs absent.

- [ ] **Step 3: Dual-write in `~matSetCell`.** In `~matSetCell` (matrix.scd ~391), after `~lp[\matrix][vi][bar] = color.clip(0, 6).asInteger;` add:

```supercollider
        (~matEvolve and: { ~matBaseGrid.notNil }).if({ ~matBaseGrid[vi][bar] = ~lp[\matrix][vi][bar] });
```

- [ ] **Step 4: Save the base.** In `~matSave` find the payload `grid: ~lp[\matrix]` and replace it with:

```supercollider
        grid: (~matEvolve.if({ ~matBaseGrid ? ~lp[\matrix] }, { ~lp[\matrix] })),
```

- [ ] **Step 5: Re-snapshot on load.** In `~matLoadFile`, immediately after the line `~lp[\matrix] = grid;` (matrix.scd ~617), add:

```supercollider
            (~matEvolve).if({ ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
```

- [ ] **Step 6: Add the OSCdefs.** Near the matrix OSCdefs (after `\mat_play` ~868), add:

```supercollider
OSCdef(\mat_evolve, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetEvolve.((msg[1] ? 0).asInteger > 0)
}, '/matrix/evolve');
OSCdef(\mat_evolverate, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matEvolveRate = (msg[1] ? 0.15).asFloat.clip(0, 1);
    ~matEvolvePush.()
}, '/matrix/evolverate');
```

- [ ] **Step 7: Balance check.** `validating-scd-files` on both files. Expected `P:0 B:0`.

- [ ] **Step 8: Run to verify it PASSES.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`, zero `ERROR`, clean exit.

- [ ] **Step 9: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat(matrix): evolve edit/save/load + OSC routes"
```

---

### Task 3: web ÉVOLUE toggle + rate slider

**Files:**
- Modify: `web_realart/public/control/js/matrix-grid.js` (or the matrix transport/timeline area — grep for the matrix play/loop controls) + `web_realart/public/control/css/control.css`
- Modify: `web_realart/public/control/js/osc.js` consumers — add an `on("/matrix/evolve")` handler

**Interfaces:**
- Consumes: `send`, `on` (osc.js). Produces: a toggle that sends `/matrix/evolve [0/1]` and a slider that sends `/matrix/evolverate [0..1]`, both reflecting the echoed `/matrix/evolve [state, rate]`.

- [ ] **Step 1: Locate the matrix transport controls.** `grep -rn "matrix/play\|matrix/loop\|matrix-timeline" web_realart/public/control/js` to find where the matrix play/stop/loop UI is built. Add the evolve controls beside them.

- [ ] **Step 2: Add the toggle + slider.** In that module, add a button `ÉVOLUE` (class `mat-evolve`) and a range input (min 0, max 1, step 0.01) near the matrix transport:

```javascript
const evBtn = document.createElement("button");
evBtn.className = "mat-evolve"; evBtn.textContent = "ÉVOLUE";
evBtn.addEventListener("click", () => {
  const on = !evBtn.classList.contains("on");
  send("/matrix/evolve", on ? 1 : 0);
});
const evRate = document.createElement("input");
evRate.type = "range"; evRate.min = 0; evRate.max = 1; evRate.step = 0.01; evRate.value = 0.15;
evRate.title = "taux d'évolution";
evRate.addEventListener("change", () => send("/matrix/evolverate", +evRate.value));
// append evBtn, evRate to the matrix transport container (match the existing pattern)
```

- [ ] **Step 3: Reflect the echoed state.** Add a handler (in the same module or osc.js consumers):

```javascript
on("/matrix/evolve", (args) => {
  const on = Math.round(Number(args[0])) === 1;
  const rate = Number(args[1]);
  evBtn.classList.toggle("on", on);
  if (Number.isFinite(rate)) evRate.value = rate;
});
```

- [ ] **Step 4: Style the toggle.** Append to `control.css`:

```css
.mat-evolve { padding: 2px 8px; }
.mat-evolve.on { background: #1a8; color: #000; }
```

- [ ] **Step 5: Syntax + regression.**

Run: `cd web_realart && node --check public/control/js/matrix-grid.js && node --test test/*.test.mjs`
Expected: no `--check` output; the full suite stays green (currently 29/29). UI behavior is verified live (macm1) / Playwright — note the deferral.

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js web_realart/public/control/css/control.css
git commit -m "feat(web): matrix evolve toggle and rate"
```

---

## Self-review

**Spec coverage:**
- Base/working grid model + bounded mutation → Task 1 (`~matBaseGrid`, `~matEvolveStep` re-derives from base). ✓
- Recolour active cells only, differ from base, 0 stays 0 → Task 1 Step 3 + test density/differ assertions. ✓
- Enable/disable snapshot/restore → Task 1 `~matSetEvolve`. ✓
- Wrap trigger once per cycle → Task 1 Step 4 (`~lp[\matBar] < ~matPrevBar`). ✓
- Live-edit dual-write + save base + load re-snapshot → Task 2. ✓
- OSC `/matrix/evolve` + `/matrix/evolverate` + echo → Task 2 OSCdefs + `~matEvolvePush`. ✓
- Web toggle/slider → Task 3. ✓
- Default OFF, rate 0.15 env-tunable → Task 1 decls. ✓

**Placeholder scan:** No TBD/TODO. The routine wrap-trigger is integration-tested by the macm1 live smoke (the routine needs the clock); `~matEvolveStep`/`~matSetEvolve`/OSCdefs are directly unit-tested. Web UI behavior deferred to Playwright/live (noted), with node --check + suite-green as the automated gate.

**Type consistency:** `~matEvolveStep` mutates `~lp[\matrix]` (Array of Arrays of Int) from `~matBaseGrid` (same shape, 2-level copy). `~matSetEvolve.(Bool)`. `~matEvolveRate` Float 0..1. OSCdef `\mat_evolve` calls `~matSetEvolve`, `\mat_evolverate` sets `~matEvolveRate` — matching Task 1's names. `/matrix/evolve` echo is `[stateInt(0/1), rate]` (Task 1 `~matEvolvePush`) consumed by Task 3's handler (`args[0]` state, `args[1]` rate). `~matSetCell` dual-write guarded by `~matEvolve and ~matBaseGrid.notNil`. Save uses `~matBaseGrid ? ~lp[\matrix]` fallback.
