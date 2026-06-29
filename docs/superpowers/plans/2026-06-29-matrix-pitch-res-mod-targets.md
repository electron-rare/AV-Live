# Matrix pitch + res modulation targets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `res` and `pitch` as per-voice modulation targets in the matrix sequencer so pose sources can drive resonance (res-voices) and in-key transpose (melodic step voices).

**Architecture:** `res` becomes an independent additive Pbind key in `~matModPairs` (like cutoff/rev). `pitch` is special — frequency is computed by a custom `\freq` Pfunc from scale degrees, so a pitch binding adds a bipolar integer scale-degree offset (`~matPitchOffset`) inside that Pfunc; it is excluded from `~matModPairs`. Target eligibility is enforced by the existing `~matModTargets` gating in `~matSetVoiceMod`. Web mirrors the new per-voice targets + labels.

**Tech Stack:** SuperCollider (sclang, no server for tests), vanilla ES modules + `node --test` (`web_realart`).

## Global Constraints

- No emojis in code/docs/commits.
- Commits: subject ≤ 50 chars, body ≤ 72 chars/line, no AI attribution, no `--no-verify`, no underscore in commit scope.
- `.scd` files MUST stay balanced P:0 B:0 — run the `validating-scd-files` skill after every `.scd` edit.
- Modulation source/target IDs are SYMBOLS on the wire and in presets — never renamed; FR labels are web display-only.
- SC tests live in `sound_algo/data_only/test/test_matrix.scd` (NO server booted; stubs `~toscSend`/`~toscTouch`; dummy `Pdef(\lp_*)`; `~lp=(clock:TempoClock.default)`; loads `../matrix.scd`; `pass = pass and: {...}` + `try{}`; ends `0.exit`; final `TEST PASS`). Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd` (binary not on PATH; there is no `timeout`/`gtimeout` — the script self-terminates). Test OSCdef/data logic by calling functions directly.
- Web tests: `cd web_realart && node --test test/*.test.mjs` — the GLOB form is required (a bare `node --test test/` mis-parses "test" as a single failing test). Currently 26/26.
- Push only on user request (Gitea `gitea-https` remote = `https://electron@git.saillant.cc/electron-rare/AV-Live.git`). macm1 is the live engine host.

## Eligibility (single source of truth)

- **Pitch-capable** (10, the freq-Pfunc step voices): `sub, acid, arp, lead, stab, pad, reese, bells, perc, tom`.
- **Res-capable** (10 = `~matResVoices`): `sub, acid, arp, lead, stab, pad, reese, bells, melody, chord`.
- Overlap (both): `sub, acid, arp, lead, stab, pad, reese, bells`. Pitch-only: `perc, tom`. Res-only: `melody, chord`.

## File structure

| File | Change |
|------|--------|
| `sound_algo/data_only/matrix.scd` | `~matModPairs` (+res branch, exclude pitch), `~matModTargets` (+res/+pitch), `~matPitchOffset`/`~matPitchRange`, freq Pfunc patch |
| `sound_algo/data_only/test/test_matrix.scd` | res additive, pitch offset, freq integration, gating assertions |
| `web_realart/public/control/js/matrix-state.js` | `MATRIX_MOD_TARGETS` (+res/+pitch per voice), `MOD_TARGET_LABELS` (+pitch/+res) |
| `web_realart/test/matrix-state.test.mjs` | target/label coverage assertions |

---

### Task 1: `res` modulation target

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` — `~matModPairs` (currently ~156-193), `~matModTargets` (currently ~28-39)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Consumes: `~matVoiceMods`, `~matModSourceVal`, `~matResVoices`.
- Produces: `~matModPairs` now emits a `[\res, Pfunc]` pair (additive `Σ src·depth` clip 0..1) for bindings whose target is `\res`; `~matModTargets[v]` includes `\res` for the 10 res-voices.

- [ ] **Step 1: Write the failing test.** Add to `test_matrix.scd` (near the per-voice additive model block, after the existing rev test ~line 463), following the file's style:

```supercollider
// --- res target (cycle 1) ---
// res: additive, two sources sum and clip 0..1
~matVoiceMods[\acid] = [ (source: \rHandY, target: \res, depth: 0.5),
                          (source: \bodyY,  target: \res, depth: 0.5) ];
~matModCache[\rHandY] = 1.0; ~matModCache[\bodyY] = 1.0;   // 1*0.5 + 1*0.5 = 1.0 (clip)
pass = pass and: {
    var pairs, pf;
    pairs = ~matModPairs.(\acid, (amp: 1.0), { 1.0 });
    pf    = pairs[pairs.indexOf(\res) + 1];
    pf.notNil and: { (pf.asStream.next(()) - 1.0).abs < 0.001 }
};
~matVoiceMods[\acid] = [];
// res target is gated to res-voices: ~matModTargets[\hats] must NOT include \res
pass = pass and: { (~matModTargets[\hats] ? []).includes(\res).not };
pass = pass and: { (~matModTargets[\acid] ? []).includes(\res) };
```
(`Pfunc.value` returns self in SC — evaluate via `pf.asStream.next(())`, as the existing additive tests do.)

- [ ] **Step 2: Run to verify it FAILS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL` (or an exception) — `~matModPairs` has no `\res` branch (a `\res` target currently falls into the `amp` catch-all, so `indexOf(\res)` is -1), and `~matModTargets[\acid]` lacks `\res`.

- [ ] **Step 3: Add the `\res` branch to `~matModPairs`.** Replace the `\rev`→catch-all tail of the `byTarget.keysValuesDo` block. Current (matrix.scd ~179-190):

```supercollider
        (tgt == \rev).if({
            pairs = pairs ++ [\rev, Pfunc {
                var a = 0; list.do { |b| a = a + (~matModSourceVal.(b[\source]) * b[\depth]) };
                a.clip(0, 1)
            }]
        }, {
            pairs = pairs ++ [\amp, Pfunc {
                var base = (spec[\amp] ? 1.0) * volOf.value;
                list.do { |b| base = base * (1 + (b[\depth] * (~matModSourceVal.(b[\source]) * 2 - 1))).max(0) };
                base
            }]
        }) }) })
```
becomes (insert a `\res` branch before the amp catch-all):
```supercollider
        (tgt == \rev).if({
            pairs = pairs ++ [\rev, Pfunc {
                var a = 0; list.do { |b| a = a + (~matModSourceVal.(b[\source]) * b[\depth]) };
                a.clip(0, 1)
            }]
        }, {
        (tgt == \res).if({
            pairs = pairs ++ [\res, Pfunc {
                var a = 0; list.do { |b| a = a + (~matModSourceVal.(b[\source]) * b[\depth]) };
                a.clip(0, 1)
            }]
        }, {
            pairs = pairs ++ [\amp, Pfunc {
                var base = (spec[\amp] ? 1.0) * volOf.value;
                list.do { |b| base = base * (1 + (b[\depth] * (~matModSourceVal.(b[\source]) * 2 - 1))).max(0) };
                base
            }]
        }) }) }) })
```
(Note the extra `)` added to close the new nested `.if` — count the closing braces/parens carefully and balance-check.)

- [ ] **Step 4: Add `\res` to `~matModTargets` for the 10 res-voices.** In the `~matModTargets` IdentityDictionary (matrix.scd ~28-39), append `\res` to each of: `sub, acid, arp, lead, stab, pad, reese, bells, melody, chord`. Example edits:
  - `\sub->[\amp,\pan,\rev]` → `\sub->[\amp,\pan,\rev,\res]`
  - `\acid->[\amp,\cutoff,\pan,\rev]` → `\acid->[\amp,\cutoff,\pan,\rev,\res]`
  - …same for arp, lead, stab, pad, reese (all currently `[\amp,\cutoff,\pan,\rev]` → `+\res`)
  - `\bells->[\amp,\pan,\rev]` → `+\res`
  - `\melody->[\amp,\cutoff,\pan,\rev]` → `+\res`; `\chord->[\amp,\cutoff,\pan,\rev]` → `+\res`
  Do NOT add `\res` to any other voice (perc/tom/kick/etc. stay as-is). Keep the list values consistent with `~matResVoices` (matrix.scd:46).

- [ ] **Step 5: Balance check.** Run the `validating-scd-files` skill on `matrix.scd` and `test_matrix.scd`. Expected `P:0 B:0` each.

- [ ] **Step 6: Run to verify it PASSES.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`, zero `ERROR`, clean exit.

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat(matrix): res modulation target"
```

---

### Task 2: `pitch` modulation target (bipolar scale-degree offset)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` — `~matModPairs` select (exclude pitch), new `~matPitchOffset`/`~matPitchRange`, freq Pfunc (the step-pattern site), `~matModTargets` (+pitch)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Consumes: `~matVoiceMods`, `~matModSourceVal`, `~lpNote`, `~matModTargets`.
- Produces: `~matPitchOffset.(voiceSymbol)` → integer (bipolar sum of scale-degree offsets); `~matPitchRange` (env-tunable, default 7); the step-pattern `\freq` Pfunc adds the offset to the degree; `~matModTargets[v]` includes `\pitch` for the 10 pitch-capable voices; `~matModPairs` never emits `\pitch`.

- [ ] **Step 1: Write the failing test.** Add to `test_matrix.scd` after the Task 1 res block:

```supercollider
// --- pitch target (cycle 1): bipolar scale-degree offset ---
~matPitchRange = 7;   // make the assertion deterministic regardless of env
// +full deflection: source 1.0, depth 1.0 -> +7
~matVoiceMods[\acid] = [ (source: \rHandY, target: \pitch, depth: 1.0) ];
~matModCache[\rHandY] = 1.0;
pass = pass and: { ~matPitchOffset.(\acid) == 7 };
// -full deflection: source 0.0 -> -7
~matModCache[\rHandY] = 0.0;
pass = pass and: { ~matPitchOffset.(\acid) == -7 };
// neutral: source 0.5 -> 0
~matModCache[\rHandY] = 0.5;
pass = pass and: { ~matPitchOffset.(\acid) == 0 };
// additive: two bindings sum (1.0*+7 and 0.5-source*0 -> +7)
~matVoiceMods[\acid] = [ (source: \rHandY, target: \pitch, depth: 1.0),
                          (source: \bodyY,  target: \pitch, depth: 1.0) ];
~matModCache[\rHandY] = 1.0; ~matModCache[\bodyY] = 0.5;   // +7 + 0 = +7
pass = pass and: { ~matPitchOffset.(\acid) == 7 };
~matVoiceMods[\acid] = [];
// gating: pitch allowed on acid (melodic) but NOT on kick (percussive)
pass = pass and: { (~matModTargets[\acid] ? []).includes(\pitch) };
pass = pass and: { (~matModTargets[\kick] ? []).includes(\pitch).not };
// pitch is NOT emitted as a ~matModPairs pair (handled in the freq Pfunc)
~matVoiceMods[\acid] = [ (source: \rHandY, target: \pitch, depth: 1.0) ];
pass = pass and: { ~matModPairs.(\acid, (amp: 1.0), { 1.0 }).includes(\pitch).not };
~matVoiceMods[\acid] = [];
// freq integration: with ~lpNote stubbed, a +7 offset transposes the played note up
~origLpNote = ~lpNote;
~lpNote = { |deg, oct| 60 + deg };   // simple midi-note stub
~matVoiceMods[\acid] = [ (source: \rHandY, target: \pitch, depth: 1.0) ];
~matModCache[\rHandY] = 1.0;   // +7
~matColorDefs[5][2][\steps] = Array.fill(16, nil).put(0, (degree: 0, vel: 0.8));
~pEv = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { (~pEv[\freq] - ((60 + 0 + 7).midicps * (2 ** (~matColorDefs[5][2][\octave] ? 0)))).abs < 1.0 };
~lpNote = ~origLpNote;
~matVoiceMods[\acid] = [];
~matColorDefs[5][2][\steps] = Array.fill(16, nil);
```
(If reading `~matColorDefs[5][2][\octave]` for `freqRatio` proves awkward, assert instead that `~pEv[\freq]` is strictly GREATER than the same event built with offset 0 — a direction check is acceptable and robust. Keep whichever you can make deterministic; do NOT leave an assertion that always passes.)

- [ ] **Step 2: Run to verify it FAILS.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL`/exception — `~matPitchOffset` undefined, `~matModTargets` lacks `\pitch`, freq Pfunc not yet offset.

- [ ] **Step 3: Add `~matPitchRange` + `~matPitchOffset`.** Near the other env-tunable constants and `~matModSourceVal` (so it is defined before `~matColorStepPattern` uses it; place it just after `~matModSourceVal`'s definition or in the same region as `~matModNeutralCut`). Add:

```supercollider
~matPitchRange = ~matPitchRange ? 7;   // +/- scale degrees at full deflection (env-tunable; 7 ~= 1 octave)
~matPitchOffset = { |name|
    var off = 0;
    ((~matVoiceMods[name] ? []).select { |b| b[\target] == \pitch }).do { |b|
        off = off + (((~matModSourceVal.(b[\source]) * 2 - 1) * b[\depth] * ~matPitchRange).round.asInteger)
    };
    off
};
```
Ensure it is defined ABOVE the `~matColorStepPattern` definition (functions are assigned at load; `~matColorStepPattern`'s Pfunc only *calls* `~matPitchOffset` at play time, so definition order is not strictly required, but keep it with the mod helpers for clarity).

- [ ] **Step 4: Exclude `\pitch` from `~matModPairs`.** In the select filter (matrix.scd ~160-162), add `b[\target] != \pitch`:

```supercollider
    ((~matVoiceMods[name] ? []).select { |b|
        b[\source].notNil and: { b[\target].notNil }
            and: { b[\target] != \pitch } and: { allowed.includes(b[\target]) }
    }).do { |b| byTarget[b[\target]] = (byTarget[b[\target]] ? []) ++ [b] };
```
This prevents a `\pitch` binding from falling into the `amp` catch-all.

- [ ] **Step 5: Patch the step-pattern freq Pfunc.** At the melodic `\freq` Pfunc (matrix.scd ~226), add the offset to the degree:

Current:
```supercollider
        [\freq, Pfunc { |e| (~lpNote.notNil).if({ ~lpNote.(e[\degree], 0).midicps * freqRatio }, { 440 }) }]
```
becomes:
```supercollider
        [\freq, Pfunc { |e| (~lpNote.notNil).if({ ~lpNote.(e[\degree] + ~matPitchOffset.(name), 0).midicps * freqRatio }, { 440 }) }]
```
Do NOT change the overlay-path freq Pfunc (matrix.scd ~205: `(e[\freq] ? 440) * freqRatio`) — it inherits the base pattern's freq and has no degree, so scale-quantized pitch does not apply there. Add a one-line comment at ~205 noting pitch mod is step-path only.

- [ ] **Step 6: Add `\pitch` to `~matModTargets` for the 10 pitch-capable voices.** Append `\pitch` to each of: `sub, acid, arp, lead, stab, pad, reese, bells, perc, tom`. After Task 1 these read e.g. `\sub->[\amp,\pan,\rev,\res]` → `\sub->[\amp,\pan,\rev,\res,\pitch]`; `\perc->[\amp,\cutoff,\pan,\rev]` → `+\pitch` (perc gets pitch, no res); `\tom->[\amp,\pan,\rev]` → `+\pitch`. Do NOT add `\pitch` to melody/chord (override path, no scale-degree freq) or to any non-melodic voice.

- [ ] **Step 7: Balance check.** `validating-scd-files` on `matrix.scd` and `test_matrix.scd`. Expected `P:0 B:0` each.

- [ ] **Step 8: Run to verify it PASSES.**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`, zero `ERROR`, clean exit.

- [ ] **Step 9: Commit.**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat(matrix): pitch modulation target"
```

---

### Task 3: Web mirror — target lists + labels

**Files:**
- Modify: `web_realart/public/control/js/matrix-state.js` — `MATRIX_MOD_TARGETS`, `MOD_TARGET_LABELS`
- Test: `web_realart/test/matrix-state.test.mjs`

**Interfaces:**
- Consumes: nothing new.
- Produces: `MATRIX_MOD_TARGETS[v]` includes `"res"`/`"pitch"` matching SC eligibility; `MOD_TARGET_LABELS` has `pitch` and `res` entries.

- [ ] **Step 1: Write the failing test.** Append to `web_realart/test/matrix-state.test.mjs` (match its `import assert from "node:assert"` style; add `MATRIX_MOD_TARGETS` / `MOD_TARGET_LABELS` to the existing import from `../public/control/js/matrix-state.js` if not already imported):

```javascript
test("res target on res-voices only", () => {
  for (const v of ["sub","acid","arp","lead","stab","pad","reese","bells","melody","chord"])
    assert.ok(MATRIX_MOD_TARGETS[v].includes("res"), `${v} should allow res`);
  for (const v of ["kick","hats","perc","tom","fx"])
    assert.ok(!MATRIX_MOD_TARGETS[v].includes("res"), `${v} should NOT allow res`);
});
test("pitch target on melodic step voices only", () => {
  for (const v of ["sub","acid","arp","lead","stab","pad","reese","bells","perc","tom"])
    assert.ok(MATRIX_MOD_TARGETS[v].includes("pitch"), `${v} should allow pitch`);
  for (const v of ["kick","hats","clap","melody","chord","fx"])
    assert.ok(!MATRIX_MOD_TARGETS[v].includes("pitch"), `${v} should NOT allow pitch`);
});
test("MOD_TARGET_LABELS covers pitch and res", () => {
  assert.ok(MOD_TARGET_LABELS.pitch);
  assert.ok(MOD_TARGET_LABELS.res);
});
```

- [ ] **Step 2: Run to verify it FAILS.**

Run: `cd web_realart && node --test test/*.test.mjs`
Expected: the 3 new tests FAIL (targets/labels missing); existing tests still pass.

- [ ] **Step 3: Update `MATRIX_MOD_TARGETS`.** In `matrix-state.js`, append to each voice's list to mirror SC exactly:
  - `+ "res"` on: sub, acid, arp, lead, stab, pad, reese, bells, melody, chord.
  - `+ "pitch"` on: sub, acid, arp, lead, stab, pad, reese, bells, perc, tom.
  Example: `acid:["none","amp","cutoff","pan","rev"]` → `acid:["none","amp","cutoff","pan","rev","res","pitch"]`; `perc:["none","amp","cutoff","pan","rev"]` → `+"pitch"`; `melody:["none","amp","cutoff","pan","rev"]` → `+"res"`; `tom:["none","amp","pan","rev"]` → `+"pitch"`; `sub:["none","amp","pan","rev"]` → `+"res","pitch"`. Leave kick/hats/clap/ride/rim/sweep/fx/snare/crash/shaker unchanged.

- [ ] **Step 4: Update `MOD_TARGET_LABELS`.** Add entries:
```javascript
export const MOD_TARGET_LABELS = { none:"—", amp:"volume", cutoff:"cutoff", pan:"pan", rev:"reverb", res:"résonance", pitch:"pitch" };
```

- [ ] **Step 5: Run to verify it PASSES.**

Run: `cd web_realart && node --test test/*.test.mjs`
Expected: all pass (existing + 3 new).

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(web): pitch and res mod targets"
```

---

## Self-review

**Spec coverage:**
- §1 res target (independent additive Pbind key, res-voices) → Task 1. ✓
- §2 pitch target (bipolar scale-degree offset, freq Pfunc, melodic voices, excluded from matModPairs) → Task 2. ✓
- §2 "apply to every freq Pfunc / patch the one true site" → Task 2 Step 5 patches the step-pattern site and documents the overlay site is n/a. ✓
- §3 gating via `~matModTargets` (no new gate) → Tasks 1/2 extend `~matModTargets`; existing `~matSetVoiceMod` enforces. ✓
- §4 web labels + targets → Task 3. ✓
- §Testing → Tasks 1/2 (SC), Task 3 (web). ✓

**Placeholder scan:** No TBD/TODO. The freq-integration test gives a deterministic assertion AND a robust direction-check fallback (explicitly "do not leave an assertion that always passes"). The `\res` branch edit shows the exact before/after with a brace-balance caution.

**Type consistency:** `~matPitchOffset.(name)` returns an integer, added to `e[\degree]` (integer) — consistent. `~matModTargets` symbols (`\res`,`\pitch`) ↔ web strings (`"res"`,`"pitch"`) ↔ `MOD_TARGET_LABELS` keys — consistent. Eligibility sets (pitch=10 freq voices, res=10 res-voices) are identical between the SC tasks, the web task, and the spec's eligibility table. `~matModPairs` excludes `\pitch` (Task 2 Step 4) so it never reaches the amp catch-all; `\res` has its own branch (Task 1 Step 3) before the catch-all.
