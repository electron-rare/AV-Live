# Per-voice modulation/pose + expanded iPhone sources + FR names — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every iPhone-derived value usable as per-instrument (per-voice) modulation in the matrix sequencer, with an additive multi-binding model, a curated pose/event system, FR display labels, and live value meters.

**Architecture:** SuperCollider holds the truth: `~matModCache` (source values, fed by new OSCdefs from already-emitted `/pose/*` routes), `~matVoiceMods[voice]` (additive binding lists) and `~matVoicePoses[voice]` (trigger/gate bindings). The web control surface edits voice-level state over new `/matrix/voicemod` and `/matrix/voicepose` routes and shows live meters from a `/matrix/modvalues` push. One Python one-liner exposes `mouth_open` as `/pose/mouth`.

**Tech Stack:** SuperCollider (sclang/scsynth), vanilla ES modules + Node (`web_realart`), `python-osc` (`data_only_viz`), `node --test`, `uv` for Python.

## Global Constraints

- Python: **uv** only (never pip/poetry/conda directly).
- No emojis in code/docs/commits.
- Commits: subject ≤ 50 chars, body ≤ 72 chars/line, no AI attribution, no `--no-verify`, no underscore in the commit scope (hooks enforce).
- `.scd` files MUST stay balanced: parens P:0 and brackets B:0; files loaded via `.load` keep exactly one top-level block (TLB:1). Run the `validating-scd-files` skill after every `.scd` edit.
- Modulation source IDs are **symbols on the wire and in presets** — never renamed. FR labels live only in the web display layer.
- Git fallback for push (Gitea SSH broken): `https://electron@git.saillant.cc/<org>/<repo>.git`. Push only when the user asks.
- macm1 is the live engine host (`ssh macm1`, Tailscale `100.120.142.74`); GrosMac is dev.

## Canonical source order (single source of truth, mirrored SC ↔ web)

```
lHandY, rHandY, lHandX, rHandX, lOpen, rOpen, handSpeed, handDist,
bodyX, bodyY, depth, bodyVitesse, bodyAccel, bodySym, headX, headY,
limbSpan, danse, mouthOpen
```
19 sources. `/matrix/modvalues` sends them in exactly this order. SC: `~matModOrder`. Web: `MOD_SOURCE_ORDER`.

## File structure

| File | Responsibility | Change |
|------|----------------|--------|
| `sound_algo/data_only/matrix.scd` | engine: cache, mods, poses, OSC, save/load | modify (most tasks) |
| `sound_algo/data_only/test/test_matrix.scd` | SC assertions | extend |
| `data_only_viz/pose_bridge.py` | OSC emit to SC | add `/pose/mouth` emit |
| `web_realart/public/control/js/matrix-state.js` | data layer: sources, labels, per-voice state | modify |
| `web_realart/public/control/js/voice-editor.js` | MOD/POSE tab UI + OSC handlers | modify |
| `web_realart/public/control/js/__tests__/matrix-state.test.js` | web unit tests | create |
| `sound_algo/data_only/matrix_presets/generate_presets.py` | preset emit | modify |
| `sound_algo/data_only/matrix_presets/patterns.py` | demo mappings | modify (optional demo) |

### SC test protocol (authoritative — supersedes any standalone harness shown in a task)

`sound_algo/data_only/test/test_matrix.scd` is the canonical SC harness and the ONLY place SC assertions go. Verified facts:

- **Run:** `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd` (the binary is NOT on `$PATH`; there is **no `timeout`/`gtimeout`** on this macOS host — the script self-terminates and the Bash-tool timeout bounds any runaway).
- **Server is NOT booted.** The harness stubs `~toscSend`/`~toscTouch`, defines dummy `Pdef(\lp_*)`, sets a minimal `~lp = (clock: TempoClock.default)`, then `featureFile.load`s `../matrix.scd`. It is fast and deterministic — not flaky.
- **Assertion style:** accumulate `pass = pass and: { <cond> };`, wrap risky calls in `try { } { |e| pass = false; (...).postln }`. Final output line is `TEST PASS` (and no `ERROR` lines).
- **Testing OSCdef logic without a server:** call the registered function directly, e.g. `OSCdef(\mat_mod_kin).func.value(['/pose/kin', 0, 1.5, 5.0, 0.0]);` then assert on `~matModCache`. Call `~mat*` functions directly the same way.
- **Each SC task:** (1) balance-check the edited `.scd` with the `validating-scd-files` skill (P:0 B:0); (2) add assertions to `test_matrix.scd` in its existing style; (3) run the harness, expect `TEST PASS`. The per-task "logic harness" code blocks below are illustrative content for the assertions — fold them into `test_matrix.scd`, do NOT create standalone `scratchpad/*.scd` boot scripts. Final behavior acceptance is the macm1 live smoke (Task 14).

---

## Phase 1 — SuperCollider engine

### Task 1: New continuous mod sources (cache OSCdefs + source list)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd:867-895` (sources list + cache OSCdefs)
- Test: targeted harness `scratchpad/t1_sources.scd` (create)

**Interfaces:**
- Produces: `~matModSources` (19 symbols), `~matModOrder` (19, no `none`), `~matKinSpeedMax`/`~matKinAccelMax`/`~matLimbSpanGain` (env-tunable floats), new OSCdefs `\mat_mod_kin`, `\mat_mod_head`, `\mat_mod_limb`, `\mat_mod_mouth`, and an extended `\mat_mod_action` writing `~matModCache[\danse]`.
- Consumes: existing `~matModCache`, `~matModSourceVal`.

- [ ] **Step 1: Extend the source list.** Replace `matrix.scd:869-871`:

```supercollider
~matModSources = ~matModSources ?
    [\lHandY, \rHandY, \lHandX, \rHandX, \lOpen, \rOpen, \handSpeed, \handDist,
     \bodyX, \bodyY, \depth];
```
with:
```supercollider
~matModSources = ~matModSources ?
    [\lHandY, \rHandY, \lHandX, \rHandX, \lOpen, \rOpen, \handSpeed, \handDist,
     \bodyX, \bodyY, \depth,
     \bodyVitesse, \bodyAccel, \bodySym, \headX, \headY, \limbSpan, \danse, \mouthOpen];

// Fixed wire order for /matrix/modvalues (mirrors web MOD_SOURCE_ORDER). No \none.
~matModOrder = [
    \lHandY, \rHandY, \lHandX, \rHandX, \lOpen, \rOpen, \handSpeed, \handDist,
    \bodyX, \bodyY, \depth, \bodyVitesse, \bodyAccel, \bodySym, \headX, \headY,
    \limbSpan, \danse, \mouthOpen];

// Normalization for raw iPhone units -> 0..1 (env-tunable, no code edit to retune).
~matKinSpeedMax  = ~matKinSpeedMax  ? 3.0;    // m/s mapped to 1.0
~matKinAccelMax  = ~matKinAccelMax  ? 10.0;   // m/s^2 mapped to 1.0
~matLimbSpanGain = ~matLimbSpanGain ? 1.0;    // limb span scale
```

- [ ] **Step 2: Add the continuous-source OSCdefs.** After the `\mat_mod_span` block (ends `matrix.scd:895`), insert:

```supercollider
OSCdef(\mat_mod_kin, { |msg|
    // /pose/kin [pid, speed, accel, sym]
    ~matModCache[\bodyVitesse] = ((msg[2] ? 0) / ~matKinSpeedMax).clip(0, 1);
    ~matModCache[\bodyAccel]   = ((msg[3] ? 0) / ~matKinAccelMax).clip(0, 1);
    ~matModCache[\bodySym]     = (((msg[4] ? 0) + 1) / 2).clip(0, 1);
}, '/pose/kin');

OSCdef(\mat_mod_head, { |msg|
    // /pose/head [pid, x, y, c]
    ~matModCache[\headX] = (msg[2] ? 0.5).clip(0, 1);
    ~matModCache[\headY] = (1 - (msg[3] ? 0.5)).clip(0, 1);
}, '/pose/head');

OSCdef(\mat_mod_limb, { |msg|
    // /pose/limb_span [pid, span]
    ~matModCache[\limbSpan] = ((msg[2] ? 0) * ~matLimbSpanGain).clip(0, 1);
}, '/pose/limb_span');

OSCdef(\mat_mod_mouth, { |msg|
    // /pose/mouth [pid, open]
    ~matModCache[\mouthOpen] = (msg[2] ? 0).clip(0, 1);
}, '/pose/mouth');

~matActionLabels = ~matActionLabels ? [\debout, \assise, \danse];
~matLastAction   = ~matLastAction   ? IdentityDictionary.new;
OSCdef(\mat_mod_action, { |msg|
    // /pose/action [pid, idx, p0, p1, p2] : danse proba feeds \danse; label change fires pose
    var pid = (msg[1] ? 0).asInteger;
    var idx = (msg[2] ? 0).asInteger.clip(0, 2);
    var lab = ~matActionLabels[idx];
    ~matModCache[\danse] = (msg[5] ? 0).clip(0, 1);
    (~matLastAction[pid] != lab).if({ ~matLastAction[pid] = lab; ~matPoseFire.(lab) });
}, '/pose/action');
```
(`~matPoseFire` is the per-voice version delivered in Task 4; `\mat_mod_action`'s pose-fire only matters once Task 4 lands — registering it now is harmless because `~matPoseFire` already exists in its per-colour form.)

- [ ] **Step 3: Balance check (hard gate).** Use the `validating-scd-files` skill on `matrix.scd`. Expected: `P:0 B:0`.

- [ ] **Step 4: Write the logic harness** `scratchpad/t1_sources.scd`:

```supercollider
// Boots the matrix engine, injects /pose/* messages, asserts cache values.
// Run: sclang scratchpad/t1_sources.scd  (no audio needed for cache asserts)
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;   // adjust if the boot entry differs
SystemClock.sched(2.0, {
    var n = NetAddr("127.0.0.1", 57121);
    n.sendMsg("/pose/kin", 0, 1.5, 5.0, 0.0);        // speed=1.5 accel=5 sym=0
    n.sendMsg("/pose/head", 0, 0.3, 0.25, 1.0);      // x=0.3 y=0.25
    n.sendMsg("/pose/limb_span", 0, 0.7);
    n.sendMsg("/pose/mouth", 0, 0.8);
    n.sendMsg("/pose/action", 0, 2, 0.1, 0.2, 0.7);  // danse proba 0.7
    SystemClock.sched(0.5, {
        [\bodyVitesse, 0.5, \bodyAccel, 0.5, \bodySym, 0.5, \headX, 0.3,
         \headY, 0.75, \limbSpan, 0.7, \mouthOpen, 0.8, \danse, 0.7]
        .pairsDo { |k, want|
            var got = (~matModCache[k] ? -1);
            ((got - want).abs < 0.02).if(
                { ("OK  " ++ k ++ " = " ++ got).postln },
                { ("FAIL " ++ k ++ " got " ++ got ++ " want " ++ want).postln });
        };
        0.exit;
    });
    nil;
});
)
```
If `00_load.scd` is not the matrix boot entry, find it with `grep -rl "matrix.scd" sound_algo/data_only --include=*.scd` and use that path.

- [ ] **Step 5: Run the harness.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t1_sources.scd 2>&1 | grep -E "OK|FAIL"`
Expected: 8 `OK` lines, 0 `FAIL`. (`bodyVitesse=0.5` because 1.5/3.0; `bodyAccel=0.5` because 5/10; `bodySym=0.5` because (0+1)/2.)

- [ ] **Step 6: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): route new iphone mod sources"
```

---

### Task 2: Per-voice additive modulation model (`~matVoiceMods` + `~matModPairs`)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd:154-173` (`~matModPairs`)
- Modify: `sound_algo/data_only/matrix.scd:867-868` area (declare `~matVoiceMods`)
- Test: harness `scratchpad/t2_modpairs.scd` (create)

**Interfaces:**
- Produces: `~matVoiceMods` (IdentityDictionary: voiceSymbol -> Array of `(source:, target:, depth:)`). `~matModPairs.(name, spec, volOf)` now returns a **flattened list** `[target1, Pfunc1, target2, Pfunc2, ...]` (possibly empty), additive per target, read from `~matVoiceMods[name]` instead of `spec[\mod]`.
- Consumes: `~matModTargets`, `~matModNeutralCut`, `~matResVoices`, `~matModSourceVal`, `~matModSources`.
- Note: callers of `~matModPairs` (`~matColorStepPattern`, `~matVariationOverlay`) splice the return with `++`; the flattened-pair contract is preserved, so call sites need no change. Verify with `grep -n "matModPairs" matrix.scd` before editing.

- [ ] **Step 1: Declare `~matVoiceMods`.** Immediately after `matrix.scd:868` (`~matModCache = ~matModCache ? IdentityDictionary.new;`) add:

```supercollider
~matVoiceMods  = ~matVoiceMods  ? IdentityDictionary.new;   // voice -> [ (source:,target:,depth:) ]
~matVoicePoses = ~matVoicePoses ? IdentityDictionary.new;   // voice -> [ (poseId:,action:) ]
```

- [ ] **Step 2: Write the failing harness** `scratchpad/t2_modpairs.scd`:

```supercollider
// Pure data-layer test of additive ~matModPairs. No scsynth needed.
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;
SystemClock.sched(2.0, {
    var spec = (amp: 1.0);
    var volOf = { 1.0 };
    var pairs, pf;
    // two sources -> same pan target, additive
    ~matVoiceMods[\acid] = [ (source: \rHandX, target: \pan, depth: 0.5),
                             (source: \bodyX,  target: \pan, depth: 0.5) ];
    ~matModCache[\rHandX] = 1.0;   // (1*2-1)*0.5 = +0.5
    ~matModCache[\bodyX]  = 0.0;   // (0*2-1)*0.5 = -0.5  -> sum 0.0
    pairs = ~matModPairs.(\acid, spec, volOf);
    pf = pairs[pairs.indexOf(\pan) + 1];
    ((pf.value).abs < 0.001).if({ "OK pan-additive".postln }, { ("FAIL pan " ++ pf.value).postln });
    // single rev source
    ~matVoiceMods[\acid] = [ (source: \rev_dummy, target: \rev, depth: 1.0) ];
    ~matVoiceMods[\acid] = [ (source: \handDist, target: \rev, depth: 1.0) ];
    ~matModCache[\handDist] = 0.4;
    pairs = ~matModPairs.(\acid, spec, volOf);
    pf = pairs[pairs.indexOf(\rev) + 1];
    ((pf.value - 0.4).abs < 0.001).if({ "OK rev".postln }, { ("FAIL rev " ++ pf.value).postln });
    // disallowed target is ignored (kick has no cutoff)
    ~matVoiceMods[\kick] = [ (source: \bodyY, target: \cutoff, depth: 1.0) ];
    pairs = ~matModPairs.(\kick, (amp:1.0), volOf);
    (pairs.includes(\cutoff).not).if({ "OK gate".postln }, { "FAIL gate".postln });
    0.exit;
});
)
```

- [ ] **Step 3: Run to verify it FAILS.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t2_modpairs.scd 2>&1 | grep -E "OK|FAIL|ERROR"`
Expected: failures/errors — `~matModPairs` still reads `spec[\mod]` and returns a single 2-element pair, so `indexOf(\pan)` math and additivity are wrong.

- [ ] **Step 4: Rewrite `~matModPairs`.** Replace `matrix.scd:154-173` entirely with:

```supercollider
~matModPairs = { |name, spec, volOf|
    var allowed = ~matModTargets[name] ? [];
    var byTarget = IdentityDictionary.new;
    var pairs = [];
    ((~matVoiceMods[name] ? []).select { |b|
        b[\source].notNil and: { b[\target].notNil } and: { allowed.includes(b[\target]) }
    }).do { |b| byTarget[b[\target]] = (byTarget[b[\target]] ? []) ++ [b] };
    byTarget.keysValuesDo { |tgt, list|
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            pairs = pairs ++ [\cutoff, Pfunc {
                var f = c0;
                list.do { |b| var s = ~matModSourceVal.(b[\source]);
                    f = f * (s.linexp(0, 1, 200, 6000) / c0).pow(b[\depth]) };
                f
            }]
        }, {
        (tgt == \pan).if({
            pairs = pairs ++ [\pan, Pfunc {
                var a = 0; list.do { |b| a = a + ((~matModSourceVal.(b[\source]) * 2 - 1) * b[\depth]) };
                a.clip(-1, 1)
            }]
        }, {
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
    };
    pairs
};
```

- [ ] **Step 5: Balance check.** `validating-scd-files` skill on `matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 6: Run harness to verify it PASSES.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t2_modpairs.scd 2>&1 | grep -E "OK|FAIL"`
Expected: `OK pan-additive`, `OK rev`, `OK gate`.

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): per-voice additive modulation pairs"
```

---

### Task 3: `/matrix/voicemod` set/get + echo push

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` — add `~matSetVoiceMod`, `~matVoiceModPush` (near `~matSetColorMod`, ~690), add OSCdefs (replace `\mat_colormod` block at 747-751)

**Interfaces:**
- Produces: `~matSetVoiceMod.(vi, n, argsTail)`, `~matVoiceModPush.(vi)`, OSCdefs `\mat_voicemod` (`/matrix/voicemod [vi, n, src1, tgt1, depth1, ...]`), `\mat_voicemod_get` (`/matrix/voicemod/get [vi]`).
- Consumes: `~matVoiceMods`, `~matModSources`, `~matModTargets`, `~matVoices`, `~toscSend`, `~matApplyBar`.

- [ ] **Step 1: Add setter + push.** Before `~matSetColorMod` (`matrix.scd:690`), insert:

```supercollider
// -- ~matSetVoiceMod : replace a voice's whole additive binding list; validate; re-source; echo --
~matSetVoiceMod = { |vi, n, tail|
    ((vi >= 0) and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var allowed = ~matModTargets[name] ? [];
        ~matVoiceMods[name] = Array.fill(n.asInteger, { |k|
            var s = (tail[k * 3]       ? \none).asSymbol;
            var t = (tail[(k * 3) + 1] ? \none).asSymbol;
            var d = (tail[(k * 3) + 2] ? 0).asFloat.clip(0, 1);
            ((s != \none) and: { t != \none }
                and: { ~matModSources.includes(s) } and: { allowed.includes(t) }).if(
                { (source: s, target: t, depth: d) }, { nil })
        }).reject({ |x| x.isNil });
        ~matLastColor[vi] = -1;
        (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
        ~matVoiceModPush.(vi)
    })
};

// -- ~matVoiceModPush : echo a voice's binding list to surfaces --
~matVoiceModPush = { |vi|
    ~toscSend !? {
        ((vi >= 0) and: { vi < ~matVoices.size }).if({
            var list = ~matVoiceMods[~matVoices[vi]] ? [];
            var flat = list.collect({ |m| [m[\source], m[\target], m[\depth]] }).flatten;
            ~toscSend.valueArray(["/matrix/voicemod", vi, list.size] ++ flat)
        })
    }
};
```

- [ ] **Step 2: Replace the `\mat_colormod` OSCdef.** Replace `matrix.scd:747-751`:

```supercollider
OSCdef(\mat_colormod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetColorMod.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger,
        (msg[3] ? \none).asSymbol, (msg[4] ? \none).asSymbol, (msg[5] ? 0).asFloat)
}, '/matrix/colormod');
```
with:
```supercollider
OSCdef(\mat_voicemod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetVoiceMod.((msg[1] ? 0).asInteger, (msg[2] ? 0).asInteger, msg.copyToEnd(3))
}, '/matrix/voicemod');
OSCdef(\mat_voicemod_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matVoiceModPush.((msg[1] ? 0).asInteger)
}, '/matrix/voicemod/get');
```

- [ ] **Step 3: Balance check.** `validating-scd-files` on `matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 4: Harness** `scratchpad/t3_voicemod.scd`:

```supercollider
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;
SystemClock.sched(2.0, {
    var n = NetAddr("127.0.0.1", 57121);
    // vi=5 is \acid (cutoff allowed). 2 bindings; a disallowed one (\acid has no \res target in modTargets) dropped.
    n.sendMsg("/matrix/voicemod", 5, 3, "bodyVitesse","cutoff",0.6, "rHandY","pan",0.4, "bogus","amp",0.9);
    SystemClock.sched(0.5, {
        var l = ~matVoiceMods[\acid];
        ((l.size == 2) and: { l[0][\source] == \bodyVitesse } and: { l[1][\target] == \pan }).if(
            { "OK voicemod-set".postln }, { ("FAIL " ++ l).postln });
        0.exit;
    });
    nil;
});
)
```
(`"bogus"` is not in `~matModSources` so the 3rd binding is rejected → size 2.)

- [ ] **Step 5: Run.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t3_voicemod.scd 2>&1 | grep -E "OK|FAIL"`
Expected: `OK voicemod-set`.

- [ ] **Step 6: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): voicemod set/get OSC routes"
```

---

### Task 4: Per-voice pose system (`~matVoicePoses` + `~matPoseFire` + `/matrix/voicepose`)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd:766-789` (`~matPoseFire`)
- Modify: `sound_algo/data_only/matrix.scd:752-764` (replace `\mat_colorpose`, `\mat_colorpose_get`)
- Add: `~matSetVoicePose`, `~matVoicePosePush`, event-mapping OSCdefs for `/pose/finger`, `/pose/pinch`

**Interfaces:**
- Produces: `~matSetVoicePose.(vi, n, tail)`, `~matVoicePosePush.(vi)`, `~matEventFinger.(hand, finger)`, `~matEventPinch.(hand, finger)`, OSCdefs `\mat_voicepose`, `\mat_voicepose_get`, `\mat_ev_finger`, `\mat_ev_pinch`. `~matPoseFire.(poseId)` now iterates `~matVoicePoses[name]`.
- Consumes: `~matVoicePoses`, `~matVoices`, `~lp[\matrix]`, `~lp[\matBar]`, `~matVariation`, `~toscSend`.

- [ ] **Step 1: Rewrite `~matPoseFire`.** Replace `matrix.scd:766-789`:

```supercollider
~matPoseFire = { |poseId|
    var pid = poseId.asSymbol;
    ~matVoices.do { |name, vi|
        var key = ("lp_" ++ name).asSymbol;
        ((~matVoicePoses[name]) ? []).do { |b|
            (b[\poseId] == pid).if({
                var bar   = ~lp[\matBar] ? 0;
                var color = (~lp[\matrix][vi][bar] ? 0);
                color = (color == 0).if({ 1 }, { color });
                (b[\action] == \trigger).if({
                    Pdef.all.includesKey(key).if({
                        var pat = ~matVariation.(name, color, vi);
                        pat.notNil.if({ Pdef(key, pat); Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) })
                    })
                });
                (b[\action] == \gate).if({
                    Pdef.all.includesKey(key).if({ Pdef(key).isPlaying.if({ Pdef(key).stop },
                        { Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) }) })
                });
            })
        }
    }
};
```

- [ ] **Step 2: Add setter, push, event mappers.** Immediately after the rewritten `~matPoseFire` (before `OSCdef(\mat_pose ...)` at 791), insert:

```supercollider
// -- ~matSetVoicePose : replace a voice's pose binding list; echo --
~matSetVoicePose = { |vi, n, tail|
    ((vi >= 0) and: { vi < ~matVoices.size }).if({
        ~matVoicePoses[~matVoices[vi]] = Array.fill(n.asInteger, { |k|
            var pid = (tail[k * 2]       ? \none).asSymbol;
            var act = (tail[(k * 2) + 1] ? \trigger).asSymbol;
            ((pid == \none) or: { pid == '' }).if({ nil }, { (poseId: pid, action: act) })
        }).reject({ |x| x.isNil });
        ~matVoicePosePush.(vi)
    })
};

~matVoicePosePush = { |vi|
    ~toscSend !? {
        ((vi >= 0) and: { vi < ~matVoices.size }).if({
            var list = ~matVoicePoses[~matVoices[vi]] ? [];
            var flat = list.collect({ |b| [b[\poseId], b[\action]] }).flatten;
            ~toscSend.valueArray(["/matrix/voicepose", vi, list.size] ++ flat)
        })
    }
};

// canonical event -> poseId mappers (hand 0=L,1=R; finger strikes 1..5, pinch 1..4)
~matEventFinger = { |hand, finger| ("finger" ++ (hand.asInteger == 0).if({ "L" }, { "R" }) ++ (finger.asInteger + 1)).asSymbol };
~matEventPinch  = { |hand, finger| ("pinch"  ++ (hand.asInteger == 0).if({ "L" }, { "R" }) ++ finger.asInteger).asSymbol };

OSCdef(\mat_ev_finger, { |msg| ~matPoseFire.(~matEventFinger.(msg[1] ? 0, msg[2] ? 0)) }, '/pose/finger');
OSCdef(\mat_ev_pinch,  { |msg| ~matPoseFire.(~matEventPinch.(msg[1] ? 0, msg[2] ? 1)) }, '/pose/pinch');
```

- [ ] **Step 3: Replace the colorpose OSCdefs.** Replace `matrix.scd:752-764` (the `\mat_colorpose` and `\mat_colorpose_get` blocks) with:

```supercollider
OSCdef(\mat_voicepose, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetVoicePose.((msg[1] ? 0).asInteger, (msg[2] ? 0).asInteger, msg.copyToEnd(3))
}, '/matrix/voicepose');
OSCdef(\mat_voicepose_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matVoicePosePush.((msg[1] ? 0).asInteger)
}, '/matrix/voicepose/get');
```

- [ ] **Step 4: Balance check.** `validating-scd-files` on `matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 5: Harness** `scratchpad/t4_voicepose.scd`:

```supercollider
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;
SystemClock.sched(2.0, {
    var n = NetAddr("127.0.0.1", 57121);
    n.sendMsg("/matrix/voicepose", 5, 2, "danse","gate", "fingerR2","trigger");
    SystemClock.sched(0.4, {
        var l = ~matVoicePoses[\acid];
        ((l.size == 2) and: { l[0][\poseId] == \danse } and: { l[1][\action] == \trigger }).if(
            { "OK voicepose".postln }, { ("FAIL " ++ l).postln });
        (~matEventFinger.(1, 1) == \fingerR2).if({ "OK finger-map".postln }, { "FAIL finger-map".postln });
        (~matEventPinch.(0, 3) == \pinchL3).if({ "OK pinch-map".postln }, { "FAIL pinch-map".postln });
        0.exit;
    });
    nil;
});
)
```

- [ ] **Step 6: Run.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t4_voicepose.scd 2>&1 | grep -E "OK|FAIL"`
Expected: `OK voicepose`, `OK finger-map`, `OK pinch-map`.

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): per-voice pose + finger/pinch events"
```

---

### Task 5: Live `/matrix/modvalues` push (~12 Hz)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` — add push fn + routine near `~matModOrder` (Task 1 area)

**Interfaces:**
- Produces: `~matModValuesPush.()`, `~matModValuesRoutine` (AppClock loop), outbound `/matrix/modvalues [v0 .. v18]` in `~matModOrder`.
- Consumes: `~matModCache`, `~matModOrder`, `~toscSend`.

- [ ] **Step 1: Add the push + routine.** After the `~matKinSpeedMax`/etc. block from Task 1, add:

```supercollider
~matModValuesPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/modvalues"]
            ++ ~matModOrder.collect({ |k| (~matModCache[k] ? 0).clip(0, 1) }))
    }
};
~matModValuesRoutine !? { ~matModValuesRoutine.stop };
~matModValuesRoutine = Routine({ loop { ~matModValuesPush.(); (1/12).wait } }).play(AppClock);
```

- [ ] **Step 2: Balance check.** `validating-scd-files` on `matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 3: Harness** `scratchpad/t5_modvalues.scd` (asserts an outbound message is emitted):

```supercollider
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;
SystemClock.sched(2.0, {
    var got = false;
    OSCFunc({ |msg| (msg.size == 20).if({ got = true }) }, '/matrix/modvalues');
    ~matModCache[\bodyVitesse] = 0.5;
    SystemClock.sched(0.5, {
        got.if({ "OK modvalues-emit".postln }, { "FAIL no modvalues".postln });
        0.exit;
    });
    nil;
});
)
```
(`msg.size == 20`: address arg + 19 values. If `~toscSend` targets the feedback host/port, the local `OSCFunc` may not see it; in that case validate via the web meter in Task 12 instead and mark this harness "smoke-only".)

- [ ] **Step 4: Run.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t5_modvalues.scd 2>&1 | grep -E "OK|FAIL"`
Expected: `OK modvalues-emit` (or defer to Task 12 web verification if `~toscSend` is remote).

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): push live modvalues at 12 Hz"
```

---

### Task 6: Persistence + legacy migration (save/load voice mods + poses)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd:562-575` (`~matSave`)
- Modify: `sound_algo/data_only/matrix.scd:577-647` (`~matLoadFile`)

**Interfaces:**
- Consumes: `~matVoiceMods`, `~matVoicePoses`, `~matColorDefs`, `~matVoices`, `~matVoiceModPush`, `~matVoicePosePush`.
- Produces: `.matrix` payload gains `voiceMods:` and `voicePoses:` keys. Legacy per-colour `\mod`/`\pose` (and legacy `raw[\mods]`) migrate into voice lists on load.

- [ ] **Step 1: Extend `~matSave` payload.** In `matrix.scd:566-570`, replace the `payload` Event with:

```supercollider
    var payload = (
        grid: ~lp[\matrix],
        instruments: ~matInstruments.collect({ |x| (x ? \default) }),
        colorDefs: ~matColorDefs.collect({ |defs| (1..6).collect({ |c| defs[c] }) }),
        voiceMods:  ~matVoices.collect({ |name| ~matVoiceMods[name]  ? [] }),
        voicePoses: ~matVoices.collect({ |name| ~matVoicePoses[name] ? [] })
    );
```

- [ ] **Step 2: Restore + migrate on load.** In `~matLoadFile`, immediately BEFORE `~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) });` (`matrix.scd:632`), insert:

```supercollider
            // -- voice-level mods/poses: reset, restore new format, then migrate legacy --
            ~matVoices.do { |name| ~matVoiceMods[name] = []; ~matVoicePoses[name] = [] };
            ((raw.isArray.not) and: { raw[\voiceMods].notNil }).if({
                raw[\voiceMods].do { |list, vi| (list.isArray and: { vi < ~matVoices.size }).if({
                    ~matVoiceMods[~matVoices[vi]] = list.select({ |m| m.isKindOf(Event) and: { m[\source].notNil } })
                }) }
            });
            ((raw.isArray.not) and: { raw[\voicePoses].notNil }).if({
                raw[\voicePoses].do { |list, vi| (list.isArray and: { vi < ~matVoices.size }).if({
                    ~matVoicePoses[~matVoices[vi]] = list.select({ |b| b.isKindOf(Event) and: { b[\poseId].notNil } })
                }) }
            });
            // legacy: collapse per-colour \mod/\pose into voice lists (dedup) when new keys absent
            (raw.isArray.not).if({
                ~matVoices.do { |name, vi|
                    (~matVoiceMods[name].isEmpty).if({
                        var seen = [], acc = [];
                        (1..6).do { |c| var m = ~matColorDefs[vi][c][\mod];
                            (m.notNil and: { seen.includes(m[\target]).not }).if({
                                seen = seen.add(m[\target]);
                                acc = acc.add((source: m[\source], target: m[\target], depth: m[\depth])) }) };
                        ~matVoiceMods[name] = acc;
                    });
                    (~matVoicePoses[name].isEmpty).if({
                        var acc = [];
                        (1..6).do { |c| ((~matColorDefs[vi][c][\pose]) ? []).do { |b|
                            (acc.any({ |x| (x[\poseId] == b[\poseId]) and: { x[\action] == b[\action] } }).not).if({
                                acc = acc.add((poseId: b[\poseId], action: b[\action])) }) } };
                        ~matVoicePoses[name] = acc;
                    });
                }
            });
```

- [ ] **Step 3: Push voice state after load.** In `~matLoadFile`, after `~matVoices.size.do { |vi| (1..6).do { |c| ~matStepsPush.(vi, c) } };` (`matrix.scd:636`), add:

```supercollider
            ~matVoices.size.do { |vi| ~matVoiceModPush.(vi); ~matVoicePosePush.(vi) };
```

- [ ] **Step 4: Balance check.** `validating-scd-files` on `matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 5: Harness** `scratchpad/t6_persist.scd` (save then reload, assert round-trip + legacy collapse):

```supercollider
(
~AVLIVE_HEADLESS = true;
"sound_algo/data_only/00_load.scd".loadRelative;
SystemClock.sched(2.0, {
    // round-trip new format
    ~matVoiceMods[\acid]  = [ (source: \bodyVitesse, target: \cutoff, depth: 0.6) ];
    ~matVoicePoses[\acid] = [ (poseId: \danse, action: \gate) ];
    ~matSave.("t6_tmp");
    ~matVoiceMods[\acid] = []; ~matVoicePoses[\acid] = [];
    ~matLoad.("t6_tmp");
    SystemClock.sched(0.5, {
        var m = ~matVoiceMods[\acid], p = ~matVoicePoses[\acid];
        ((m.size == 1) and: { m[0][\target] == \cutoff } and: { p.size == 1 } and: { p[0][\poseId] == \danse }).if(
            { "OK persist".postln }, { ("FAIL " ++ m ++ " / " ++ p).postln });
        0.exit;
    });
    nil;
});
)
```

- [ ] **Step 6: Run.**

Run: `cd sound_algo/data_only && timeout 60 sclang ../../scratchpad/t6_persist.scd 2>&1 | grep -E "OK|FAIL"`
Expected: `OK persist`. Then clean: `rm -f ~/.config/av-live/matrices/t6_tmp.matrix`.

- [ ] **Step 7: Commit.**

```bash
git add sound_algo/data_only/matrix.scd
git commit -m "feat(matrix): persist + migrate voice mods/poses"
```

---

### Task 7: Extend `test_matrix.scd` + final SC sweep

**Files:**
- Modify: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:** consumes everything from Tasks 1-6.

- [ ] **Step 1: Read the existing test file's style.** `grep -n "assert\|TEST\|\.do\|postln" sound_algo/data_only/test/test_matrix.scd | head -30` — match its assertion helper and structure.

- [ ] **Step 2: Add test cases** mirroring harnesses t1-t6 (cache routing, additive pairs, voicemod validation, voicepose + event mappers, persistence round-trip) using the file's existing assertion helper. Keep one block per concern.

- [ ] **Step 3: Balance check.** `validating-scd-files` on `test_matrix.scd`. Expected `P:0 B:0`.

- [ ] **Step 4: Run the suite (best-effort).**

Run: `cd sound_algo/data_only && timeout 120 sclang test/test_matrix.scd 2>&1 | tail -40`
Expected: all new assertions PASS. If the suite times out (known flakiness), the per-task harnesses (t1-t6) + balance checks are the accepted gate; note the timeout in the commit body.

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/test/test_matrix.scd
git commit -m "test(matrix): cover voice mods/poses + sources"
```

---

## Phase 2 — Python (iPhone mouth value)

### Task 8: Emit `/pose/mouth` from `pose_bridge.py`

**Files:**
- Modify: `data_only_viz/pose_bridge.py` (near the `/pose/action` / `/pose/kin` emit methods, ~331-351)

**Interfaces:**
- Produces: `/pose/mouth [pid, open]` sent to SC and to the VJ mirror, where `mouth_open` is already computed upstream.
- Consumes: the existing `mouth_open` scalar (verify its name/scope first).

- [ ] **Step 1: Confirm the value is available.** `grep -n "mouth" data_only_viz/*.py` — confirm `mouth_open` is computed and reachable where action/kin are sent (likely `action_head_pub.py`/`action_head.py`). If it lives only in the action-head feature dict, plumb it to the bridge call the same way `kin` is passed.

- [ ] **Step 2: Add the emit.** Following the pattern of the `/pose/kin` sender (`pose_bridge.py:341-351`), add a sibling method:

```python
    def send_mouth(self, pid: int, mouth_open: float) -> None:
        """Send mouth openness via /pose/mouth OSC route."""
        args = [int(pid), float(mouth_open)]
        self._client.send_message("/pose/mouth", args)
        self._vj("/pose/mouth", args)
```
Then call `send_mouth(pid, mouth_open)` at the same site that already calls the kin/action senders for that person.

- [ ] **Step 3: Header doc.** Add to the module's OSC route docstring (the block near `pose_bridge.py:10`): `/pose/mouth <pid> <open>   mouth openness 0..1`.

- [ ] **Step 4: Smoke.** Run the data_only pipeline (or its dry-run if one exists) and confirm the route appears:

Run: `cd data_only_viz && grep -n "/pose/mouth" pose_bridge.py`
Expected: the new sender + docstring line present. Live verification happens in Task 14.

- [ ] **Step 5: Commit.**

```bash
git add data_only_viz/pose_bridge.py
git commit -m "feat(pose): emit /pose/mouth from bridge"
```

---

## Phase 3 — Web control surface

### Task 9: matrix-state — sources, labels, events, per-voice state

**Files:**
- Modify: `web_realart/public/control/js/matrix-state.js`
- Test: `web_realart/test/matrix-state.test.mjs` (EXTEND the existing file — do not create a new one; match its style: `import assert from "node:assert"`, import from `../public/control/js/matrix-state.js`)

**Interfaces:**
- Produces: extended `MATRIX_MOD_SOURCES` (19 + `none`), `MOD_SOURCE_ORDER` (19, no none), `MOD_SOURCE_LABELS`, `MOD_TARGET_LABELS`, `POSE_EVENT_CHOICES`, `matVoiceMods`/`matVoicePoses` state arrays, `resetVoiceMaps()`, and save/load coverage. Pure parsers `parseVoiceMod(args)`, `parseVoicePose(args)`, `parseModValues(args)`.
- Consumes: `MATRIX_VOICES`.

- [ ] **Step 1: Write failing tests** — APPEND these cases to the existing `web_realart/test/matrix-state.test.mjs` (keep its `import assert from "node:assert"` style; add the new symbols to the existing import from `../public/control/js/matrix-state.js`). The new imports/cases:

```javascript
// add to the existing import from "../public/control/js/matrix-state.js":
//   MOD_SOURCE_ORDER, MOD_SOURCE_LABELS, MATRIX_MOD_SOURCES, POSE_EVENT_CHOICES,
//   parseVoiceMod, parseVoicePose, parseModValues

test("every ordered source has a FR label", () => {
  assert.equal(MOD_SOURCE_ORDER.length, 19);
  for (const s of MOD_SOURCE_ORDER) assert.ok(MOD_SOURCE_LABELS[s], `missing label ${s}`);
});

test("MATRIX_MOD_SOURCES starts with none and covers all sources", () => {
  assert.equal(MATRIX_MOD_SOURCES[0], "none");
  for (const s of MOD_SOURCE_ORDER) assert.ok(MATRIX_MOD_SOURCES.includes(s));
});

test("pose event choices include curated + custom", () => {
  const ids = POSE_EVENT_CHOICES.map((c) => c.id);
  assert.ok(ids.includes("danse"));
  assert.ok(ids.includes("fingerR2"));
  assert.ok(ids.includes("__custom__"));
});

test("parseVoiceMod round-trips a 2-binding list", () => {
  const { vi, list } = parseVoiceMod([5, 2, "bodyVitesse", "cutoff", 0.6, "rHandY", "pan", 0.4]);
  assert.equal(vi, 5);
  assert.deepEqual(list[0], { source: "bodyVitesse", target: "cutoff", depth: 0.6 });
  assert.equal(list[1].target, "pan");
});

test("parseVoicePose round-trips", () => {
  const { vi, list } = parseVoicePose([5, 2, "danse", "gate", "fingerR2", "trigger"]);
  assert.equal(vi, 5);
  assert.deepEqual(list[1], { poseId: "fingerR2", action: "trigger" });
});

test("parseModValues maps ordered values to a dict", () => {
  const vals = Array.from({ length: 19 }, (_, i) => i / 18);
  const m = parseModValues(vals);
  assert.equal(m.lHandY, 0);
  assert.equal(m.mouthOpen, 1);
});
```

- [ ] **Step 2: Run to verify FAIL.**

Run: `cd web_realart && node --test test/`
Expected: FAIL — new symbols not exported yet (existing tests still pass).

- [ ] **Step 3: Implement.** In `matrix-state.js`, replace the `MATRIX_MOD_SOURCES` line (`:31`) and add new exports after `MATRIX_MOD_TARGETS` (`:42`):

```javascript
export const MOD_SOURCE_ORDER = [
  "lHandY","rHandY","lHandX","rHandX","lOpen","rOpen","handSpeed","handDist",
  "bodyX","bodyY","depth","bodyVitesse","bodyAccel","bodySym","headX","headY",
  "limbSpan","danse","mouthOpen"
];
export const MATRIX_MOD_SOURCES = ["none", ...MOD_SOURCE_ORDER];

export const MOD_SOURCE_LABELS = {
  none:"—",
  lHandY:"Main G ↕", rHandY:"Main D ↕", lHandX:"Main G ↔", rHandX:"Main D ↔",
  lOpen:"Main G ouvert", rOpen:"Main D ouvert", handSpeed:"Vitesse mains", handDist:"Écart mains",
  bodyX:"Corps ↔", bodyY:"Corps ↕", depth:"Profondeur",
  bodyVitesse:"Vitesse corps", bodyAccel:"Accél. corps", bodySym:"Symétrie",
  headX:"Tête ↔", headY:"Tête ↕", limbSpan:"Envergure", danse:"Danse (proba)", mouthOpen:"Bouche"
};
export const MOD_TARGET_LABELS = { none:"—", amp:"volume", cutoff:"cutoff", pan:"pan", rev:"reverb" };

// Curated pose/event dropdown. id is the SC poseId symbol; __custom__ reveals a text input.
export const POSE_EVENT_CHOICES = [
  { id:"danse", label:"Danse" }, { id:"debout", label:"Debout" }, { id:"assise", label:"Assise" },
  { id:"fingerL1", label:"Frappe MG pouce" },  { id:"fingerL2", label:"Frappe MG index" },
  { id:"fingerL3", label:"Frappe MG majeur" }, { id:"fingerL4", label:"Frappe MG annul." },
  { id:"fingerL5", label:"Frappe MG auric." },
  { id:"fingerR1", label:"Frappe MD pouce" },  { id:"fingerR2", label:"Frappe MD index" },
  { id:"fingerR3", label:"Frappe MD majeur" }, { id:"fingerR4", label:"Frappe MD annul." },
  { id:"fingerR5", label:"Frappe MD auric." },
  { id:"pinchL1", label:"Pincement MG index" }, { id:"pinchL2", label:"Pincement MG majeur" },
  { id:"pinchL3", label:"Pincement MG annul." }, { id:"pinchL4", label:"Pincement MG auric." },
  { id:"pinchR1", label:"Pincement MD index" }, { id:"pinchR2", label:"Pincement MD majeur" },
  { id:"pinchR3", label:"Pincement MD annul." }, { id:"pinchR4", label:"Pincement MD auric." },
  { id:"__custom__", label:"Personnalisé…" }
];

// --- Per-voice mod/pose state (live bindings, separate from per-colour matColorDefs) ---
export let matVoiceMods  = Array.from({ length: MATRIX_VOICES.length }, () => []); // [{source,target,depth}]
export let matVoicePoses = Array.from({ length: MATRIX_VOICES.length }, () => []); // [{poseId,action}]
export function resetVoiceMaps() {
  matVoiceMods  = Array.from({ length: MATRIX_VOICES.length }, () => []);
  matVoicePoses = Array.from({ length: MATRIX_VOICES.length }, () => []);
}

export function parseVoiceMod(args) {
  const vi = Math.round(Number(args[0]));
  const n = Math.round(Number(args[1]));
  const list = [];
  for (let k = 0; k < n; k++) {
    const b = 2 + k * 3;
    list.push({ source: String(args[b]), target: String(args[b + 1]), depth: Number(args[b + 2]) });
  }
  return { vi, list };
}
export function parseVoicePose(args) {
  const vi = Math.round(Number(args[0]));
  const n = Math.round(Number(args[1]));
  const list = [];
  for (let k = 0; k < n; k++) {
    const b = 2 + k * 2;
    list.push({ poseId: String(args[b]), action: String(args[b + 1]) });
  }
  return { vi, list };
}
export function parseModValues(args) {
  const m = {};
  for (let i = 0; i < MOD_SOURCE_ORDER.length; i++) m[MOD_SOURCE_ORDER[i]] = Number(args[i]) || 0;
  return m;
}
```

- [ ] **Step 4: Persist voice maps in localStorage.** In `saveMatState()` (`:88-91`) add `vmod: matVoiceMods, vpose: matVoicePoses` to the JSON object; in `loadMatState()` (`:93-116`) after the `cdef` block, restore them when present (length === MATRIX_VOICES.length), else leave defaults. (These are display caches; SC remains authoritative via `/matrix/voicemod/get`.)

- [ ] **Step 5: Run to verify PASS.**

Run: `cd web_realart && node --test test/`
Expected: all tests PASS (existing + new).

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js/matrix-state.js web_realart/test/matrix-state.test.mjs
git commit -m "feat(web): mod source labels + per-voice state"
```

---

### Task 10: voice-editor — per-voice MOD list + POSE dropdown + OSC handlers

**Files:**
- Modify: `web_realart/public/control/js/voice-editor.js` — `renderModPoseTab` (327-396), `openFor` get-calls (98-100), add `/matrix/voicemod` + `/matrix/voicepose` handlers near the `/matrix/colordefs` handler (470).

**Interfaces:**
- Consumes: `matVoiceMods`, `matVoicePoses`, `MATRIX_MOD_SOURCES`, `MOD_SOURCE_LABELS`, `MOD_TARGET_LABELS`, `MATRIX_MOD_TARGETS`, `POSE_EVENT_CHOICES`, `parseVoiceMod`, `parseVoicePose`, `send`, `on`.
- Produces: a voice-level MOD/POSE editor independent of `cdColor`; sends `/matrix/voicemod vi n …` and `/matrix/voicepose vi n …`.

- [ ] **Step 1: Update imports.** Add to the matrix-state import in `voice-editor.js`: `matVoiceMods, matVoicePoses, MOD_SOURCE_LABELS, MOD_TARGET_LABELS, POSE_EVENT_CHOICES, parseVoiceMod, parseVoicePose`.

- [ ] **Step 2: Replace `renderModPoseTab`.** Replace `voice-editor.js:327-396` with a per-voice implementation:

```javascript
// Per-voice MOD (additive free list) + POSE (curated events). Independent of cdColor.
function sendVoiceMod(vi) {
  const list = matVoiceMods[vi] || [];
  send("/matrix/voicemod", vi, list.length,
    ...list.flatMap((b) => [b.source, b.target, +b.depth]));
  saveMatState();
}
function sendVoicePose(vi) {
  const list = matVoicePoses[vi] || [];
  send("/matrix/voicepose", vi, list.length,
    ...list.flatMap((b) => [b.poseId, b.action]));
  saveMatState();
}

function renderModPoseTab(vi) {
  if (!cdTabBodyEl) return;
  const voice = MATRIX_VOICES[vi];
  const targets = MATRIX_MOD_TARGETS[voice] || ["none", "amp"];

  // --- MOD: additive list ---
  const modWrap = document.createElement("div");
  modWrap.className = "cd-modlist";
  (matVoiceMods[vi] || []).forEach((b, i) => {
    const row = document.createElement("div");
    row.className = "cd-row";
    const src = document.createElement("select");
    MATRIX_MOD_SOURCES.forEach((s) => { const o = document.createElement("option");
      o.value = s; o.textContent = MOD_SOURCE_LABELS[s] || s; src.appendChild(o); });
    src.value = b.source;
    const tgt = document.createElement("select");
    targets.forEach((t) => { const o = document.createElement("option");
      o.value = t; o.textContent = MOD_TARGET_LABELS[t] || t; tgt.appendChild(o); });
    tgt.value = b.target;
    const dep = document.createElement("input");
    dep.type = "range"; dep.min = 0; dep.max = 1; dep.step = 0.01; dep.value = b.depth;
    const meter = document.createElement("span");
    meter.className = "cd-meter"; meter.dataset.src = b.source;
    const del = document.createElement("button");
    del.textContent = "x"; del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    const apply = () => { b.source = src.value; b.target = tgt.value; b.depth = +dep.value;
      meter.dataset.src = b.source; sendVoiceMod(vi); };
    src.addEventListener("change", apply);
    tgt.addEventListener("change", apply);
    dep.addEventListener("change", apply);
    del.addEventListener("click", () => { matVoiceMods[vi].splice(i, 1); sendVoiceMod(vi); renderPattern(vi); });
    [mk("src", src), mk("cible", tgt), mk("depth", dep), meter, del].forEach((e) => row.appendChild(e));
    modWrap.appendChild(row);
  });
  const addMod = document.createElement("button");
  addMod.textContent = "+ modulation";
  addMod.addEventListener("click", () => {
    (matVoiceMods[vi] ||= []).push({ source: MOD_SOURCE_ORDER_FIRST(), target: firstTarget(targets), depth: 0.5 });
    sendVoiceMod(vi); renderPattern(vi);
  });
  modWrap.appendChild(addMod);
  cdTabBodyEl.appendChild(modWrap);

  // --- POSE: curated events ---
  const poseWrap = document.createElement("div");
  poseWrap.className = "cd-poselist";
  (matVoicePoses[vi] || []).forEach((b, i) => {
    const row = document.createElement("div");
    row.className = "cd-row";
    const ev = document.createElement("select");
    POSE_EVENT_CHOICES.forEach((c) => { const o = document.createElement("option");
      o.value = c.id; o.textContent = c.label; ev.appendChild(o); });
    const custom = document.createElement("input");
    custom.placeholder = "poseId"; custom.className = "pose-id";
    const known = POSE_EVENT_CHOICES.some((c) => c.id === b.poseId);
    ev.value = known ? b.poseId : "__custom__";
    custom.value = known ? "" : b.poseId;
    custom.hidden = ev.value !== "__custom__";
    const act = document.createElement("select");
    ["trigger", "gate"].forEach((a) => { const o = document.createElement("option");
      o.value = a; o.textContent = a; act.appendChild(o); });
    act.value = b.action;
    const del = document.createElement("button");
    del.textContent = "x"; del.style.cssText = "width:auto;padding:2px 6px;font-size:10px;";
    const apply = () => {
      custom.hidden = ev.value !== "__custom__";
      b.poseId = ev.value === "__custom__" ? (custom.value || "none") : ev.value;
      b.action = act.value; sendVoicePose(vi);
    };
    ev.addEventListener("change", apply);
    custom.addEventListener("change", apply);
    act.addEventListener("change", apply);
    del.addEventListener("click", () => { matVoicePoses[vi].splice(i, 1); sendVoicePose(vi); renderPattern(vi); });
    [mk("event", ev), custom, mk("action", act), del].forEach((e) => row.appendChild(e));
    poseWrap.appendChild(row);
  });
  const addPose = document.createElement("button");
  addPose.textContent = "+ pose";
  addPose.addEventListener("click", () => {
    (matVoicePoses[vi] ||= []).push({ poseId: "danse", action: "trigger" });
    sendVoicePose(vi); renderPattern(vi);
  });
  poseWrap.appendChild(addPose);
  cdTabBodyEl.appendChild(poseWrap);
}

// helpers (place near renderModPoseTab)
function firstTarget(targets) { return targets.find((t) => t !== "none") || "amp"; }
function MOD_SOURCE_ORDER_FIRST() { return "bodyVitesse"; }
```
Add `MOD_SOURCE_ORDER` to the imports if you prefer `MOD_SOURCE_ORDER[0]` over the helper; either is fine — keep one.

- [ ] **Step 3: Update `openFor` get-calls.** Replace `voice-editor.js:98-100`:

```javascript
  send("/matrix/colordefs/get", vi);
  send("/matrix/steps/get", vi);
  send("/matrix/colordefs/get/ext", vi);
```
with:
```javascript
  send("/matrix/colordefs/get", vi);
  send("/matrix/steps/get", vi);
  send("/matrix/voicemod/get", vi);
  send("/matrix/voicepose/get", vi);
```

- [ ] **Step 4: Add inbound handlers.** After the `/matrix/colordefs` handler (`voice-editor.js:481`), add:

```javascript
on("/matrix/voicemod", (args) => {
  const { vi, list } = parseVoiceMod(args);
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matVoiceMods[vi] = list; saveMatState();
    if (isOpenFor(vi)) renderPattern(vi);
  }
});
on("/matrix/voicepose", (args) => {
  const { vi, list } = parseVoicePose(args);
  if (vi >= 0 && vi < MATRIX_VOICES.length) {
    matVoicePoses[vi] = list; saveMatState();
    if (isOpenFor(vi)) renderPattern(vi);
  }
});
```
Ensure `parseVoiceMod`, `parseVoicePose`, `on` are imported.

- [ ] **Step 5: Node syntax check.**

Run: `cd web_realart && node --check public/control/js/voice-editor.js && node --check public/control/js/matrix-state.js`
Expected: no output (valid).

- [ ] **Step 6: Commit.**

```bash
git add web_realart/public/control/js/voice-editor.js
git commit -m "feat(web): per-voice MOD list + pose dropdown"
```

---

### Task 11: Live meters from `/matrix/modvalues`

**Files:**
- Modify: `web_realart/public/control/js/voice-editor.js` (modvalues handler + meter update)
- Modify: `web_realart/public/control/css/control.css` (meter style)

**Interfaces:**
- Consumes: `parseModValues`, the `/matrix/modvalues` feedback route, `.cd-meter[data-src]` elements created in Task 10.
- Produces: a module-level `latestModValues` cache + `updateMeters()` that sets each meter's width/opacity from the live value.

- [ ] **Step 1: Add the handler + updater.** Near the other `on(...)` handlers in `voice-editor.js`, add:

```javascript
let latestModValues = {};
on("/matrix/modvalues", (args) => {
  latestModValues = parseModValues(args);
  updateMeters();
});
function updateMeters() {
  if (expandedVoice < 0 || activeTab !== "modpose") return;
  const meters = cdTabBodyEl ? cdTabBodyEl.querySelectorAll(".cd-meter") : [];
  meters.forEach((m) => {
    const v = latestModValues[m.dataset.src] || 0;
    m.style.setProperty("--v", v.toFixed(3));
    m.title = `${m.dataset.src}: ${v.toFixed(2)}`;
  });
}
```
Import `parseModValues` from matrix-state.

- [ ] **Step 2: Add meter CSS.** Append to `control.css`:

```css
.cd-meter { display:inline-block; width:42px; height:8px; border:1px solid #444;
  border-radius:3px; vertical-align:middle; margin:0 4px; position:relative; background:#1b1b1b; }
.cd-meter::after { content:""; position:absolute; left:0; top:0; bottom:0;
  width:calc(var(--v,0) * 100%); background:#1a8; border-radius:2px; }
```

- [ ] **Step 3: Node syntax check.**

Run: `cd web_realart && node --check public/control/js/voice-editor.js`
Expected: no output.

- [ ] **Step 4: Commit.**

```bash
git add web_realart/public/control/js/voice-editor.js web_realart/public/control/css/control.css
git commit -m "feat(web): live mod-source meters"
```

---

### Task 12: Web integration smoke (Playwright, against a running stack)

**Files:** none (verification only).

- [ ] **Step 1: Boot the web bridge** (GrosMac or macm1): `cd web_realart && node server.js` (or the project boot script). Confirm `[feedback] ecoute :9000` and `[ws]` lines.

- [ ] **Step 2: Open the control UI** at `http://localhost:4400/control/` (or `supra-m1.local:4400/control/`). Expand a melodic voice (e.g. `acid`), open the MOD/POSE tab.

- [ ] **Step 3: Verify MOD list.** Click `+ modulation`, set `Vitesse corps → cutoff`, depth ~0.6. Confirm a `/matrix/voicemod` frame is sent (browser console / server log) and the row persists on tab reswitch.

- [ ] **Step 4: Verify POSE dropdown.** Click `+ pose`, choose `Danse`, action `gate`; choose `Personnalisé…` and confirm the text field appears.

- [ ] **Step 5: Verify live meters** (only if SC engine is up and a person is tracked, else defer to Task 14): meters next to sources move as values arrive on `/matrix/modvalues`.

- [ ] **Step 6: No commit** (verification task). Record results in the task notes.

---

## Phase 4 — Presets

### Task 13: Preset generator — per-voice mods/poses + regenerate

**Files:**
- Modify: `sound_algo/data_only/matrix_presets/generate_presets.py`
- Modify (optional demo): `sound_algo/data_only/matrix_presets/patterns.py`

**Interfaces:**
- Produces: each generated `.matrix` carries `voiceMods:` and `voicePoses:` keys (empty by default, a few demonstrative mappings allowed). Format matches the SC payload from Task 6.

- [ ] **Step 1: Inspect the current emit.** `grep -n "colorDefs\|asCompileString\|def emit\|payload\|mod\|pose" sound_algo/data_only/matrix_presets/generate_presets.py | head -40` — find where the `.matrix` Event string is assembled.

- [ ] **Step 2: Emit the new keys.** Where the payload Event is written, add `voiceMods:` and `voicePoses:` entries — one list per voice, default `[]`. For a few demo presets (e.g. techno), set, for `acid`: `voiceMods: [(source: \bodyVitesse, target: \cutoff, depth: 0.6)]`. Keep the SC `asCompileString` syntax exactly (Event literals `(source: \x, target: \y, depth: 0.6)`).

- [ ] **Step 3: Regenerate.**

Run: `cd sound_algo/data_only/matrix_presets && uv run python generate_presets.py`
Expected: 28 `.matrix` files regenerated, no errors.

- [ ] **Step 4: Validate they load in SC.** Use the existing preset validator (`grep -rl "matLoad\|validate" scratchpad sound_algo/data_only` to find it) or a small harness that loads each preset and checks `~matVoiceMods`:

Run: `cd sound_algo/data_only && timeout 120 sclang scratchpad/validate_presets.scd 2>&1 | tail -20`
Expected: 28/28 load OK (the validator from the prior session covers grid/stream; extend it to assert `voiceMods`/`voicePoses` parse when present).

- [ ] **Step 5: Commit.**

```bash
git add sound_algo/data_only/matrix_presets
git commit -m "feat(presets): emit per-voice mods and poses"
```

---

## Phase 5 — Integration

### Task 14: macm1 live smoke + acceptance

**Files:** none (acceptance).

- [ ] **Step 1: Deploy to macm1.** Push (if the user asks) and on macm1 pull the branch; or rsync the working tree per the project's deploy path. Reboot the matrix engine (the prior session used a reboot script under `scratchpad/`).

- [ ] **Step 2: Start data_only_viz** with the iPhone source (USB or OSC). Confirm `/pose/kin`, `/pose/head`, `/pose/limb_span`, `/pose/mouth`, `/pose/action`, `/pose/finger`, `/pose/pinch` are flowing (e.g. `oscdump 57121` on a tap, or the VJ mirror).

- [ ] **Step 3: Open the control UI**, expand `acid`, add `Vitesse corps → cutoff` (depth 0.6). Move/dance in front of the iPhone: confirm (a) the live meter for `Vitesse corps` moves, (b) the acid cutoff audibly tracks body speed.

- [ ] **Step 4: Pose events.** Add a pose binding `Frappe MD index → trigger` on a voice; strike with the right index finger; confirm the voice re-triggers. Add `Danse → gate`; confirm dancing toggles the voice.

- [ ] **Step 5: Persistence.** `/matrix/save` a preset, reboot, `/matrix/load`; confirm voice mods/poses restored. Load a pre-existing (legacy per-colour) preset; confirm migration produced sane voice-level bindings (no errors, audio still correct).

- [ ] **Step 6: Record acceptance** in the task notes; report results to the user. Push on request.

---

## Self-review

**Spec coverage:**
- §1 per-voice model → Tasks 2, 3, 4, 6. ✓
- §2 new continuous sources → Task 1 (kin/head/limb/action), Task 8 (mouth). ✓
- §3 pose/event system → Task 4 (finger/pinch/action mapping + per-voice fire). ✓
- §4 display labels → Task 9. ✓
- §5 live viz → Tasks 5 (push) + 11 (meters). ✓
- §6 OSC routes → Tasks 3, 4, 5 (new), colormod/colorpose removed in 3/4. ✓
- §7 UI → Tasks 10, 11. ✓
- §8 persistence + migration → Task 6; presets → Task 13. ✓
- §9 testing → harnesses per SC task, Task 7 (suite), Task 9 (node), Tasks 12/14 (smoke). ✓

**Placeholder scan:** No TBD/TODO. SC test infra uncertainty is handled explicitly (balance check + harness + best-effort suite), not hand-waved. Boot-entry path (`00_load.scd`) flagged with a grep fallback in Task 1/Step 4.

**Type consistency:** `~matVoiceMods`/`~matVoicePoses` IdentityDictionaries keyed by voice symbol throughout (Tasks 2/3/4/6). Wire shapes consistent: `/matrix/voicemod [vi, n, src,tgt,depth …]` (set in Task 3, parsed in Task 9 `parseVoiceMod`, sent in Task 10 `sendVoiceMod`); `/matrix/voicepose [vi, n, pose,act …]` likewise. `/matrix/modvalues` = 19 values in `~matModOrder` == `MOD_SOURCE_ORDER` (Tasks 1/5/9/11). `~matModPairs` return contract (flattened `[tgt, Pfunc …]`) preserved for existing call sites (Task 2 note).
