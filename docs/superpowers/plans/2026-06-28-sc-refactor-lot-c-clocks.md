# SC Refactor Lot C — Clock unification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Collapse the 4 SC clocks into one (`TempoClock.default`) and route all
runtime tempo changes through a single `~setTempo.(bpm)`.

**Architecture:** Secondary clock slots become aliases of `TempoClock.default`
(no call-site rewrites). A single `~setTempo` (in both engines) sets `~bpm` +
`TempoClock.default.tempo`. Runtime controllers call `~setTempo`. Each scene
sets its base tempo on entry. Tape-stop ramps, track-init, dev presets are
left as direct writes (documented exceptions).

**Tech Stack:** SuperCollider (sclang), headless `.scd` tests.

## Global Constraints

- Branch: `refactor/sc-lot-c-clocks` (never `main`).
- `sclang` full path: `/Applications/SuperCollider.app/Contents/MacOS/sclang`.
- `.scd` modular files: ONE top-level `(...)` block; balance `P:0 B:0`:
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' <file>`
- SC env vars lowercase `~xxx`. Comments in French. No emojis.
- Headless tests boot no server, end `0.exit`.
- Do NOT reboot/kill the running live concert; verify via headless test +
  balance + grep. Full boot smoke + live smoke happen at merge.
- Behavior parity for sound; tempo coordination is the intended change.
- Commits: subject ≤ 50 chars, no AI attribution, no `--no-verify`, no
  underscore in scope.

---

### Task 1: `~setTempo` in both engines + headless test

**Files:**
- Modify: `sound_algo/engine.scd` (after `~bpm = 132;`, line ~106)
- Modify: `sound_algo/data_only/engine.scd` (near top of its setup block)
- Test: `sound_algo/tests/test_tempo.scd`

**Interfaces:**
- Produces: `~setTempo.(bpm)` → sets `~bpm` (clipped 20..300) and
  `TempoClock.default.tempo = ~bpm/60`; returns the clip-applied `~bpm`.

- [ ] **Step 1: Write the failing test** — create `sound_algo/tests/test_tempo.scd`:

```supercollider
// Headless test for ~setTempo. Run: sclang sound_algo/tests/test_tempo.scd
(
var ok = true;
// minimal: ~setTempo only needs TempoClock.default (always exists)
(thisProcess.nowExecutingPath.dirname.dirname ++ "/engine.scd").load;
~setTempo.(140);
if(~bpm != 140) { ok = false; "FAIL: bpm".postln };
if(TempoClock.default.tempo.round(0.0001) != (140/60).round(0.0001)) {
    ok = false; "FAIL: clock".postln };
~setTempo.(9999);                       // clip high
if(~bpm != 300) { ok = false; "FAIL: clip hi".postln };
~setTempo.(1);                          // clip low
if(~bpm != 20) { ok = false; "FAIL: clip lo".postln };
if(ok) { "PASS test_tempo".postln } { "TESTS FAILED".postln };
0.exit;
)
```

- [ ] **Step 2: Run — expect FAIL** (`~setTempo` nil):
`/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_tempo.scd`

- [ ] **Step 3: Add `~setTempo` to `sound_algo/engine.scd`** immediately after
`~bpm = 132;`:

```supercollider
    // Setter de tempo unique et coordonne : une seule horloge
    // (TempoClock.default). Tous les controleurs runtime passent par ici.
    ~setTempo = { |bpm|
        ~bpm = bpm.clip(20, 300);
        TempoClock.default.tempo = ~bpm / 60;
        ("[tempo] " ++ ~bpm ++ " BPM").postln;
        ~bpm;
    };
```

- [ ] **Step 4: Add the same `~setTempo` to `sound_algo/data_only/engine.scd`**
(so the data-only universe has it too). Place it inside that file's top-level
setup block, near where its engine state is initialised. Use the identical
definition as Step 3.

- [ ] **Step 5: Run test + balance** — expect `PASS test_tempo`; balance
`engine.scd` and `data_only/engine.scd` → `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/engine.scd sound_algo/data_only/engine.scd sound_algo/tests/test_tempo.scd
git commit -m "feat: single coordinated setTempo"
```

---

### Task 2: Alias the 3 secondary clocks to `TempoClock.default`

**Files:**
- Modify: `sound_algo/data_only/launchpad.scd:94`
- Modify: `sound_algo/data_only/scene_concert.scd:140`
- Modify: `sound_algo/data_only/scene_pose_play.scd:89`

**Interfaces:**
- Consumes: nothing. Produces: `~lp[\clock]`, `~concert[\clock]`,
  `~bpEngine[\clock]` all `=== TempoClock.default`. All existing
  `.play(~xxx[\clock])` / `~xxx[\clock].tempo=` now operate on the one clock.

- [ ] **Step 1: launchpad** — replace line 94:

```supercollider
~lp[\clock] = ~lp[\clock] ? TempoClock(126/60).permanent_(true);
```
with:
```supercollider
~lp[\clock] = TempoClock.default;   // horloge unique (Lot C)
```

- [ ] **Step 2: scene_concert** — replace line 140:

```supercollider
~concert[\clock] = TempoClock(126/60).permanent_(true);
```
with:
```supercollider
~concert[\clock] = TempoClock.default;   // horloge unique (Lot C)
```

- [ ] **Step 3: scene_pose_play** — replace line 89:

```supercollider
~bpEngine[\clock] = TempoClock(100/60).permanent_(true);
```
with:
```supercollider
~bpEngine[\clock] = TempoClock.default;   // horloge unique (Lot C)
```

- [ ] **Step 4: Verify** — balance each of the 3 files → `P:0 B:0`; grep each to
confirm the alias line. (No headless test: these are assignments verified at
the lot gate's boot smoke.)

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/launchpad.scd sound_algo/data_only/scene_concert.scd sound_algo/data_only/scene_pose_play.scd
git commit -m "refactor: alias secondary clocks to default"
```

---

### Task 3: Route LIVE-side tempo writers through `~setTempo`

**Files:**
- Modify: `sound_algo/web_bridge.scd:176-177`
- Modify: `sound_algo/pd/bridge.scd:51` and `:102`
- Modify: `sound_algo/live/midi_init.scd:94`
- Modify: `sound_algo/live/scenes.scd:61`

**Interfaces:** Consumes `~setTempo` (Task 1).

- [ ] **Step 1: web_bridge** — replace:
```supercollider
    ~bpm = msg[1];
    TempoClock.default.tempo = ~bpm / 60;
```
with:
```supercollider
    ~setTempo.(msg[1]);
```

- [ ] **Step 2: pd/bridge line 51** — replace:
```supercollider
    TempoClock.default.tempo = (~bpm ? 128) / 60;
```
with:
```supercollider
    ~setTempo.(~bpm ? 128);
```

- [ ] **Step 3: pd/bridge line 102** — in the `\pdTweakBpm` OSCdef, replace
`~bpm = msg[1].asFloat; TempoClock.default.tempo = ~bpm/60` with
`~setTempo.(msg[1].asFloat)`. The line becomes:
```supercollider
~pd[\defs].add(OSCdef(\pdTweakBpm,    { |msg| ~setTempo.(msg[1].asFloat) }, '/tweak/bpm'));
```

- [ ] **Step 4: midi_init line 94** — replace the CC 36 handler body
`TempoClock.default.tempo = val.linlin(0,127, 60,200) / 60` with
`~setTempo.(val.linlin(0,127, 60,200))`:
```supercollider
    ~midiFuncs.add(MIDIFunc.cc({ |val| ~setTempo.(val.linlin(0,127, 60,200)) }, 36));
```

- [ ] **Step 5: scenes.scd line 61** — replace:
```supercollider
                TempoClock.default.tempo = v / 60;
```
with:
```supercollider
                ~setTempo.(v);
```

- [ ] **Step 6: Verify** — balance the 4 files → `P:0 B:0`; grep each site to
confirm `~setTempo`. Run `sclang sound_algo/tests/test_tempo.scd` → still `PASS`.

- [ ] **Step 7: Commit**

```bash
git add sound_algo/web_bridge.scd sound_algo/pd/bridge.scd sound_algo/live/midi_init.scd sound_algo/live/scenes.scd
git commit -m "refactor: route live tempo writers to setTempo"
```

---

### Task 4: Route data-only tempo writers through `~setTempo`

**Files:**
- Modify: `sound_algo/control/web_bridge.scd` (`~applyTempo`, ~line 96)
- Modify: `sound_algo/control/vdmx_send.scd:93`
- Modify: `sound_algo/data_only/launchpad.scd:333-337` (`/launch/tempo`)
- Modify: `sound_algo/control/finger_piano.scd:171` (`\bpm` cmd)

**Interfaces:** Consumes `~setTempo` (Task 1). After Task 2 the clocks alias
default, so a single `~setTempo` covers launchpad + concert.

- [ ] **Step 1: control/web_bridge `~applyTempo`** — replace:
```supercollider
~applyTempo = { |bpm|
    ~webState[\tempo] = bpm;
    if(TempoClock.default.notNil) {
        TempoClock.default.tempo_(bpm / 60.0);
    };
```
with (keep the `~webState` write, delegate the tempo to `~setTempo`):
```supercollider
~applyTempo = { |bpm|
    ~webState[\tempo] = bpm;
    ~setTempo.(bpm);
```
(Do not remove the closing `};` of the function — only the inner `if` block and
the `~webState` line change as shown; leave the rest of `~applyTempo` intact.)

- [ ] **Step 2: vdmx_send line 93** — replace:
```supercollider
    OSCdef(\vdmxCtlBpm,   { |m| TempoClock.default.tempo_(m[1] / 60) },        "/ctl/bpm");
```
with:
```supercollider
    OSCdef(\vdmxCtlBpm,   { |m| ~setTempo.(m[1]) },        "/ctl/bpm");
```

- [ ] **Step 3: launchpad `/launch/tempo` lines 333-337** — replace the body:
```supercollider
OSCdef(\lpTempo, { |msg|
    var t = ((msg[1] ? 126).clip(60, 200)) / 60;
    ~lp[\clock].tempo = t;
    ~concert !? { ~concert[\clock] !? { |c| c.tempo = t } };
}, '/launch/tempo');
```
with (one clock now → single setter):
```supercollider
OSCdef(\lpTempo, { |msg|
    ~setTempo.((msg[1] ? 126).clip(60, 200));
}, '/launch/tempo');
```

- [ ] **Step 4: finger_piano `\bpm` line 171** — replace:
```supercollider
    { cmd == \bpm }    { ~lp !? { ~lp[\clock].tempo = msg[2] / 60 };
                         ("[fp] bpm = " ++ msg[2]).postln; }
```
with:
```supercollider
    { cmd == \bpm }    { ~setTempo.(msg[2]);
                         ("[fp] bpm = " ++ msg[2]).postln; }
```

- [ ] **Step 5: Verify** — balance the 4 files → `P:0 B:0`; grep each site for
`~setTempo`; run `sclang sound_algo/tests/test_finger_piano.scd` → `PASS`
(confirms finger_piano still loads after the edit).

- [ ] **Step 6: Commit**

```bash
git add sound_algo/control/web_bridge.scd sound_algo/control/vdmx_send.scd sound_algo/data_only/launchpad.scd sound_algo/control/finger_piano.scd
git commit -m "refactor: route data-only tempo to setTempo"
```

---

### Task 5: Per-scene base tempo + morceaux build-ups

**Files:**
- Modify: `sound_algo/data_only/scene_concert.scd` (concert start → base 126)
- Modify: `sound_algo/data_only/scene_pose_play.scd` (body-play start → base 100)
- Modify: `sound_algo/data_only/morceaux/03_acid_line.scd`,
  `12_trance.scd`, `13_psytrance.scd`, `14_punkcore.scd`
  (`~concert[\clock].tempo = X/60` → `~setTempo.(X)`)

**Interfaces:** Consumes `~setTempo` (Task 1). Since clocks now alias default,
the per-scene base must be set explicitly (the old 126/100 init is gone).

- [ ] **Step 1: concert base tempo** — in `scene_concert.scd`, find where the
concert starts its Routine (the `~concert[\start]` / play path) and add
`~setTempo.(126);` at the start of that path (after the clock alias, before the
Routine plays). Show the exact insertion in the report. If the concert has no
single start hook, add `~setTempo.(126);` right after the `~concert[\clock]`
alias line so the base is set at load.

- [ ] **Step 2: body-play base tempo** — in `scene_pose_play.scd`, at the
body-play scene entry (where `~bpEngine` Routine starts), add `~setTempo.(100);`
so body-play runs at 100 BPM as before. Show the insertion in the report.

- [ ] **Step 3: morceaux build-ups** — in each of the 4 morceaux, replace the
two tempo writes. Pattern (acid_line shown; apply the analogous change in each
file with that file's own BPM values):
```supercollider
~concert[\clock] !? { |c| c.tempo = speed.linlin(0, 0.6, 124, 140).clip(124, 140) / 60 };
```
becomes:
```supercollider
~setTempo.(speed.linlin(0, 0.6, 124, 140).clip(124, 140));
```
and the `stop`/reset line `~concert[\clock] !? { |c| c.tempo = 126 / 60 }`
becomes `~setTempo.(126);`. For `12_trance.scd` (138→126), `13_psytrance.scd`
(145→126), `14_punkcore.scd` (156→126): replace `~concert[\clock] ... c.tempo =
N/60` with `~setTempo.(N)` keeping each file's N.

- [ ] **Step 4: Verify** — balance all edited files → `P:0 B:0`; grep the
morceaux to confirm no remaining `~concert[\clock].tempo` writes; grep
concert/body-play for the base `~setTempo` calls.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/scene_concert.scd sound_algo/data_only/scene_pose_play.scd sound_algo/data_only/morceaux/03_acid_line.scd sound_algo/data_only/morceaux/12_trance.scd sound_algo/data_only/morceaux/13_psytrance.scd sound_algo/data_only/morceaux/14_punkcore.scd
git commit -m "refactor: scenes and morceaux use setTempo"
```

---

### Task 6: Verification gate (no new code)

- [ ] **Step 1: headless tests** — run, expect PASS:
```bash
/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_tempo.scd
/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd
/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_finger_piano.scd
```

- [ ] **Step 2: no orphan clocks / writers** — grep must return ONLY the
intended exceptions (tape-stop ramps in `live/live.scd`, track-init in
`tracks/`, dev preset blocks):
```bash
grep -rn "TempoClock(" sound_algo --include=*.scd          # expect: none in launchpad/concert/pose_play
grep -rn "\[\\\\clock\]\.tempo" sound_algo --include=*.scd  # expect: none (all via setTempo)
```
Record any remaining hits and confirm each is an intended exception.

- [ ] **Step 3: balance** — every edited modular `.scd` → `P:0 B:0`.

- [ ] **Step 4: live smoke (at merge, with the rig)** — change tempo from one
controller (e.g. `/control/fp bpm 140`) and confirm launchpad + concert + live
patterns all follow one tempo; check `/tmp/sc_boot.log` for no error.

## Self-Review

**Spec coverage:** `~setTempo` both engines + test → Task 1. Alias 3 clocks →
Task 2. Route live writers → Task 3. Route data-only writers → Task 4.
Per-scene base + morceaux → Task 5. Exceptions (tape-stop, track-init, presets)
left untouched and grep-checked → Task 6 step 2. Verification → Task 6. OK.

**Placeholder scan:** every reroute has exact before/after from the audit. Task
5 steps 1-2 instruct "find the start hook" — acceptable because the insertion is
described precisely (add `~setTempo.(126/100)` at scene entry) and the
implementer reports the exact location. OK.

**Type consistency:** `~setTempo.(bpm)` signature identical across Tasks 1/3/4/5.
Clock aliases (`= TempoClock.default`) identical across Task 2. OK.
