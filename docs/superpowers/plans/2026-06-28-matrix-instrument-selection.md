# Matrix Instrument Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each matrix voice play an alternative SynthDef chosen from a curated per-voice menu, switch all voices at once via fixed kits, reset a cell with right-click, and persist instrument choices inside the named `.matrix` presets.

**Architecture:** A `~matInstruments[vi]` indirection (nil = voice default) injects an `\instrument` override into the existing `~matVariation` Pchain overlay (the same overlay that carries `\matGlow`). Kits are fixed name→map tables in SC. The `.matrix` file format is extended from a bare grid Array to an Event `(grid:, instruments:)`, backward-compatible with grid-only files. Web adds a sticky-left per-row `<select>` + kit buttons + a right-click-clear handler.

**Tech Stack:** SuperCollider (sclang), vanilla browser JS (classic `control.js`), CSS sticky positioning, Node `node:test`.

## Coordination precondition (read before implementing)

This plan modifies the parallel "matrix save/load presets" feature's core
functions (`~matSave`, `~matLoadFile`, `~matGridValid`, `~matGridPush`, the
`/matrix/grid` web handler). **Do not start implementation until that feature is
frozen/merged** (no in-flight edits to `sound_algo/data_only/matrix.scd` persistence
helpers or `web_realart/public/control/control.js` matrix handlers), or conflicts
are guaranteed. Branch from the current `feat/matrix-instruments` HEAD.

## Global Constraints

- SC env vars lowercase `~xxx`; comments English; no emojis. — sound_algo/CLAUDE.md
- Every `.scd` edit keeps `awk` paren/bracket balance `P:0 B:0`. — sound_algo/CLAUDE.md
- No audio-graph / SynthDef / `Out.ar` changes. — design spec
- No `web_realart/server.js` change (`/matrix/*` already relayed). — design spec
- `.matrix` format change MUST stay backward-compatible: existing grid-only files
  (the 14 shipped `matrix_presets/*.matrix`, bare Array compile strings) still load,
  defaulting instruments to nil. — design spec + matrix.scd:240,250
- Curated invariant: every instrument settable for a voice (menu option or kit
  entry) is in that voice's `~matInstChoices` list; invalid → ignored. — design spec
- `~matVariation`'s `\matGlow` stays the FIRST overlay key. — glow feature
- Commit subject <= 50 chars, no underscore in scope, no AI attribution. — CLAUDE.md
- `web_realart` is `"type":"module"`; tests use `node:test`. — package.json

---

### Task 1: SC instrument state, choices, kits, OSC, overlay injection

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (add state after the init block ~L25; add `~matInstChoices`/`~matKits`/`~matApplyInstrument`/`~matApplyKit` near the other helpers; extend `~matVariation` overlay ~L66-79; add 2 OSCdefs after the existing `~mat_*` block ~L309)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matInstruments` (Array of 16 nil-or-Symbol), `~matInstChoices`
  (IdentityDictionary voiceName→[Symbol]), `~matKits` (IdentityDictionary
  kitName→(voiceName→Symbol)), `~matApplyInstrument.(vi, instOrNil)`,
  `~matApplyKit.(name)`.
- Consumes: `~matVoices`, `~matVariation`, `~matApplyBar`, `~toscSend`, `~lp`.

- [ ] **Step 1: Write the failing tests**

Insert into `sound_algo/data_only/test/test_matrix.scd` before the final
`pass.if(` (currently ~L144). Reuse the existing capturing-stub idiom:

```supercollider
// --- Instrument selection (Task 1) ---
pass = pass and: { ~matInstruments.notNil and: { ~matInstruments.size == 16 } };
pass = pass and: { ~matInstruments.every({ |x| x.isNil }) };          // default nil
pass = pass and: { ~matInstChoices.notNil and: { ~matKits.notNil } };

// apply a valid instrument echoes /matrix/instrument with vi + symbol string
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
try { ~matApplyInstrument.(7, \do_plane) } { |e| pass = false;
    ("EXCEPTION matApplyInstrument: " ++ e.class.name).postln };
pass = pass and: { ~matInstruments[7] == \do_plane };
pass = pass and: { ~trigLog.notNil and: { ~trigLog[0] == "/matrix/instrument" } };
pass = pass and: { ~trigLog[1] == 7 };
pass = pass and: { ~trigLog[2].asString == "do_plane" };

// an instrument not in the voice's choices is rejected (state unchanged)
~matInstruments[0] = nil;
try { ~matApplyInstrument.(0, \do_plane) } { |e| pass = false };   // kick can't be do_plane
pass = pass and: { ~matInstruments[0].isNil };

// empty/"default" clears to nil
~matInstruments[7] = \do_plane;
~matApplyInstrument.(7, \default);
pass = pass and: { ~matInstruments[7].isNil };

// applying a kit sets its voices and leaves others nil
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matApplyKit.(\deep);
pass = pass and: { ~matInstruments[~matVoices.indexOf(\kick)] == \do_kick };
pass = pass and: { ~matInstruments[~matVoices.indexOf(\hats)].isNil };

// with an instrument set, consuming a ~matVariation stream carries \instrument
~matInstruments[6] = \do_strike;
~trigLog2 = nil;
try { ~trigLog2 = ~matVariation.(\arp, 2, 6).asStream.next(()) } { |e| pass = false;
    ("EXCEPTION matVariation inst: " ++ e.class.name).postln };
pass = pass and: { ~trigLog2.notNil and: { ~trigLog2[\instrument] == \do_strike } };
~matVoices.size.do { |i| ~matInstruments[i] = nil };   // reset for later tests
```

Add `~trigLog2` to the `var` declarations at the top of the test block (L7-11):
`var trigLog2 = nil;` is not needed — `~trigLog2` is an env var; no declaration required.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL` (`~matInstruments` undefined).

- [ ] **Step 3: Add instrument state to the init block**

In `matrix.scd`, after the `~matLastColor` initializer (~L25), add:

```supercollider
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, nil);
```

- [ ] **Step 4: Add `~matInstChoices` and `~matKits`**

Add near the other `~mat*` helpers (e.g. after `~matBaseFor`, before `~matVariation`):

```supercollider
// -- per-voice curated instrument choices (symbol must be a loaded SynthDef) --
~matInstChoices = ~matInstChoices ? IdentityDictionary[
    \kick  -> [\lp_kick, \do_kick, \do_quake_sub],
    \hats  -> [\lp_hat,  \do_hat],
    \clap  -> [\lp_clap, \lp_rim, \do_hat],
    \perc  -> [\lp_perc, \do_strike, \lp_tom],
    \sub   -> [\lp_sub,  \lp_reese, \do_body_drone, \do_quake_sub],
    \acid  -> [\lp_acid, \lp_pluck, \do_geo],
    \arp   -> [\lp_pluck, \do_strike, \lp_bells],
    \lead  -> [\lp_pluck, \do_plane, \do_strike, \lp_bells],
    \stab  -> [\lp_pluck, \do_geo, \lp_acid],
    \pad   -> [\lp_pad,  \do_body_drone, \do_drone, \lp_reese],
    \ride  -> [\lp_ride, \lp_hat, \do_hat],
    \rim   -> [\lp_rim,  \lp_clap, \do_hat],
    \tom   -> [\lp_tom,  \do_strike, \do_quake_sub],
    \reese -> [\lp_reese, \lp_sub, \do_body_drone, \do_weather],
    \bells -> [\lp_bells, \do_strike, \do_plane],
    \sweep -> [\lp_sweep, \do_body_gran, \do_drone, \do_weather]
];

// -- fixed kits: kitName -> (voiceName -> instrument). Unlisted voices = default --
~matKits = ~matKits ? IdentityDictionary[
    \default -> IdentityDictionary[],
    \deep -> IdentityDictionary[
        \kick -> \do_kick, \sub -> \do_body_drone, \reese -> \do_body_drone,
        \pad -> \do_drone, \sweep -> \do_drone ],
    \industrial -> IdentityDictionary[
        \kick -> \do_quake_sub, \perc -> \do_strike, \tom -> \do_strike,
        \clap -> \lp_rim, \stab -> \do_geo ],
    \acid -> IdentityDictionary[
        \lead -> \do_plane, \arp -> \do_strike, \sub -> \lp_reese, \bells -> \do_plane ]
];
```

- [ ] **Step 5: Add `~matApplyInstrument` and `~matApplyKit`**

Add after the kits:

```supercollider
// -- ~matApplyInstrument : set voice vi's instrument (nil = default), re-source, echo --
~matApplyInstrument = { |vi, instOrNil|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var inst = ((instOrNil == \default) or: { instOrNil == '' } or: { instOrNil.isNil })
            .if({ nil }, { instOrNil.asSymbol });
        var ok = inst.isNil or: { (~matInstChoices[name] ? []).includes(inst) };
        ok.if({
            ~matInstruments[vi] = inst;
            ~matLastColor[vi] = -1;                       // force re-source next bar
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~toscSend !? { ~toscSend.("/matrix/instrument", vi, (inst ? \default).asString) }
        })
    })
};

// -- ~matApplyKit : apply a fixed kit map to all voices, echo each --
~matApplyKit = { |name|
    var kit = ~matKits[name.asSymbol];
    kit.notNil.if({
        ~matVoices.do { |vname, vi|
            ~matApplyInstrument.(vi, kit[vname] ? \default)
        }
    })
};
```

- [ ] **Step 6: Inject `\instrument` into the `~matVariation` overlay**

In `~matVariation`, the overlay Pbind (currently the `Pchain(Pbind(\matGlow, ...,
\amp, spec[\amp]), base)` at ~L66-79) gains an `\instrument` key AFTER `\amp`, read
from `~matInstruments[vi]` (only when non-nil; nil → no key → base instrument). Keep
`\matGlow` first. Replace the overlay `Pbind(...)` argument list's end so it reads:

```supercollider
        Pbind(
            \matGlow, Pfunc { |e|
                ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1));
                0
            },
            \stretch, spec[\stretch],
            \octave,  spec[\octave],
            \amp,     spec[\amp],
            \instrument, Pfunc { ~matInstruments[vi] }   // nil → base \instrument kept
        ),
```

Note: a Pbind value of `nil` for `\instrument` leaves the base event's
`\instrument` untouched (Pchain only overrides keys with non-nil values per event).

- [ ] **Step 7: Add the OSCdefs**

After the existing `OSCdef(\mat_list, ...)` block (~L306-309), add:

```supercollider
OSCdef(\mat_inst, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyInstrument.(msg[1].asInteger, (msg[2] ? \default).asSymbol)
}, '/matrix/instrument');

OSCdef(\mat_kit, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyKit.((msg[1] ? \default).asSymbol)
}, '/matrix/kit');
```

- [ ] **Step 8: Run the tests + balance check**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`, no EXCEPTION lines.
Run: `awk 'BEGIN{p=0;b=0}{for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c=="(")p++;if(c==")")p--;if(c=="[")b++;if(c=="]")b--}}END{print "P:"p" B:"b}' sound_algo/data_only/matrix.scd`
Expected: `P:0 B:0`

- [ ] **Step 9: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: per-voice matrix instrument + kits"
```

---

### Task 2: Persist instruments in the .matrix format (backward-compatible)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matSave` ~L237, `~matLoadFile` ~L247, add `~matInstrPush`; `~matGridValid` stays for the grid)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matInstrPush` (sends `/matrix/instruments` with 16 instrument strings).
- Changes: `.matrix` file content from a bare grid Array compile-string to an Event
  `(grid: <16x32>, instruments: <16 symbols-or-default>)`. `~matLoadFile` accepts
  BOTH (Array = legacy grid-only → instruments default to nil).

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Instrument persistence round-trip (Task 2) ---
pass = pass and: { ~matInstrPush.notNil };
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matSetCell.(1, 7, 4);
~matApplyInstrument.(7, \do_plane);                 // lead -> do_plane
~matSave.("inst grid");
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matClear.();
pass = pass and: { ~matLoad.("inst grid") };
pass = pass and: { ~lp[\matrix][1][7] == 4 };       // grid restored
pass = pass and: { ~matInstruments[7] == \do_plane }; // instrument restored
File.delete(~matDir +/+ "inst_grid.matrix");

// legacy grid-only file still loads (instruments default nil)
File.use(~matDir +/+ "legacy.matrix", "w", { |f|
    f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matInstruments[3] = \do_strike;
pass = pass and: { ~matLoad.("legacy") };
pass = pass and: { ~matInstruments.every({ |x| x.isNil }) };  // defaulted
File.delete(~matDir +/+ "legacy.matrix");
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL` (`~matInstrPush` undefined / instruments not restored).

- [ ] **Step 3: Add `~matInstrPush`** (after `~matGridPush`, ~L224)

```supercollider
// -- ~matInstrPush : send 16 instrument names (or "default") to surfaces --
~matInstrPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/instruments"]
            ++ ~matInstruments.collect({ |x| (x ? \default).asString }))
    }
};
```

- [ ] **Step 4: Extend `~matSave` to write grid + instruments**

Replace `~matSave` (~L237-244) body's write line so it serializes an Event:

```supercollider
~matSave = { |name|
    var safe = ~matSafeName.(name);
    var path = ~matDir +/+ (safe ++ ".matrix");
    var payload = (
        grid: ~lp[\matrix],
        instruments: ~matInstruments.collect({ |x| (x ? \default) })
    );
    File.use(path, "w", { |f| f.write(payload.asCompileString) });
    ~matSavedNames.add(safe.asSymbol);
    ("[matrix] saved " ++ path).postln;
    ~matListPush.();
};
```

- [ ] **Step 5: Extend `~matLoadFile` to accept Event or legacy Array**

Replace `~matLoadFile` (~L247-265):

```supercollider
~matLoadFile = { |path|
    var raw, grid, insts;
    File.exists(path).if({
        raw = File.use(path, "r", { |f| f.readAllString }).interpret;
        // legacy: bare grid Array; new: Event (grid:, instruments:)
        grid  = raw.isArray.if({ raw }, { raw[\grid] });
        insts = raw.isArray.if({ nil }, { raw[\instruments] });
        ~matGridValid.(grid).if({
            ~lp[\matrix] = grid;
            // restore instruments (default nil; validate against choices)
            ~matVoices.do { |name, vi|
                var sym = (insts.notNil).if({ insts[vi] }, { \default });
                ~matInstruments[vi] = ((sym.isNil) or: { sym == \default } or: {
                    (~matInstChoices[name] ? []).includes(sym.asSymbol).not
                }).if({ nil }, { sym.asSymbol });
            };
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
            ~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) });
            ~matGridPush.();
            ~matInstrPush.();
            ("[matrix] loaded " ++ path).postln;
            true
        }, {
            ("[matrix] invalid grid in " ++ path).warn;
            false
        })
    }, {
        ("[matrix] not found " ++ path).warn;
        false
    })
};
```

- [ ] **Step 6: Run tests + balance**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST PASS`.
Run the awk balance on matrix.scd → `P:0 B:0`.

- [ ] **Step 7: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: persist instruments in matrix presets"
```

---

### Task 3: Web instrument selects, kit buttons, right-click clear

**Files:**
- Modify: `web_realart/public/control/index.html` (kit buttons in the matrix transport ~L161)
- Modify: `web_realart/public/control/control.js` (`renderMatrix` row build ~L263; WS handlers ~L200; kit button + persistence wiring ~L635)
- Modify: `web_realart/public/control/control.css` (sticky voice-label/instrument column; `.mcell` unaffected)

**Interfaces:**
- Consumes: `/matrix/instrument <vi> <inst>`, `/matrix/instruments <16 strings>`,
  `/matrix/kit <name>` (Task 1/2), `MATRIX_VOICES`, `cellRefs`, `matPlayhead`.
- Produces: per-row instrument `<select>`, kit buttons, `contextmenu` clear, the
  `MATRIX_INST_CHOICES` JS table, and persisted instrument state.

- [ ] **Step 1: Add `MATRIX_INST_CHOICES` + kit list (after `MATRIX_VOICES`, ~L208)**

```javascript
// per-voice curated instrument options (must mirror SC ~matInstChoices)
const MATRIX_INST_CHOICES = {
  kick:["lp_kick","do_kick","do_quake_sub"], hats:["lp_hat","do_hat"],
  clap:["lp_clap","lp_rim","do_hat"], perc:["lp_perc","do_strike","lp_tom"],
  sub:["lp_sub","lp_reese","do_body_drone","do_quake_sub"],
  acid:["lp_acid","lp_pluck","do_geo"], arp:["lp_pluck","do_strike","lp_bells"],
  lead:["lp_pluck","do_plane","do_strike","lp_bells"], stab:["lp_pluck","do_geo","lp_acid"],
  pad:["lp_pad","do_body_drone","do_drone","lp_reese"], ride:["lp_ride","lp_hat","do_hat"],
  rim:["lp_rim","lp_clap","do_hat"], tom:["lp_tom","do_strike","do_quake_sub"],
  reese:["lp_reese","lp_sub","do_body_drone","do_weather"],
  bells:["lp_bells","do_strike","do_plane"], sweep:["lp_sweep","do_body_gran","do_drone","do_weather"]
};
const MATRIX_KITS = ["default","deep","industrial","acid"];
let matInst = new Array(16).fill("default");   // per-voice selection (persisted)
```

- [ ] **Step 2: Persist instruments with the grid**

Find `saveMatState`/`loadMatState` (they persist `matGrid` under `MATRIX_STORAGE_KEY`,
~L233). Change them to store `{grid, inst}`:

```javascript
function saveMatState() {
  try { localStorage.setItem(MATRIX_STORAGE_KEY,
    JSON.stringify({ grid: matGrid, inst: matInst })); } catch (_e) {}
}
function loadMatState() {
  try {
    const raw = JSON.parse(localStorage.getItem(MATRIX_STORAGE_KEY));
    if (raw && Array.isArray(raw.grid)) { matGrid = raw.grid;
      if (Array.isArray(raw.inst) && raw.inst.length === 16) matInst = raw.inst; return; }
    if (Array.isArray(raw)) { matGrid = raw; return; }   // legacy: bare grid
  } catch (_e) {}
  matGrid = Array.from({ length: 16 }, () => new Array(32).fill(0));
}
```

(Keep any existing validation the current `loadMatState` performs; the key change is
reading `.grid`/`.inst` and tolerating the legacy bare-array form.)

- [ ] **Step 3: Build the per-row instrument `<select>` in `renderMatrix`**

In the voice-row loop (~L263-269), right after `row.appendChild(label);`, insert a
`<select>` populated from `MATRIX_INST_CHOICES`:

```javascript
    const inst = document.createElement("select");
    inst.className = "minst";
    inst.dataset.vi = vi;
    [["default","default"]].concat(
      (MATRIX_INST_CHOICES[MATRIX_VOICES[vi]] || []).map(s => [s, s])
    ).forEach(([val, txt]) => {
      const o = document.createElement("option"); o.value = val; o.textContent = txt;
      inst.appendChild(o);
    });
    inst.value = matInst[vi] || "default";
    inst.addEventListener("change", () => {
      matInst[vi] = inst.value; saveMatState();
      send("/matrix/instrument", vi, inst.value);
    });
    row.appendChild(inst);
```

- [ ] **Step 4: Add the right-click-clear on cells**

In the same loop, after the existing `cell.addEventListener("click", ...)` (~L278-288),
add:

```javascript
      cell.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        matGrid[vi][bar] = 0; saveMatState();
        applyMatCellColor(cell, 0);
        if (bar === matPlayhead) cell.classList.add("playing");
        send("/matrix/cell", vi, bar, 0);
      });
```

- [ ] **Step 5: Add WS handlers for instrument echo + bulk instruments**

Inside the `ws` message listener, after the `/matrix/trig` block (~L200), add:

```javascript
  // /matrix/instrument <vi> <inst> — single-voice instrument echo
  if (address === "/matrix/instrument") {
    const vi = Math.round(Number(args[0])); const v = String(args[1] ?? "default");
    if (vi >= 0 && vi < 16) {
      matInst[vi] = v; saveMatState();
      const sel = document.querySelector(`.minst[data-vi="${vi}"]`);
      if (sel) sel.value = v;
    }
    return;
  }
  // /matrix/instruments <16 strings> — bulk (preset load / kit)
  if (address === "/matrix/instruments") {
    for (let vi = 0; vi < 16 && vi < args.length; vi++) {
      const v = String(args[vi] ?? "default"); matInst[vi] = v;
      const sel = document.querySelector(`.minst[data-vi="${vi}"]`);
      if (sel) sel.value = v;
    }
    saveMatState();
    return;
  }
```

- [ ] **Step 6: Add kit buttons to index.html + wiring**

In `index.html`, inside `.matrix-transport` (~L157-160), after the CLEAR button add:

```html
    <button id="kit-default" class="kit-btn" data-kit="default">DEFAULT</button>
    <button id="kit-deep" class="kit-btn" data-kit="deep">DEEP</button>
    <button id="kit-industrial" class="kit-btn" data-kit="industrial">INDUS</button>
    <button id="kit-acid" class="kit-btn" data-kit="acid">ACID</button>
```

In `control.js`, in the `DOMContentLoaded` wiring (~L635, near the other matrix
buttons), add:

```javascript
  document.querySelectorAll(".kit-btn").forEach((b) => {
    b.addEventListener("click", () => send("/matrix/kit", b.dataset.kit));
  });
```

- [ ] **Step 7: CSS — sticky instrument column + kit buttons**

In `control.css`, make the voice label + instrument select stick to the left while
the grid scrolls, and style the new controls. Append:

```css
.mvoice-label { position: sticky; left: 0; z-index: 2; background: #111; }
.minst { position: sticky; left: 54px; z-index: 2; width: 78px; font-size: 10px;
  background: #1a1a1a; color: #ccc; border: 1px solid #333; flex-shrink: 0; }
.kit-btn { flex: 1; padding: 10px 4px; font-size: 11px; }
```

- [ ] **Step 8: Static verification + manual checklist**

Run: `node --check web_realart/public/control/control.js` → no output (OK).
Manual (browser, data-only SC running): swap a voice's instrument and hear it at the
next bar; apply each kit and confirm all selects update via echo; right-click a cell
clears it; save a named matrix, reload the page, load it back, and confirm both the
grid AND the instrument selections restore.

- [ ] **Step 9: Commit**

```bash
git add web_realart/public/control/index.html web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: web matrix instrument selects and kits"
```

---

## Self-Review

**Spec coverage:** per-voice curated swap → Task 1 (state/choices/overlay) + Task 3
(selects). Fixed kits → Task 1 (`~matKits`/`~matApplyKit`) + Task 3 (buttons).
Right-click-clear → Task 3 Step 4. Persistence into presets → Task 2 (+ Task 3
localStorage). Curated invariant (kit ⊆ choices) → Task 1 validation + the kit maps
only use listed symbols. Backward-compat .matrix → Task 2 Step 5 (Array vs Event).
`\matGlow` stays first → Task 1 Step 6. ✓

**Placeholder scan:** every code step shows complete code; no TBD. ✓

**Type consistency:** `~matApplyInstrument.(vi, instOrNil)` and `~matApplyKit.(name)`
defined Task 1, used Task 2 tests + Task 1 OSCdefs. `/matrix/instrument` (single) and
`/matrix/instruments` (bulk) distinct and consistent SC↔web. `matInst[16]` and
`MATRIX_INST_CHOICES` consistent across Task 3 steps. `~matInstrPush` defined Task 2
Step 3, called in `~matLoadFile` Task 2 Step 5. ✓
