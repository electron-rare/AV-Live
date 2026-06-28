# SC Refactor Lot A — Unified music helpers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one source of truth for scales + degree→note resolution
(`palette/note.scd`) and route the three duplicated resolvers (`~ccNote`,
`~lpNote`, `~fpResolve`) through it, without changing concert behavior.

**Architecture:** A new dependency-free `palette/note.scd` defines `~scales`
(named semitone-offset arrays), `~noteFor` and `~freqFor`. It loads in both
boot paths before any consumer. `~ccNote`/`~lpNote`/`~fpResolve` become thin
wrappers. The bespoke 8-note `~scaleXxx` arrays in `palette/scales.scd` (used
by the LIVE melody/harmony generators) are LEFT UNCHANGED — Lot A only unifies
the degree→note resolvers, not the LIVE melody arrays.

**Tech Stack:** SuperCollider (sclang), headless `.scd` tests via
`/Applications/SuperCollider.app/Contents/MacOS/sclang`.

## Global Constraints

- Branch: `refactor/sc-harmonize` (never `main`).
- `.scd` `.load`-compatible files: exactly ONE top-level `(...)` block; balance
  must be `P:0 B:0` (awk check below).
- SC env vars lowercase `~xxx`. Comments in French. No emojis.
- `sclang` is NOT on PATH — use
  `/Applications/SuperCollider.app/Contents/MacOS/sclang`.
- Headless tests boot no server (`s.serverRunning` false) and end with `0.exit`.
- Behavior parity: concert (`~ccNote`) and launchpad (`~lpNote`) note output
  must be identical to today. `~fpResolve` piano-mode notes MAY change (it
  moves from bespoke absolute arrays to canonical wrapped scales) — this is the
  intended harmonization and is called out in Task 5.
- Commits: subject ≤ 50 chars, no AI attribution, no `--no-verify`, no
  underscore in scope.
- Balance check command (must print `P:0 B:0`):
  `awk 'BEGIN{p=0;b=0} {for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="(")p++; if(c==")")p--; if(c=="[")b++; if(c=="]")b--}} END{print "P:"p" B:"b}' <file>`

---

### Task 1: `palette/note.scd` — source of truth + headless test

**Files:**
- Create: `sound_algo/palette/note.scd`
- Test: `sound_algo/tests/test_note.scd`

**Interfaces:**
- Produces:
  - `~scales` — IdentityDictionary: Symbol → Array of Int semitone offsets.
    Keys: `minor, dorian, phrygian, penta, minorPent, blues, japanese, hijaz,
    hirajoshi`.
  - `~noteFor.(degree:Int, scaleName:Symbol=\minor, root:Int=60, octave:Int=0)
    -> Int` (MIDI note, octave-carrying wrap, floored mod for negative degrees).
  - `~freqFor.(degree, scaleName, root, octave) -> Float` (`~noteFor(...).midicps`).

- [ ] **Step 1: Write the failing test**

Create `sound_algo/tests/test_note.scd`:

```supercollider
// Headless unit test for palette/note.scd.
// Run: sclang sound_algo/tests/test_note.scd
(
var ok = true, base;
base = thisProcess.nowExecutingPath.dirname.dirname ++ "/";
(base ++ "palette/note.scd").load;

// root note of minor pentatonic at root 60
if(~noteFor.(0, \minorPent, 60, 0) != 60) { ok = false; "FAIL: root".postln };
// degree 5 wraps one octave on a 5-note scale -> 72
if(~noteFor.(5, \minorPent, 60, 0) != 72) { ok = false; "FAIL: wrap".postln };
// minor degree 2 = +3 semitones -> 63
if(~noteFor.(2, \minor, 60, 0) != 63) { ok = false; "FAIL: minor".postln };
// concert parity: minor root 45 degree 2 -> 48 (old ~ccNote value)
if(~noteFor.(2, \minor, 45, 0) != 48) { ok = false; "FAIL: cc".postln };
// negative degree descends with floored mod: -1 on minor -> 55
if(~noteFor.(-1, \minor, 60, 0) != 55) { ok = false; "FAIL: neg".postln };
// freq matches midicps
if(~freqFor.(0, \minorPent, 60, 0) != 60.midicps) { ok = false; "FAIL: freq".postln };

if(ok) { "PASS test_note".postln } { "TESTS FAILED".postln };
0.exit;
)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd`
Expected: error / `~noteFor` is nil (file does not exist yet).

- [ ] **Step 3: Write the implementation**

Create `sound_algo/palette/note.scd`:

```supercollider
// =====================================================================
//  palette/note.scd  --  Source de verite : gammes + degree->note
//
//  Une seule definition de la resolution degree->note MIDI, consommee par
//  les resolveurs (~ccNote concert, ~lpNote launchpad, ~fpResolve air-piano).
//  Independant : aucun pre-requis, chargeable dans LES DEUX chemins de boot
//  (LIVE et data-only) AVANT tout consommateur.
//
//  NB : les arrays ~scaleXxx de palette/scales.scd (melodies LIVE, 8 notes
//  sur-mesure) sont distincts et NON touches ici.
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// Gammes en OFFSETS de demi-tons depuis la fondamentale.
~scales = IdentityDictionary[
    \minor     -> [0, 2, 3, 5, 7, 8, 10],
    \dorian    -> [0, 2, 3, 5, 7, 9, 10],
    \phrygian  -> [0, 1, 3, 5, 7, 8, 10],
    \penta     -> [0, 2, 4, 7, 9],          // pentatonique majeure (concert)
    \minorPent -> [0, 3, 5, 7, 10],
    \blues     -> [0, 3, 5, 6, 7, 10],
    \japanese  -> [0, 2, 5, 7, 9],
    \hijaz     -> [0, 1, 4, 5, 7, 8, 10],
    \hirajoshi -> [0, 2, 3, 7, 8]
];

// degree -> note MIDI, avec report d'octave (mod plancher gere les degres
// negatifs : -1 descend). root en MIDI, octave en octaves entieres.
~noteFor = { |degree, scaleName = \minor, root = 60, octave = 0|
    var sc = ~scales[scaleName] ? ~scales[\minor];
    var d  = degree.asInteger;
    (root + ((octave + (d div: sc.size)) * 12) + sc[d % sc.size]).asInteger;
};

~freqFor = { |degree, scaleName = \minor, root = 60, octave = 0|
    ~noteFor.(degree, scaleName, root, octave).midicps;
};

"[OK] palette/note.scd : ~scales, ~noteFor, ~freqFor".postln;
)
```

- [ ] **Step 4: Run test + balance check**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd`
Expected: `PASS test_note`

Run the balance check on `sound_algo/palette/note.scd` — expected `P:0 B:0`.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/palette/note.scd sound_algo/tests/test_note.scd
git commit -m "feat: unified note/scale source of truth"
```

---

### Task 2: Load `note.scd` in all boot paths (before consumers)

**Files:**
- Modify: `sound_algo/live/_load.scd:37` (before `palette/scales.scd`)
- Modify: `sound_algo/data_only/boot.scd:151` (before `control/data_feeds.scd`)
- Modify: `sound_algo/boot.data-only.scd:40` (before `control/data_feeds.scd`)

**Interfaces:**
- Consumes: `palette/note.scd` (Task 1).
- Produces: `~scales`/`~noteFor`/`~freqFor` available in both runtimes before
  any resolver loads.

- [ ] **Step 1: LIVE path — load before scales.scd**

In `sound_algo/live/_load.scd`, the block around line 37 currently is:

```supercollider
        (~base ++ "palette/scales.scd").load;
        (~base ++ "palette/melodies/index.scd").load;
```

Change to:

```supercollider
        (~base ++ "palette/note.scd").load;
        (~base ++ "palette/scales.scd").load;
        (~base ++ "palette/melodies/index.scd").load;
```

- [ ] **Step 2: data-only `data_only/boot.scd` — load before data_feeds**

In `sound_algo/data_only/boot.scd`, around line 151:

```supercollider
    (~repoRoot ++ "control/data_feeds.scd").load;
```

Insert BEFORE it:

```supercollider
    (~repoRoot ++ "palette/note.scd").load;
    (~repoRoot ++ "control/data_feeds.scd").load;
```

(Note: `data_only/boot.scd` uses `~repoRoot` for the `sound_algo/` root — the
same variable its `control/...` loads use. `palette/` is under that root.)

- [ ] **Step 3: data-only `boot.data-only.scd` — load before data_feeds**

In `sound_algo/boot.data-only.scd`, around line 40:

```supercollider
    (~base ++ "control/data_feeds.scd").load;
```

Insert BEFORE it:

```supercollider
    (~base ++ "palette/note.scd").load;
    (~base ++ "control/data_feeds.scd").load;
```

- [ ] **Step 4: Verify both boots still reach READY**

Run (LIVE headless boot smoke):
`/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/boot.scd`
Expected: boots, prints the live ready banner, no `palette/note.scd`-related
error. (Ctrl-C / it will keep running; confirm no error in the first output.)

Run (data-only headless boot smoke), from `sound_algo/data_only`:
`/Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd`
Expected: reaches `AV-Live DATA-ONLY PATCH READY`, log shows
`[OK] palette/note.scd` before `[OK] finger_piano`.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/live/_load.scd sound_algo/data_only/boot.scd sound_algo/boot.data-only.scd
git commit -m "feat: load note helpers in all boot paths"
```

---

### Task 3: Route `~ccNote` through `~noteFor` (concert parity)

**Files:**
- Modify: `sound_algo/data_only/scene_concert.scd:72-82`
- Test: `sound_algo/tests/test_note.scd` (extend)

**Interfaces:**
- Consumes: `~noteFor`, `~scales` (Task 1).
- Produces: `~ccNote.(degree, oct)` unchanged signature/output; `~ccScales`
  kept as an alias of `~scales` for any external reader.

- [ ] **Step 1: Add a parity assertion to the test**

Append to `sound_algo/tests/test_note.scd` BEFORE the `if(ok)` line:

```supercollider
// ~ccNote parity: wrapper must match the historical formula
~ccHarmony = (root: 45, scale: \minor, pad: \dark, phrase: 0, octave: 0);
~ccScales = ~scales;
~ccNote = { |degree, oct = 0|
    ~noteFor.(degree, ~ccHarmony[\scale] ? \minor,
        ~ccHarmony[\root] ? 45, (~ccHarmony[\octave] ? 0) + oct);
};
if(~ccNote.(2, 0) != 48) { ok = false; "FAIL: ccNote 48".postln };
if(~ccNote.(0, 1) != 57) { ok = false; "FAIL: ccNote oct".postln };
```

(`~ccNote.(0,1)` = root 45 + octave 1 → 45+12+0 = 57.)

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd`
Expected: still `PASS` actually — this step defines `~ccNote` inline in the
test, so it passes once the formula is right. If it FAILS, the wrapper formula
is wrong; fix it here before touching the real file.

- [ ] **Step 3: Replace the real `~ccNote`/`~ccScales` definition**

In `sound_algo/data_only/scene_concert.scd`, replace lines 72-82:

```supercollider
~ccScales = (
    minor:    [0,2,3,5,7,8,10], dorian: [0,2,3,5,7,9,10],
    phrygian: [0,1,3,5,7,8,10], penta:  [0,2,4,7,9]);
~ccHarmony = ~ccHarmony ? (root: 45, scale: \minor, pad: \dark, phrase: 0, octave: 0);
~ccNote = { |degree, oct=0|
    var sc = ~ccScales[~ccHarmony[\scale]] ? ~ccScales[\minor];
    var d  = degree.asInteger;
    (~ccHarmony[\root] ? 45)
        + (((~ccHarmony[\octave] ? 0) + oct + (d div: sc.size)) * 12)
        + sc[d % sc.size];
};
```

with:

```supercollider
// Gammes + resolution degree->note : delegue a palette/note.scd (~noteFor).
// ~ccScales reste un alias de ~scales pour les lecteurs externes.
~ccScales = ~scales ? ~ccScales;
~ccHarmony = ~ccHarmony ? (root: 45, scale: \minor, pad: \dark, phrase: 0, octave: 0);
~ccNote = { |degree, oct=0|
    ~noteFor.(degree, ~ccHarmony[\scale] ? \minor,
        ~ccHarmony[\root] ? 45, (~ccHarmony[\octave] ? 0) + oct);
};
```

- [ ] **Step 4: Verify**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd`
Expected: `PASS test_note`

Balance check on `sound_algo/data_only/scene_concert.scd` — expected `P:0 B:0`.

Run the data-only boot smoke (from `sound_algo/data_only`):
`/Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd`
Expected: reaches `PATCH READY`, no error.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/scene_concert.scd sound_algo/tests/test_note.scd
git commit -m "refactor: ccNote delegates to noteFor"
```

---

### Task 4: Route `~lpNote` through `~ccNote`/`~noteFor`

**Files:**
- Modify: `sound_algo/data_only/launchpad.scd:136`

**Interfaces:**
- Consumes: `~ccNote` (Task 3), `~noteFor` (Task 1).
- Produces: `~lpNote.(deg, oct)` — unchanged primary path (delegates to
  `~ccNote` when present). Fallback (concert absent) now uses `~noteFor` with
  root 45 minor instead of the old degenerate `[deg%7]` table — a near-dead
  path, improved to octave-correct.

- [ ] **Step 1: Replace `~lpNote`**

In `sound_algo/data_only/launchpad.scd` line 136:

```supercollider
~lpNote = { |deg, oct=0| (~ccNote.notNil).if({ ~ccNote.(deg, oct) }, { 45 + (oct*12) + ([0,2,3,5,7,8,10][deg % 7]) }) };
```

with:

```supercollider
~lpNote = { |deg, oct=0|
    ~ccNote.notNil.if({ ~ccNote.(deg, oct) }, { ~noteFor.(deg, \minor, 45, oct) })
};
```

- [ ] **Step 2: Verify balance + data-only boot smoke**

Balance check on `sound_algo/data_only/launchpad.scd` — expected `P:0 B:0`.

Run the data-only boot smoke (from `sound_algo/data_only`):
`/Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd`
Expected: reaches `PATCH READY`; log still shows
`[data-only/launchpad] ... ready`, no error.

- [ ] **Step 3: Commit**

```bash
git add sound_algo/data_only/launchpad.scd
git commit -m "refactor: lpNote delegates to noteFor"
```

---

### Task 5: Route `~fpResolve` through `~noteFor` (drop embedded scales)

**Files:**
- Modify: `sound_algo/control/finger_piano.scd` (`~fpScaleArr`, `~fpScales`,
  `~fpResolve`, `~fpScale_`)
- Modify: `sound_algo/tests/test_finger_piano.scd` (note assertions)

**Interfaces:**
- Consumes: `~noteFor`, `~scales` (Task 1).
- Produces: `~fpScaleName` (Symbol, default `\minorPent`) replaces
  `~fpScaleArr`/`~fpScales`. `~fpResolve.(hand, finger, strikeSpeed, z, tipx,
  tipy)` keeps its Event output (`\note \freq \amp \inst`) but resolves notes
  via `~noteFor`. `~fpScale_.(name)` sets `~fpScaleName`.
- **Behavior note (intended):** piano-mode finger notes now follow the
  canonical wrapped scale (e.g. minor pentatonic 5-note + octave carry) instead
  of the previous bespoke 8-note absolute array. Clips mode (the concert path)
  is unaffected (it uses `~lpArm`, not `~fpResolve`).

- [ ] **Step 1: Update the finger_piano test note assertions**

In `sound_algo/tests/test_finger_piano.scd`, the block that loads scales +
finger_piano and asserts notes. Replace the scale-array assertions (which
referenced `~fpScaleArr.wrapAt`) with `~noteFor`-based expectations. Find:

```supercollider
// default scale is minor pentatonic; left thumb (hand 0, finger 0) -> degree 0
ev = ~fpResolve.(0, 0, 1.0, 0.0, 0.5, 0.5);
("note L thumb = " ++ ev[\note]).postln;
if(ev[\note] != ~fpScaleArr.wrapAt(0)) {
    ok = false; "FAIL: L thumb note wrong".postln;
};

// right hand defaults one octave up (~fpHandOct[1] = 12)
ev = ~fpResolve.(1, 0, 1.0, 0.0, 0.5, 0.5);
if(ev[\note] != (~fpScaleArr.wrapAt(0) + 12)) {
    ok = false; "FAIL: R thumb octave wrong".postln;
};
```

replace with:

```supercollider
// note.scd must be loaded for ~noteFor
(base ++ "palette/note.scd").load;
// default scale minorPent; L thumb (hand 0, finger 0) -> degree 0 -> root 60
ev = ~fpResolve.(0, 0, 1.0, 0.0, 0.5, 0.5);
("note L thumb = " ++ ev[\note]).postln;
if(ev[\note] != ~noteFor.(0, \minorPent, 60, 0)) {
    ok = false; "FAIL: L thumb note wrong".postln;
};
// right hand defaults one octave up (~fpHandOct[1] = 12)
ev = ~fpResolve.(1, 0, 1.0, 0.0, 0.5, 0.5);
if(ev[\note] != (~noteFor.(0, \minorPent, 60, 0) + 12)) {
    ok = false; "FAIL: R thumb octave wrong".postln;
};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_finger_piano.scd`
Expected: FAIL (`~fpResolve` still uses `~fpScaleArr`, and/or `~noteFor` value
differs from the old wrapAt array).

- [ ] **Step 3: Refactor finger_piano scale handling + `~fpResolve`**

In `sound_algo/control/finger_piano.scd`:

(3a) Replace the scale config block. Find:

```supercollider
~fpInst      = ~fpInst      ? \live;      // \live = suit ~melodyInst
// Fallback embarque : en mode data-only, palette/scales.scd n'est pas
// charge, donc ~scaleMinorPent est nil. On garantit une gamme valide.
~fpScaleArr  = ~fpScaleArr  ? (~scaleMinorPent ? [60, 63, 65, 67, 70, 72, 75, 79]);
~fpMap       = ~fpMap       ? [[0,1,2,3,4], [0,1,2,3,4]];  // [L, R] degres
```

replace with:

```supercollider
~fpInst      = ~fpInst      ? \live;      // \live = suit ~melodyInst
~fpScaleName = ~fpScaleName ? \minorPent; // nom de gamme dans ~scales
~fpRoot      = ~fpRoot      ? 60;         // fondamentale MIDI
~fpMap       = ~fpMap       ? [[0,1,2,3,4], [0,1,2,3,4]];  // [L, R] degres
```

(3b) Remove the `~fpScales` named-scale dict block. Find and DELETE:

```supercollider
// Gammes nommees accessibles via ~fpScale_
// Gammes nommees (fallback embarque si palette/scales.scd absent).
~fpScales = (
    minorPent: ~scaleMinorPent ? [60, 63, 65, 67, 70, 72, 75, 79],
    minor:     ~scaleMinor     ? [60, 62, 63, 65, 67, 68, 70, 72],
    dorian:    ~scaleDorian    ? [60, 62, 63, 65, 67, 69, 70, 72],
    phrygian:  ~scalePhrygian  ? [60, 61, 63, 65, 67, 68, 70, 72],
    blues:     ~scaleBlues     ? [60, 63, 65, 66, 67, 70, 72, 75],
    japanese:  ~scaleJapanese  ? [60, 62, 65, 67, 69, 72, 74, 77],
    hijaz:     ~scaleHijaz     ? [60, 61, 64, 65, 67, 68, 70, 72],
    hirajoshi: ~scaleHirajoshi ? [60, 62, 63, 67, 68, 72, 74, 75]
);
```

(3c) Replace the note line inside `~fpResolve`. Find:

```supercollider
    note = ((~fpScaleArr ? [60, 63, 65, 67, 70, 72, 75, 79]).wrapAt(deg)
        + transpose).asInteger;
```

replace with (transpose is a semitone offset in multiples of 12 → octaves):

```supercollider
    note = ~noteFor.(deg, ~fpScaleName, ~fpRoot, transpose div: 12);
```

(3d) Replace `~fpScale_`. Find:

```supercollider
~fpScale_    = { |name|
    ~fpScaleArr = ~fpScales[name] ? ~fpScaleArr;
    ("[fp] scale = " ++ name).postln;
};
```

replace with:

```supercollider
~fpScale_    = { |name|
    (~scales[name].notNil).if({ ~fpScaleName = name });
    ("[fp] scale = " ++ ~fpScaleName).postln;
};
```

- [ ] **Step 4: Run test + balance + boot smoke**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_finger_piano.scd`
Expected: `PASS test_finger_piano`

Balance check on `sound_algo/control/finger_piano.scd` — expected `P:0 B:0`.

Data-only boot smoke (from `sound_algo/data_only`):
`/Applications/SuperCollider.app/Contents/MacOS/sclang boot.scd`
Expected: `PATCH READY`, `[OK] finger_piano` present, no error.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/control/finger_piano.scd sound_algo/tests/test_finger_piano.scd
git commit -m "refactor: fpResolve delegates to noteFor"
```

---

### Task 6: Full verification gate (no new code)

**Files:** none (verification only).

- [ ] **Step 1: E2E suite green**

Run: `cd sound_algo/tests && bash run_all.sh`
Expected: all checks pass (syntax / load / reload-guard / SynthDef-compile).
If `run_all.sh` needs a TTY or a running server and cannot complete headless,
record exactly which checks ran and their results in the task report.

- [ ] **Step 2: All headless unit tests green**

Run:
```bash
/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_note.scd
/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/tests/test_finger_piano.scd
```
Expected: `PASS test_note` and `PASS test_finger_piano`.

- [ ] **Step 3: Balance check every Lot A `.scd`**

Run the balance awk on: `palette/note.scd`, `data_only/scene_concert.scd`,
`data_only/launchpad.scd`, `control/finger_piano.scd`. All `P:0 B:0`.

- [ ] **Step 4: Live smoke (manual, with the running rig)**

With the data-only stack running, confirm via OSC that concert harmony and the
air-piano still produce notes (no `nil`/`wrapAt`/`noteFor` errors in
`/tmp/sc_boot.log`). If a regression appears, it is a failed gate — fix before
closing the lot.

## Self-Review

**Spec coverage:** `palette/note.scd` (`~scales`/`~noteFor`/`~freqFor`) → Task 1.
Loaded in both boots before consumers → Task 2. `~ccNote` wrapper → Task 3.
`~lpNote` wrapper → Task 4. `~fpResolve` via `~noteFor`, embedded fallback
removed (root cause of the `154db32` fix) → Task 5. Parity tests + E2E + boot
smoke → Tasks 1,3,5,6. `palette/scales.scd` LIVE arrays intentionally untouched
(documented in Architecture). OK.

**Placeholder scan:** every code step has full code; no TBD. OK.

**Type consistency:** `~noteFor(degree, scaleName, root, octave) -> Int` used
identically in Tasks 1/3/4/5. `~fpScaleName`/`~fpRoot` introduced in Task 5 and
used only there. `~ccScales` aliased to `~scales` (Task 3). `transpose div: 12`
converts the existing semitone `transpose` (already a multiple of 12) to the
octave arg. OK.
