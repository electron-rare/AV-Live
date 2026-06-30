# Matrix global morceau actions — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open/close either hand fires a momentary global action on the whole matrix (fill / drop / breakdown / relance+evolve), with a per-morceau gesture→action mapping editable in a new bottom panel of the matrix editor and saved in each `.matrix`.

**Architecture:** Detect hand open/closed SC-side from the `lOpen`/`rOpen` openness already in `/pose/hands` (hysteresis + presence via `x>0`). A single `~matTransient` override (kind + kept voices + bar countdown), consulted by the per-bar voice sourcing (`~matApplyBar` via `~matEffColor`), expresses all momentary effects; `relance+evolve` is a one-shot. The 4-slot mapping `~matGlobalActions` is stored, OSC-synced (`/matrix/globalaction`), saved/loaded per `.matrix`, generated as a default by `generate_presets.py`, and edited via 4 dropdowns in a new `morceau-panel.js`.

**Tech Stack:** SuperCollider (sclang), Python 3 (`uv run python`), vanilla ES modules + `node --test` for the web control surface.

## Global Constraints

- SC env vars `~xxx` lowercase. `matrix.scd` is a single top-level block `( ... )` — keep parens balanced (`awk` P:0 B:0), no second top-level block.
- Python: uv only. No emojis in code/docs/commits. Commit subject ≤ 50 chars, body ≤ 72/line, no AI attribution, no `--no-verify`, no underscore in commit scope.
- Slot order is fixed everywhere: `0 = LH open, 1 = LH closed, 2 = RH open, 3 = RH closed`.
- Default mapping everywhere: `[fill, drop, evolve, breakdown]` (LH open=fill, LH closed=drop, RH open=evolve, RH closed=breakdown).
- Phase-1 constants (Phase 2 turns these into editable settings): `~matOpenThresh = 0.65`, `~matCloseThresh = 0.30`, `~matTransientBars = 1`, `~matBreakdownKeep = [\kick, \sub]`.
- `~matTransient` recolours/cuts ACTIVE-cell sourcing only via `~matEffColor`; it never edits `~lp[\matrix]` (the grid stays intact; the override is applied at source time).
- No `data_only_viz` changes. The matrix is live on macm1 — push/deploy only on user request.
- `/pose/hands` payload: `[addr, 0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]` so in the OSCdef `msg`: `lx=msg[2]`, `lopen=msg[4]`, `rx=msg[6]`, `ropen=msg[8]`. Absent hand slot = `[0,0,0,0]` → `x==0.0`; present hand → `x>0`.

## File Structure

- `sound_algo/data_only/matrix.scd` — engine: `~matTransient` primitive, `~matEffColor`, `~matApplyBar` integration, `~matSetTransient`, `~matTransientTick` (in `~matPlay` routine), `~matRelanceEvolve`, `~matFireGlobal`, `~matGlobalActions` + defaults, gesture detection `~matHandFlip` in the `/pose/hands` OSCdef, OSC routes `/matrix/globalaction[/get]`, save/load integration.
- `sound_algo/data_only/matrix_presets/generate_presets.py` — `to_sc` emits the default `globalActions` field.
- `sound_algo/data_only/matrix_presets/test_global_actions.py` (new) — Python: every generated `.matrix` carries the default `globalActions`.
- `sound_algo/data_only/matrix_presets/test_global_actions.scd` (new) — SC: transient apply/expire, breakdown keep set, fire dispatch, hand-flip detection, mapping save/load roundtrip.
- `web_realart/public/control/js/matrix-state.js` — `GLOBAL_ACTION_CHOICES`, `GLOBAL_SLOTS`, `matGlobalActions`, `setGlobalAction`, `resetGlobalActions`, persistence (`gact`).
- `web_realart/public/control/js/morceau-panel.js` (new) — render 4 dropdowns + OSC sync.
- `web_realart/public/control/index.html` — `#morceau-panel` container in `#tab-matrix`.
- `web_realart/public/control/control.css` — panel styles.
- `web_realart/public/control/js/main.js` — import + `initMorceauPanel()`.
- `web_realart/test/matrix-state.test.mjs` — extend with global-action coverage.

---

### Task 1: Engine — transient primitive + core actions

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matApplyBar` ~line 297-323; insert a new block after `~matSetEvolve` ~line 369; `~matPlay` routine ~line 430-440).
- Create: `sound_algo/data_only/matrix_presets/test_global_actions.scd`

**Interfaces:**
- Consumes (existing): `~matVoices` (Array of voice-name strings), `~lp[\matrix]` (22×64 Int grid), `~matLastColor` (Array, applied colour per voice), `~matApplyBar.(bar)`, `~matEvolveStep.()`, `~matBaseGrid`, `~lp[\matPlaying]`, `~matBars`.
- Produces (for Task 2 + later phases): `~matTransient` (Event `(kind:Symbol, voices:[Symbol], bars:Int)` or `nil`), `~matEffColor.(name, vi, base) -> Int`, `~matSetTransient.(kind, voices)`, `~matTransientTick.()`, `~matRelanceEvolve.()`, `~matFireGlobal.(slot)`, `~matGlobalActions` (Array[4] of Symbol, default `[\fill, \drop, \evolve, \breakdown]`), `~matBreakdownKeep` (`[\kick, \sub]`), `~matTransientBars` (1).

- [ ] **Step 1: Write the failing SC harness** `sound_algo/data_only/matrix_presets/test_global_actions.scd`

```supercollider
// Headless checks for global morceau actions (Phase 1).
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd
(
var feat = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass = true;
~lp = (clock: TempoClock.default); ~toscSend = { |path ...a| }; ~toscTouch = { |a| };
["kick","hats","clap","perc","sub","acid","arp","lead","stab","pad","ride","rim",
 "tom","reese","bells","sweep","melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1)) };
feat.load;
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 1) });  // all active
~lp[\matPlaying] = false;

// -- A: defaults --
(~matGlobalActions == [\fill, \drop, \evolve, \breakdown]).not.if({ pass = false; "FAIL: default mapping".postln });

// -- B: fill -> active voices read colour 6, silent voices stay 0 --
~matSetTransient.(\fill, []);
(~matEffColor.(\kick, 0, 1) == 6).not.if({ pass = false; "FAIL: fill active->6".postln });
(~matEffColor.(\kick, 0, 0) == 0).not.if({ pass = false; "FAIL: fill silent stays 0".postln });

// -- C: drop -> everything 0 --
~matSetTransient.(\drop, []);
(~matEffColor.(\kick, 0, 4) == 0).not.if({ pass = false; "FAIL: drop->0".postln });

// -- D: breakdown -> only kept voices survive --
~matSetTransient.(\breakdown, ~matBreakdownKeep);
(~matEffColor.(\kick, 0, 3) == 3).not.if({ pass = false; "FAIL: breakdown keeps kick".postln });
(~matEffColor.(\hats, 1, 3) == 0).not.if({ pass = false; "FAIL: breakdown cuts hats".postln });

// -- E: transient expires after ~matTransientBars ticks --
~matSetTransient.(\drop, []);
~matTransientBars.do { ~matTransientTick.() };
(~matTransient.isNil).not.if({ pass = false; "FAIL: transient not cleared after ticks".postln });
(~matEffColor.(\kick, 0, 2) == 2).not.if({ pass = false; "FAIL: post-expire normal colour".postln });

// -- F: ~matFireGlobal dispatches the mapped action --
~matGlobalActions = [\fill, \drop, \evolve, \breakdown];
~matFireGlobal.(1);   // slot 1 = drop
(~matTransient.notNil and: { ~matTransient[\kind] == \drop }).not.if({ pass = false; "FAIL: fire slot1->drop".postln });
~matTransient = nil;
~matFireGlobal.(0);   // slot 0 = fill
(~matTransient.notNil and: { ~matTransient[\kind] == \fill }).not.if({ pass = false; "FAIL: fire slot0->fill".postln });

pass.if({ "GLOBALACT PASS".postln }, { "GLOBALACT FAIL".postln });
0.exit;
)
```

- [ ] **Step 2: Run it — expect FAIL** (functions undefined → errors / FAIL).

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: errors (e.g. `~matSetTransient` is nil / doesNotUnderstand) or `GLOBALACT FAIL`.

- [ ] **Step 3: Add the global-actions engine block** to `sound_algo/data_only/matrix.scd`, immediately after `~matSetEvolve` (the block ending ~line 369, before the next comment). Paste verbatim:

```supercollider

// -- global morceau actions: momentary transient overrides + gesture mapping --
~matTransient     = ~matTransient     ? nil;          // (kind:, voices:[Symbol], bars:Int) or nil
~matTransientBars = ~matTransientBars ? 1;            // Phase 1: 1 bar (Phase 2 reads settings)
~matBreakdownKeep = ~matBreakdownKeep ? [\kick, \sub];
~matGlobalActions = ~matGlobalActions ? [\fill, \drop, \evolve, \breakdown];  // slots 0..3
~matOpenThresh    = ~matOpenThresh    ? 0.65;
~matCloseThresh   = ~matCloseThresh   ? 0.30;
~matHandState     = ~matHandState     ? IdentityDictionary[\L -> \unknown, \R -> \unknown];

// effective colour for a voice this bar, given any active transient (grid untouched)
~matEffColor = { |name, vi, base|
    var t = ~matTransient;
    t.isNil.if({ base }, {
        var k = t[\kind];
        (k == \drop).if({ 0 },
        { (k == \fill).if({ (base == 0).if({ 0 }, { 6 }) },
        { (k == \breakdown).if({ ((t[\voices] ? []).includes(name)).if({ base }, { 0 }) },
        { base }) }) })
    })
};

// set a transient + re-source now (effect lands at the next bar via Pdef quant)
~matSetTransient = { |kind, voices|
    ~matTransient = (kind: kind, voices: (voices ? []), bars: ~matTransientBars);
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    (~lp[\matPlaying] == true).if({ ~matApplyBar.(~lp[\matBar] ? 0) });
};

// count one bar of transient use; clear + force re-source when exhausted (routine-only)
~matTransientTick = {
    ~matTransient.notNil.if({
        ~matTransient[\bars] = ~matTransient[\bars] - 1;
        (~matTransient[\bars] <= 0).if({
            ~matTransient = nil;
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
        });
    });
};

// one mutation from a base snapshot + re-source (the evolve one-shot)
~matRelanceEvolve = {
    ~matBaseGrid.isNil.if({ ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
    ~matEvolveStep.();
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    (~lp[\matPlaying] == true).if({ ~matApplyBar.(~lp[\matBar] ? 0) });
};

// dispatch the action mapped to a gesture slot (0=LHopen,1=LHclosed,2=RHopen,3=RHclosed)
~matFireGlobal = { |slot|
    var act = (~matGlobalActions[slot]) ? \none;
    (act == \fill).if({ ~matSetTransient.(\fill, []) });
    (act == \drop).if({ ~matSetTransient.(\drop, []) });
    (act == \breakdown).if({ ~matSetTransient.(\breakdown, ~matBreakdownKeep) });
    (act == \evolve).if({ ~matRelanceEvolve.() });
};
```

- [ ] **Step 4: Make `~matApplyBar` transient-aware.** In `~matApplyBar` (~line 299), replace the colour line:

Replace:
```supercollider
        var color = ~lp[\matrix][vi][bar];
```
with:
```supercollider
        var color = ~matEffColor.(name, vi, ~lp[\matrix][vi][bar]);
```

- [ ] **Step 5: Tick the transient once per bar in the `~matPlay` routine.** In the routine loop (~line 432), insert the tick right after `~matApplyBar.(~lp[\matBar]);`:

Replace:
```supercollider
            ~matApplyBar.(~lp[\matBar]);
            ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
```
with:
```supercollider
            ~matApplyBar.(~lp[\matBar]);
            ~matTransientTick.();
            ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
```

- [ ] **Step 6: Verify paren balance.**

Run: `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
Expected: `P:0 B:0`

- [ ] **Step 7: Run the SC harness — expect PASS.**

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: `GLOBALACT PASS`

- [ ] **Step 8: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): transient primitive + core global actions"
```

---

### Task 2: Engine — hand-flip detection + OSC + save/load

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`/pose/hands` OSCdef ~line 1078-1087; add `~matHandFlip` + push + OSCdefs near the global-actions block; `~matSave` ~line 660-666; `~matLoadFile` ~line 683-767).
- Modify: `sound_algo/data_only/matrix_presets/test_global_actions.scd` (append flip + roundtrip checks).

**Interfaces:**
- Consumes: Task 1's `~matFireGlobal`, `~matGlobalActions`, `~matOpenThresh`, `~matCloseThresh`, `~matHandState`; existing `~matSave`/`~matLoadFile`/`~matDir`/`~matGridValid`/`~toscSend`.
- Produces: `~matHandFlip.(hand, x, openness, openSlot, closeSlot)`, `~matGlobalActionsPush.()`, OSC routes `/matrix/globalaction` (set+echo) and `/matrix/globalaction/get`, and `globalActions` persisted in the `.matrix` payload.

- [ ] **Step 1: Append failing checks** to `sound_algo/data_only/matrix_presets/test_global_actions.scd`, immediately before the `pass.if(...)` final line:

```supercollider
// -- G: hand-flip detection (no fire on appear/disappear; fire on open<->closed) --
~fired = nil; ~matFireGlobal = { |slot| ~fired = slot };   // stub to capture the slot
~matHandState[\L] = \unknown;
~matHandFlip.(\L, 0.5, 0.9, 0, 1);                          // appear OPEN -> baseline, no fire
(~fired.isNil).not.if({ pass = false; "FAIL: fired on appearance".postln });
~matHandFlip.(\L, 0.5, 0.1, 0, 1);                          // OPEN->CLOSED -> fire closeSlot(1)
(~fired == 1).not.if({ pass = false; "FAIL: open->closed did not fire slot1".postln });
~fired = nil;
~matHandFlip.(\L, 0.5, 0.9, 0, 1);                          // CLOSED->OPEN -> fire openSlot(0)
(~fired == 0).not.if({ pass = false; "FAIL: closed->open did not fire slot0".postln });
~fired = nil;
~matHandFlip.(\L, 0.0, 0.0, 0, 1);                          // disappear -> reset, no fire
(~fired.isNil).not.if({ pass = false; "FAIL: fired on disappearance".postln });

// -- H: mapping save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalActions = [\evolve, \breakdown, \fill, \drop];     // non-default
~matSave.("zz_gact_test");
~matGlobalActions = [\fill, \drop, \evolve, \breakdown];     // clobber, then reload
~matLoadFile.(~matDir +/+ "zz_gact_test.matrix");
(~matGlobalActions == [\evolve, \breakdown, \fill, \drop]).not.if({ pass = false; "FAIL: globalActions not round-tripped".postln });
("rm -f '" ++ (~matDir +/+ "zz_gact_test.matrix") ++ "'").systemCmd;
```

- [ ] **Step 2: Run — expect FAIL** (`~matHandFlip` undefined; `globalActions` not saved).

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: error on `~matHandFlip` or `GLOBALACT FAIL`.

- [ ] **Step 3: Add `~matHandFlip` + push + OSCdefs.** Append to the global-actions block created in Task 1 (right after `~matFireGlobal`):

```supercollider

// derive open/closed per hand from openness (hysteresis); fire only on an
// established open<->closed flip. Absent hand (x<=0) resets state (no fire).
~matHandFlip = { |hand, x, openness, openSlot, closeSlot|
    var present = x > 0.001;
    var prev = (~matHandState[hand]) ? \unknown;
    var cur = present.if({
        (openness >= ~matOpenThresh).if({ \open },
        { (openness <= ~matCloseThresh).if({ \closed }, { prev }) })
    }, { \unknown });
    ((prev == \open) and: { cur == \closed }).if({ ~matFireGlobal.(closeSlot) });
    ((prev == \closed) and: { cur == \open }).if({ ~matFireGlobal.(openSlot) });
    ~matHandState[hand] = cur;
};

// push the 4-slot mapping to surfaces (symbols sent as strings)
~matGlobalActionsPush = {
    4.do { |i| ~toscSend !? { ~toscSend.("/matrix/globalaction", i, (~matGlobalActions[i] ? \none).asString) } }
};
```

- [ ] **Step 4: Register the OSC routes.** Add near the other matrix OSCdefs (e.g. just after the `\mat_evolverate` OSCdef ~line 948):

```supercollider
OSCdef(\mat_globalaction, { |msg, time, addr|
    var slot = (msg[1] ? 0).asInteger;
    var sym  = (msg[2] ? \none).asSymbol;
    ~toscTouch !? { ~toscTouch.(addr) };
    (slot >= 0 and: { slot < 4 }).if({
        ~matGlobalActions[slot] = sym;
        ~toscSend !? { ~toscSend.("/matrix/globalaction", slot, sym.asString) };
    })
}, '/matrix/globalaction');
OSCdef(\mat_globalaction_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalActionsPush.()
}, '/matrix/globalaction/get');
```

- [ ] **Step 5: Call detection from `/pose/hands`.** In the `\mat_mod_hands` OSCdef (~line 1078-1087), add two calls just before its closing `}, '/pose/hands');`:

```supercollider
    ~matHandFlip.(\L, msg[2] ? 0, msg[4] ? 0, 0, 1);
    ~matHandFlip.(\R, msg[6] ? 0, msg[8] ? 0, 2, 3);
```

- [ ] **Step 6: Persist in `~matSave`.** In the `payload` Event (~line 660-666), add a `globalActions` entry. Replace:
```supercollider
        voicePoses: ~matVoices.collect({ |name| ~matVoicePoses[name] ? [] })
    );
```
with:
```supercollider
        voicePoses: ~matVoices.collect({ |name| ~matVoicePoses[name] ? [] }),
        globalActions: ~matGlobalActions
    );
```

- [ ] **Step 7: Restore in `~matLoadFile`.** Just before `~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) });` (~line 761), add:

```supercollider
            // restore global morceau actions (default when absent/legacy)
            ~matGlobalActions = [\fill, \drop, \evolve, \breakdown];
            ((raw.isArray.not) and: { raw[\globalActions].notNil and: { raw[\globalActions].isArray } }).if({
                raw[\globalActions].do { |s, i| (i < 4 and: { s.notNil }).if({ ~matGlobalActions[i] = s.asSymbol }) }
            });
```
Then, just after `~matEvolvePush.();` (~line 767), add:
```supercollider
            ~matGlobalActionsPush.();
```

- [ ] **Step 8: Verify paren balance.**

Run: `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
Expected: `P:0 B:0`

- [ ] **Step 9: Run the SC harness — expect PASS.**

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: `GLOBALACT PASS`

- [ ] **Step 10: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/matrix_presets/test_global_actions.scd
git commit -m "feat(matrix): hand-flip detection, OSC, save/load mapping"
```

---

### Task 3: Generator — emit default `globalActions` in every preset

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/generate_presets.py` (`to_sc` ~line 1147-1150).
- Create: `sound_algo/data_only/matrix_presets/test_global_actions.py`
- Regenerate: `sound_algo/data_only/matrix_presets/*.matrix`

**Interfaces:**
- Consumes: existing `to_sc(name, arc_fn, instkit, melodies, extra, post=None)`, `MORCEAUX`, `main()`.
- Produces: each `.matrix` file contains the literal `'globalActions': [ \fill, \drop, \evolve, \breakdown ]` matching the SC default + load defaults from Task 2.

- [ ] **Step 1: Write the failing Python test** `sound_algo/data_only/matrix_presets/test_global_actions.py`

```python
"""Every generated .matrix must carry the default globalActions mapping
(slots: LH open=fill, LH closed=drop, RH open=evolve, RH closed=breakdown).
Run: cd .../matrix_presets && uv run python test_global_actions.py"""
import sys, os, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_presets as G

EXPECT = r"'globalActions': [ \fill, \drop, \evolve, \breakdown ]"
ok = True

def check(c, m):
    global ok
    if not c: ok = False; print("FAIL:", m)

# to_sc emits the field
sample = G.to_sc("techno_drive_live", G.MORCEAUX["techno_drive"]["live"],
                 G.MORCEAUX["techno_drive"]["instkit"],
                 G.MORCEAUX["techno_drive"]["melodies"],
                 G.MORCEAUX["techno_drive"]["extra"])
check(EXPECT in sample, "to_sc output missing globalActions default")

# every emitted .matrix on disk carries it (run generate first)
here = os.path.dirname(os.path.abspath(__file__))
files = glob.glob(os.path.join(here, "*.matrix"))
check(len(files) >= 84, "expected >=84 .matrix files, got %d" % len(files))
missing = [os.path.basename(f) for f in files
           if EXPECT not in open(f, encoding="utf-8").read()]
check(not missing, "globalActions missing in: %s" % missing[:5])

print("GLOBALACT-PY PASS" if ok else "GLOBALACT-PY FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Run it — expect FAIL** (`to_sc` does not emit the field yet; on-disk files lack it).

Run: `cd sound_algo/data_only/matrix_presets && uv run python test_global_actions.py`
Expected: `FAIL: to_sc output missing globalActions default` then `GLOBALACT-PY FAIL`.

- [ ] **Step 3: Emit the field in `to_sc`.** In `generate_presets.py`, change the return (~line 1147-1150). Replace:
```python
    return ("(\n'grid': [\n%s\n],\n'instruments': [ %s ],\n"
            "'colorDefs': [\n%s\n],\n"
            "'voiceMods': [ %s ],\n"
            "'voicePoses': [ %s ]\n)\n" % (rows, isyms, cds, vms, vps))
```
with:
```python
    return ("(\n'grid': [\n%s\n],\n'instruments': [ %s ],\n"
            "'colorDefs': [\n%s\n],\n"
            "'voiceMods': [ %s ],\n"
            "'voicePoses': [ %s ],\n"
            "'globalActions': [ \\fill, \\drop, \\evolve, \\breakdown ]\n)\n"
            % (rows, isyms, cds, vms, vps))
```

- [ ] **Step 4: Regenerate the presets (twice — must be deterministic).**

Run: `cd sound_algo/data_only/matrix_presets && uv run python generate_presets.py && uv run python generate_presets.py && git status --porcelain '*.matrix' | wc -l`
Expected: 84 files written each run; the second run leaves the working tree unchanged for already-tracked files (only the new field differs from HEAD, consistently).

- [ ] **Step 5: Run the Python test — expect PASS.**

Run: `uv run python test_global_actions.py`
Expected: `GLOBALACT-PY PASS`

- [ ] **Step 6: Regression — section + family tests still green.**

Run: `uv run python test_sections.py && uv run python test_families.py`
Expected: `TEST PASS` then `TEST PASS`.

- [ ] **Step 7: Verify a generated preset loads in SC (defaults intact).**

Run: `cd sound_algo/data_only/matrix_presets && /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd`
Expected: `GLOBALACT PASS` (unchanged — the engine reads the same default; this confirms nothing regressed).

- [ ] **Step 8: Commit.**

```bash
git add sound_algo/data_only/matrix_presets/generate_presets.py sound_algo/data_only/matrix_presets/test_global_actions.py sound_algo/data_only/matrix_presets/*.matrix
git commit -m "feat(presets): emit default global actions mapping"
```

---

### Task 4: Web state — choices, mapping, persistence

**Files:**
- Modify: `web_realart/public/control/js/matrix-state.js`
- Modify: `web_realart/test/matrix-state.test.mjs`

**Interfaces:**
- Consumes: existing `MATRIX_STORAGE_KEY`, `saveMatState`/`loadMatState` (extend the persisted blob with a `gact` field).
- Produces: `GLOBAL_ACTION_CHOICES` (Array of `{id,label}`), `GLOBAL_SLOTS` (Array[4] of `{key,label}`), `matGlobalActions` (Array[4] of String), `setGlobalAction(slot, id)`, `resetGlobalActions()`.

- [ ] **Step 1: Write the failing test.** Append to `web_realart/test/matrix-state.test.mjs`:

```javascript
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
```

- [ ] **Step 2: Run it — expect FAIL** (named exports undefined).

Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: import/assertion failures (`GLOBAL_ACTION_CHOICES` undefined).

- [ ] **Step 3: Add the state + choices.** In `matrix-state.js`, after `POSE_EVENT_CHOICES` (~line 62), add:

```javascript
// Global morceau actions: fixed 4 gesture slots, editable mapping (Phase 1).
export const GLOBAL_ACTION_CHOICES = [
  { id: "none", label: "—" }, { id: "fill", label: "Fill" },
  { id: "drop", label: "Drop" }, { id: "breakdown", label: "Breakdown" },
  { id: "evolve", label: "Relance + evolve" },
];
export const GLOBAL_SLOTS = [
  { key: 0, label: "Main G ouverte" }, { key: 1, label: "Main G fermée" },
  { key: 2, label: "Main D ouverte" }, { key: 3, label: "Main D fermée" },
];
export let matGlobalActions = ["fill", "drop", "evolve", "breakdown"];
export function setGlobalAction(slot, id) {
  if (slot >= 0 && slot < 4) matGlobalActions[slot] = id;
}
export function resetGlobalActions() {
  matGlobalActions = ["fill", "drop", "evolve", "breakdown"];
}
```

- [ ] **Step 4: Persist `gact`.** In `saveMatState` (~line 153-157), add `gact: matGlobalActions` to the JSON blob. Replace:
```javascript
    JSON.stringify({ grid: matGrid, inst: matInst, cdef: matColorDefs,
                     vmod: matVoiceMods, vpose: matVoicePoses })); } catch (_e) {}
```
with:
```javascript
    JSON.stringify({ grid: matGrid, inst: matInst, cdef: matColorDefs,
                     vmod: matVoiceMods, vpose: matVoicePoses,
                     gact: matGlobalActions })); } catch (_e) {}
```
In `loadMatState`, just before the `return; }` that closes the new-format branch (~line 182), add:
```javascript
      if (Array.isArray(raw.gact) && raw.gact.length === 4) matGlobalActions = raw.gact;
```

- [ ] **Step 5: Run the test — expect PASS.**

Run: `cd web_realart && node --test test/matrix-state.test.mjs`
Expected: all tests pass (0 failures).

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(control): global action state + persistence"
```

---

### Task 5: Web UI — the "Morceau" bottom panel

**Files:**
- Create: `web_realart/public/control/js/morceau-panel.js`
- Modify: `web_realart/public/control/index.html` (`#tab-matrix`, before `</section>` ~line 181)
- Modify: `web_realart/public/control/control.css`
- Modify: `web_realart/public/control/js/main.js` (import + init call)

**Interfaces:**
- Consumes: `send`, `on`, `onOpen` from `./osc.js`; `GLOBAL_ACTION_CHOICES`, `GLOBAL_SLOTS`, `matGlobalActions`, `setGlobalAction`, `saveMatState` from `./matrix-state.js`.
- Produces: `export function init()` — renders 4 dropdowns into `#morceau-slots`, sends `/matrix/globalaction slot id` on change, syncs from `on("/matrix/globalaction")`, requests state on connect.

- [ ] **Step 1: Create the panel module** `web_realart/public/control/js/morceau-panel.js`

```javascript
// morceau-panel.js — bottom-of-editor panel for matrix-wide ("morceau") actions.
// Phase 1: the 4 hand-gesture slots -> global action. DOM-only; state in
// matrix-state.js, transport over osc.js. Later phases add settings + global controls.
import { send, on, onOpen } from "./osc.js";
import {
  GLOBAL_ACTION_CHOICES, GLOBAL_SLOTS, matGlobalActions,
  setGlobalAction, saveMatState,
} from "./matrix-state.js";

export function init() {
  const host = document.getElementById("morceau-slots");
  if (!host) return;
  const selects = [];
  GLOBAL_SLOTS.forEach((slot) => {
    const wrap = document.createElement("label");
    wrap.className = "morceau-slot";
    wrap.append(slot.label + " ");
    const sel = document.createElement("select");
    GLOBAL_ACTION_CHOICES.forEach((c) => {
      const o = document.createElement("option");
      o.value = c.id; o.textContent = c.label;
      sel.appendChild(o);
    });
    sel.value = matGlobalActions[slot.key] || "none";
    sel.addEventListener("change", () => {
      setGlobalAction(slot.key, sel.value);
      send("/matrix/globalaction", slot.key, sel.value);
      saveMatState();
    });
    selects[slot.key] = sel;
    wrap.appendChild(sel);
    host.appendChild(wrap);
  });
  on("/matrix/globalaction", (args) => {
    const slot = Math.round(Number(args[0]));
    const id = String(args[1] || "none");
    if (slot >= 0 && slot < 4 && selects[slot]) {
      selects[slot].value = id;
      setGlobalAction(slot, id);
      saveMatState();
    }
  });
  onOpen(() => send("/matrix/globalaction/get"));
  send("/matrix/globalaction/get");
}
```

- [ ] **Step 2: Add the container to `index.html`.** Inside `#tab-matrix`, just before its closing `</section>` (after `<div id="matrix-mixer" ...></div>`, ~line 180):

```html
  <div id="morceau-panel" class="morceau-panel">
    <div class="morceau-title">Actions globales (morceau)</div>
    <div id="morceau-slots" class="morceau-slots"></div>
  </div>
```

- [ ] **Step 3: Style the panel.** Append to `web_realart/public/control/control.css`:

```css
.morceau-panel { margin-top: 12px; padding: 8px; border-top: 1px solid #333;
  background: #161616; border-radius: 6px; }
.morceau-title { font-size: 12px; text-transform: uppercase; letter-spacing: .05em;
  color: #888; margin-bottom: 6px; }
.morceau-slots { display: grid; grid-template-columns: repeat(2, 1fr);
  gap: 6px 12px; }
.morceau-slot { display: flex; align-items: center; justify-content: space-between;
  gap: 6px; font-size: 13px; color: #ccc; }
.morceau-slot select { flex: 0 0 auto; background: #222; color: #eee;
  border: 1px solid #444; border-radius: 4px; padding: 2px 4px; }
```

- [ ] **Step 4: Wire it into `main.js`.** Add the import after the `voice-editor` import (~line 12):
```javascript
import { init as initMorceauPanel } from "./morceau-panel.js";
```
And add the init call after `initGrid();` (~line 59):
```javascript
  initMorceauPanel();
```

- [ ] **Step 5: Smoke the bundle (no syntax errors, panel renders).** Start the bridge and load the control page in a headless check.

Run: `cd web_realart && node --check public/control/js/morceau-panel.js && node --check public/control/js/main.js`
Expected: no output (both files parse). (Full DOM render is verified live in Task 6.)

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js/morceau-panel.js web_realart/public/control/index.html web_realart/public/control/control.css web_realart/public/control/js/main.js
git commit -m "feat(control): morceau panel with gesture-action slots"
```

---

### Task 6: Deploy + live smoke (macm1)

**Files:** none (deploy + manual verification).

- [ ] **Step 1: Push + pull on macm1 + regen.**

```bash
git push gitea-https main
ssh macm1 'cd ~/AV-Live/sound_algo/data_only/matrix_presets && git pull && uv run python generate_presets.py'
```
(Use the actual macm1 AV-Live path. Push only after user confirms — the rig is live.)

- [ ] **Step 2: Reload the engine + a live preset, open the control surface.**
Reboot the matrix SC engine on macm1 (launch_concert.sh path), `/matrix/load techno_drive_live`, `/matrix/play`. Open `http://supra-m1.local:4400/control/`, MATRICE tab → confirm the "Actions globales (morceau)" panel shows 4 dropdowns defaulting to Fill / Drop / Relance+evolve / Breakdown.

- [ ] **Step 3: Verify gestures (both hands visible).**
Open left hand → momentary fill (1 bar, all voices busier) then back. Close left hand → 1-bar drop then back. Open right hand → re-source + one evolve mutation. Close right hand → 1-bar breakdown to kick+sub then back. Confirm no false fires when hands leave frame.

- [ ] **Step 4: Verify the editor + persistence.**
In the panel, re-map a slot (e.g. MG ouverte → Breakdown); confirm the new mapping fires. `SAUVER` the matrix, reload it → the mapping persists. Load an old preset → defaults apply (fill/drop/evolve/breakdown).

- [ ] **Step 5: Report to the user (their ear).** Summarise what landed and ask them to confirm by hand before Phase 2.

---

## Self-review

**Spec coverage (Phase 1 scope):**
- Detection §1 (hysteresis + presence via `x>0`, flip-only, reset on disappear) → Task 2 Step 3/5 + harness G.
- `~matTransient` primitive §2 (apply/expire, per-bar sourcing) → Task 1 Steps 3-5 + harness B-E.
- 4 core actions (fill/drop/breakdown/evolve) → Task 1 Step 3 (`~matFireGlobal`) + harness F.
- Mapping storage + OSC get/set + echo §5 → Task 2 Steps 3-4.
- Save/load per `.matrix` §5 → Task 2 Steps 6-7 + harness H.
- Generator default §5 → Task 3.
- Bottom panel with 4 slots §6 → Tasks 4-5.
- Defaults `[fill,drop,evolve,breakdown]` + thresholds 0.65/0.30 + transient 1 bar + breakdownKeep kick+sub → Global Constraints, used identically in Task 1 (SC), Task 3 (generator), Task 4 (web). ✓
- Phase-2/3 items (extended vocabulary, settings UI, global-control consolidation, `/matrix/bpm`) are explicitly OUT of this plan.

**Placeholder scan:** every code step has complete code; no TBD/TODO; thresholds and slot order are concrete.

**Type consistency:** slot order `0=LHopen,1=LHclosed,2=RHopen,3=RHclosed` identical across `~matHandFlip` calls (Task 2 Step 5), `~matFireGlobal`/`~matGlobalActions` (Task 1), `GLOBAL_SLOTS` (Task 4), panel (Task 5). Action symbols `fill/drop/breakdown/evolve/none` match between SC (`~matEffColor`/`~matFireGlobal`), generator literal, and web `GLOBAL_ACTION_CHOICES`. `globalActions` field name identical in `~matSave`, `~matLoadFile`, generator literal, and the Python test's `EXPECT`. `~matEffColor.(name, vi, base)` signature matches its calls in `~matApplyBar` and the harness. Persisted web key `gact` matches between `saveMatState` and `loadMatState`.
