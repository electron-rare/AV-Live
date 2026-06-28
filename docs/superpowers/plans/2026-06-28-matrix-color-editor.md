# Matrix Per-Instrument Color Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each matrix voice's 6 colors per-voice editable (variation + sound) via a popup editor with a 6-color audition loop, replacing the global hardcoded variation table.

**Architecture:** A per-voice `~matColorDefs[vi]` table (colors 1-6, each an Event with stretch/octave/amp/inst/cutoff/pan) becomes the source `~matVariation` reads — defaults reproduce the current global table, so behavior is unchanged until edited. The existing overlay (glow + per-voice volume + instrument + mod) is preserved; per-color `inst`/`cutoff`/`pan` slot in. A web modal edits the 6 colors and auditions them. Color defs persist in the `.matrix` Event.

**Tech Stack:** SuperCollider (sclang), vanilla browser JS (classic control.js), CSS, Node `node:test`.

## Anchoring note (post-reconciliation)

This plan targets `~matVariation` as it exists at main `1df8b89` (reconciled with
instruments + capture + per-voice volume). Its current overlay is
`Pchain(Pbind(*([\matGlow, \stretch, \octave, \amp(=spec[\amp]*volOf)] ++ instPair
++ modPairs)), base)` with `var spec = [..hardcoded..][color]` and
`var inst = ~matInstruments[vi]`. Line numbers below are approximate; locate by the
surrounding code.

## Global Constraints

- SC env vars lowercase `~xxx`; comments English; no emojis; `.scd` awk balance P:0 B:0. — sound_algo/CLAUDE.md
- Defaults MUST reproduce the current variation table exactly (behavior-preserving until edited). — spec
- `\matGlow` stays FIRST overlay key; instrument stays a conditional `instPair` (never a nil-yielding Pfunc); per-voice volume (`volOf`) preserved; mod keys appended LAST so live mod overrides static color-def cutoff/pan. — spec + reconciled overlay
- Editable knobs bounded to synth-exposed args: instrument, stretch, octave, amp, cutoff (filter voices), pan (pan voices). cutoff/pan applicability reuses `~matModTargets` membership. — spec
- `.matrix` format stays backward-compatible: files without `colorDefs` load with default defs (the 14+ shipped grid-only presets, instrument-only, and mod Events all still load). — spec
- No audio-graph / SynthDef changes; no `server.js` change. — spec
- Commit subject <= 50 chars, no underscore in scope, no AI attribution. — CLAUDE.md

---

### Task 1: SC color-def state + `~matVariation` reads it (parity-preserving)

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (state init near `~matModNeutralCut`; `~matVariation` ~L152-197)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matColorDefs` (Array of 16; each an Array of 7 where index 1-6 is an
  Event `(stretch:, octave:, amp:, inst:, cutoff:, pan:)`; index 0 unused),
  `~matDefaultColorDefs` (a function returning a fresh default 7-slot array).
- `~matVariation.(name, color, vi)` now reads `~matColorDefs[vi][color]`; signature unchanged.

- [ ] **Step 1: Write the failing tests**

Insert into `test_matrix.scd` before the final `pass.if(`:

```supercollider
// --- Color editor: per-voice color defs (Task 1) ---
pass = pass and: { ~matColorDefs.notNil and: { ~matColorDefs.size == 16 } };
// defaults reproduce the current table: color 2 = stretch 0.5, octave 0, amp 1.0
pass = pass and: { ~matColorDefs[5][2][\stretch] == 0.5 };
pass = pass and: { ~matColorDefs[5][2][\octave] == 0 };
pass = pass and: { ~matColorDefs[5][2][\amp] == 1.0 };
pass = pass and: { ~matColorDefs[5][5][\amp] == 1.05 };   // color 5 default amp
pass = pass and: { ~matColorDefs[0][1][\inst].isNil };    // inst default nil
// ~matVariation reads the def: editing the def changes the produced event
~matColorDefs[5][2][\stretch] = 0.25;
~tv = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~tv[\stretch] == 0.25 };
~matColorDefs[5][2][\stretch] = 0.5;                      // restore default
// per-color cutoff applies for a filter voice (acid supports cutoff)
~matColorDefs[5][2][\cutoff] = 1234;
~tv2 = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~tv2[\cutoff] == 1234 };
~matColorDefs[5][2][\cutoff] = nil;
// per-color inst overrides the per-voice default
~matColorDefs[6][2][\inst] = \do_strike;                 // arp supports do_strike
~tv3 = ~matVariation.(\arp, 2, 6).asStream.next(());
pass = pass and: { ~tv3[\instrument] == \do_strike };
~matColorDefs[6][2][\inst] = nil;
```

(Requires `Pdef(\lp_acid)` and `Pdef(\lp_arp)` in the test setup — already present.)

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/SuperCollider.app/Contents/MacOS/sclang sound_algo/data_only/test/test_matrix.scd`
Expected: `TEST FAIL` (`~matColorDefs` undefined).

- [ ] **Step 3: Add the default-builder and state init**

In `matrix.scd`, near the other `~mat*` init (after `~matModNeutralCut`), add:

```supercollider
// -- default color defs reproduce the historical global variation table --
~matDefaultColorDefs = {
    [ nil,
        (stretch: 1.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil),
        (stretch: 0.5, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil),
        (stretch: 1.0, octave:  1, amp: 1.0,  inst: nil, cutoff: nil, pan: nil),
        (stretch: 2.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil),
        (stretch: 1.0, octave: -1, amp: 1.05, inst: nil, cutoff: nil, pan: nil),
        (stretch: 0.5, octave:  0, amp: 1.2,  inst: nil, cutoff: nil, pan: nil) ]
};
~matColorDefs = ~matColorDefs ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
```

- [ ] **Step 4: Make `~matVariation` read `~matColorDefs[vi][color]`**

In `~matVariation`, replace the hardcoded `var spec = [ nil, (..), .. ][color];`
(currently ~L153-161) with a per-voice lookup, change `inst` to honor a per-color
override, and add a `cdPairs` (color-def cutoff/pan) between `instPair` and
`modPairs`. The full `spec.notNil.if({ ... })` block becomes:

```supercollider
            var spec = ~matColorDefs[vi][color];
            spec.notNil.if({
                var inst = spec[\inst] ? ~matInstruments[vi];      // per-color wins, else voice default
                var volOf = { (~lp[\vol].notNil).if({ ~lp[\vol][name.asSymbol] ? 0.8 }, { 0.8 }) };
                var instPair = inst.notNil.if({ [\instrument, inst] }, { [] });
                var cdPairs = [];
                (spec[\cutoff].notNil and: { (~matModTargets[name] ? []).includes(\cutoff) }).if({
                    cdPairs = cdPairs ++ [\cutoff, spec[\cutoff]] });
                (spec[\pan].notNil and: { (~matModTargets[name] ? []).includes(\pan) }).if({
                    cdPairs = cdPairs ++ [\pan, spec[\pan]] });
                ~matVariationOverlay.(name, vi, spec, volOf, instPair, cdPairs)
            }, { base })
```

where the overlay assembly (which keeps `mod`/`modPairs` and the Pchain) is factored
into a helper so the function stays readable. Add this helper just before
`~matVariation` (it closes over `~matMod`/`~matModNeutralCut`/`~matModSourceVal`/`base`
— pass `base` in):

```supercollider
~matVariationOverlay = { |name, vi, spec, volOf, instPair, cdPairs|
    var base = ~matBaseFor.(name);
    var mod = ~matMod[vi];
    var modPairs = mod.isNil.if({ [] }, {
        var src = mod[\source], tgt = mod[\target], d = mod[\depth];
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            [\cutoff, Pfunc { var s = ~matModSourceVal.(src);
                c0 * (s.linexp(0, 1, 200, 6000) / c0).pow(d) }]
        }, {
            (tgt == \pan).if({
                [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }]
            }, {
                [\amp, Pfunc { (spec[\amp] * volOf.value) * (1 + (d * (~matModSourceVal.(src) * 2 - 1))).max(0) }]
            })
        })
    });
    Pchain(
        Pbind(*([
            \matGlow, Pfunc { |e| ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1)); 0 },
            \stretch, spec[\stretch],
            \octave,  spec[\octave],
            \amp,     Pfunc({ (spec[\amp] ? 1.0) * volOf.value })
        ] ++ instPair ++ cdPairs ++ modPairs)),
        base
    )
};
```

Precedence note: `cdPairs` (static per-color cutoff/pan) come BEFORE `modPairs`, so a
live capture mod on the same target overrides the static color value — intended.

- [ ] **Step 5: Run tests + balance**

Run the sclang test → `TEST PASS`. Run the awk balance on matrix.scd → `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: per-voice editable matrix color defs"
```

---

### Task 2: `~matSetColorDef` + push + OSCdefs

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (helpers + OSCdefs near the other `~mat_*` OSCdefs)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matSetColorDef.(vi, color, field, value)`, `~matColorDefPush.(vi)`.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Color editor: set + push (Task 2) ---
pass = pass and: { ~matSetColorDef.notNil and: { ~matColorDefPush.notNil } };
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetColorDef.(5, 3, \octave, -2);                 // acid, color 3
pass = pass and: { ~matColorDefs[5][3][\octave] == -2 };
// ~matSetColorDef echoes via ~matColorDefPush -> PLURAL /matrix/colordefs (vi + 36 vals)
pass = pass and: { ~trigLog[0] == "/matrix/colordefs" and: { ~trigLog[1] == 5 } };
pass = pass and: { ~trigLog.size == 38 };
// invalid field is rejected (state unchanged)
~matSetColorDef.(5, 3, \bogus, 9);
pass = pass and: { (~matColorDefs[5][3][\bogus]).isNil };
// invalid inst for the voice is rejected
~matSetColorDef.(0, 1, \inst, \do_plane);            // kick can't be do_plane
pass = pass and: { ~matColorDefs[0][1][\inst].isNil };
~matSetColorDef.(5, 3, \octave, 0);                  // restore
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add the helpers**

```supercollider
// -- ~matSetColorDef : set one field of one voice/color, validate, re-source, echo --
~matSetColorDef = { |vi, color, field, value|
    var fields = [\stretch, \octave, \amp, \inst, \cutoff, \pan];
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }
        and: { fields.includes(field.asSymbol) }).if({
        var name = ~matVoices[vi];
        var ok = true;
        var v = value;
        (field.asSymbol == \inst).if({
            // coerce BEFORE comparing: over the web->OSC path `value` is the STRING
            // "default", and "default" == \default is FALSE in SC (String != Symbol).
            v = ((value.asSymbol == \default) or: { value.isNil }).if({ nil }, { value.asSymbol });
            ok = v.isNil or: { (~matInstChoices[name] ? []).includes(v) };
        });
        ((field.asSymbol == \cutoff) or: { field.asSymbol == \pan }).if({
            ok = (~matModTargets[name] ? []).includes(field.asSymbol);
            v = value.asFloat;
        });
        ((field.asSymbol == \stretch) or: { field.asSymbol == \octave } or: { field.asSymbol == \amp }).if({
            v = (field.asSymbol == \octave).if({ value.asInteger }, { value.asFloat });
        });
        ok.if({
            ~matColorDefs[vi][color][field.asSymbol] = v;
            ~matLastColor[vi] = -1;
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~matColorDefPush.(vi)
        })
    })
};

// -- ~matColorDefPush : send one voice's 6 color defs flattened to surfaces --
// flat layout per color (1..6): stretch, octave, amp, inst(str), cutoff(-1=nil), pan(-2=nil)
// Distinct OUTBOUND address (plural) so it never collides with the 4-arg inbound
// /matrix/colordef set (mirrors /matrix/instrument vs /matrix/instruments).
~matColorDefPush = { |vi|
    ~toscSend !? {
        var flat = (1..6).collect({ |c|
            var d = ~matColorDefs[vi][c];
            [ d[\stretch], d[\octave], d[\amp], (d[\inst] ? \default).asString,
              d[\cutoff] ? -1, d[\pan] ? -2 ]
        }).flatten;
        ~toscSend.valueArray(["/matrix/colordefs", vi] ++ flat)
    }
};
```

- [ ] **Step 4: Add the OSCdefs** (near the other `~mat_*` OSCdefs)

```supercollider
OSCdef(\mat_colordef, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetColorDef.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger,
        (msg[3] ? \amp).asSymbol, msg[4])
}, '/matrix/colordef');

OSCdef(\mat_colordef_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matColorDefPush.((msg[1] ? 0).asInteger)
}, '/matrix/colordefs/get');
```

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix color def set and push"
```

---

### Task 3: `~matAudition` + OSCdef

**Files:**
- Modify: `sound_algo/data_only/matrix.scd`
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matAudition.(vi, on)`.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Color editor: audition (Task 3) ---
pass = pass and: { ~matAudition.notNil };
// off when not running must not raise
try { ~matAudition.(0, false) } { |e| pass = false;
    ("EXCEPTION matAudition off: " ++ e.class.name).postln };
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add `~matAudition`**

```supercollider
// -- ~matAudition : preview a voice's 6 colors as a 1-beat-per-step loop --
// on=true starts a Routine cycling color 1..6 (re-sources the voice's Pdef each
// step); on=false stops the routine and silences the voice. Preview only — does
// not move the grid playhead.
~matAudition = { |vi, on|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var key  = ("lp_" ++ name).asSymbol;
        ~matAudRoutine = ~matAudRoutine ? IdentityDictionary.new;
        ~matAudRoutine[vi] !? { ~matAudRoutine[vi].stop };
        on.if({
            var clock = ~lp[\clock] ? TempoClock.default;
            ~matAudRoutine[vi] = Routine({
                var c = 1;
                loop {
                    var pat = ~matVariation.(name, c, vi);
                    pat.notNil.if({ Pdef(key, pat); Pdef(key).play(clock, quant: 1) });
                    1.wait;
                    c = (c % 6) + 1;
                }
            }).play(clock, quant: 1);
        }, {
            ~matAudRoutine[vi] = nil;
            Pdef.all.includesKey(key).if({ Pdef(key).stop });
            ~matLastColor[vi] = -1;       // force normal re-source on next grid bar
        })
    })
};
```

- [ ] **Step 4: Add the OSCdef**

```supercollider
OSCdef(\mat_audition, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matAudition.((msg[1] ? 0).asInteger, (msg[2] ? 0) > 0)
}, '/matrix/audition');
```

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix color audition loop"
```

---

### Task 4: Persist color defs in the .matrix Event

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matSave`, `~matLoadFile`)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Changes: `.matrix` Event gains a `colorDefs` field; load defaults missing/invalid
  defs to `~matDefaultColorDefs`.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Color editor: persistence (Task 4) ---
~matColorDefs[4][3][\amp] = 0.42;                    // sub, color 3
~matSave.("cdef grid");
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
pass = pass and: { ~matLoad.("cdef grid") };
pass = pass and: { ~matColorDefs[4][3][\amp] == 0.42 };
File.delete(~matDir +/+ "cdef_grid.matrix");
// legacy grid-only file loads with default color defs
File.use(~matDir +/+ "cleg.matrix", "w", { |f|
    f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matColorDefs[4][3][\amp] = 0.9;
pass = pass and: { ~matLoad.("cleg") };
pass = pass and: { ~matColorDefs[4][3][\amp] == 1.0 };   // defaulted (color 3 amp default)
File.delete(~matDir +/+ "cleg.matrix");
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add `colorDefs` to `~matSave`** — extend the payload Event:

```supercollider
    var payload = (
        grid: ~lp[\matrix],
        instruments: ~matInstruments.collect({ |x| (x ? \default) }),
        mods: ~matMod.collect({ |m| m.isNil.if({ \none }, { [m[\source], m[\target], m[\depth]] }) }),
        colorDefs: ~matColorDefs.collect({ |defs| (1..6).collect({ |c| defs[c] }) })
    );
```

- [ ] **Step 4: Restore in `~matLoadFile`** — after the mod-restore block, add:

```supercollider
            // restore color defs (default missing/legacy to the historical table)
            ~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
            ((raw.isArray.not) and: { raw[\colorDefs].notNil }).if({
                raw[\colorDefs].do { |voiceDefs, vi|
                    (voiceDefs.isArray and: { vi < ~matVoices.size }).if({
                        voiceDefs.do { |d, ci|
                            (d.isKindOf(Event)).if({
                                [\stretch, \octave, \amp, \inst, \cutoff, \pan].do { |f|
                                    d[f].notNil.if({ ~matColorDefs[vi][ci + 1][f] = d[f] })
                                }
                            })
                        }
                    })
                }
            });
```

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: persist matrix color defs in presets"
```

---

### Task 5: Web color-editor modal

**Files:**
- Modify: `web_realart/public/control/index.html` (a hidden modal container)
- Modify: `web_realart/public/control/control.js` (edit button per row; modal open/render; WS handlers; persistence)
- Modify: `web_realart/public/control/control.css` (modal + audition styles)

**Interfaces:**
- Consumes: `/matrix/colordef`, `/matrix/colordefs/get`, `/matrix/audition`,
  `MATRIX_VOICES`, `MATRIX_INST_CHOICES`, `MATRIX_MOD_TARGETS` (for cutoff/pan
  applicability). Produces: a per-voice modal editor + `matColorDefs` JS state.

- [ ] **Step 1: Add the modal container to index.html**

Before the closing `</body>` / the `control.js` script tag, add:

```html
<div id="colordef-modal" class="cd-modal" hidden>
  <div class="cd-panel">
    <div class="cd-head"><span id="cd-title">voice</span>
      <button id="cd-audition" class="cd-aud">AUDITION</button>
      <button id="cd-close" class="cd-close">X</button></div>
    <div id="cd-rows"></div>
  </div>
</div>
```

- [ ] **Step 2: Add JS state + the edit button per row**

In `control.js`, after `MATRIX_MOD_TARGETS` (or near the matrix state), add:

```javascript
let matColorDefs = Array.from({ length: 16 }, () =>
  [null,
   {stretch:1.0,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:0.5,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:1.0,octave:1,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:2.0,octave:0,amp:1.0,inst:"default",cutoff:-1,pan:-2},
   {stretch:1.0,octave:-1,amp:1.05,inst:"default",cutoff:-1,pan:-2},
   {stretch:0.5,octave:0,amp:1.2,inst:"default",cutoff:-1,pan:-2}]);
let cdEditVoice = -1, cdAuditioning = false;
```

In `renderMatrix`'s voice-row loop, right after the instrument `<select>` is
appended (the `.minst` element), add an edit button:

```javascript
    const edit = document.createElement("button");
    edit.className = "minst-edit"; edit.textContent = "..."; edit.dataset.vi = vi;
    edit.addEventListener("click", () => openColorDef(vi));
    row.appendChild(edit);
```

- [ ] **Step 3: Add the modal open/render + control wiring**

Add these functions in `control.js`:

```javascript
function openColorDef(vi) {
  cdEditVoice = vi;
  document.getElementById("cd-title").textContent = MATRIX_VOICES[vi];
  const rows = document.getElementById("cd-rows");
  rows.innerHTML = "";
  const targets = MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]] || ["none","amp"];
  const hasCut = targets.includes("cutoff"), hasPan = targets.includes("pan");
  for (let c = 1; c <= 6; c++) {
    const d = matColorDefs[vi][c];
    const r = document.createElement("div"); r.className = "cd-row m" + c;
    const mk = (label, el) => { const w = document.createElement("label");
      w.className = "cd-field"; w.textContent = label; w.appendChild(el); return w; };
    const inst = document.createElement("select"); inst.className = "cd-inst";
    [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
      .forEach(([v,t]) => { const o=document.createElement("option"); o.value=v; o.textContent=t; inst.appendChild(o); });
    inst.value = d.inst || "default";
    inst.addEventListener("change", () => setCD(c, "inst", inst.value));
    const stretch = document.createElement("select"); stretch.className = "cd-str";
    [0.5,1.0,2.0].forEach(v => { const o=document.createElement("option"); o.value=v; o.textContent=v+"x"; stretch.appendChild(o); });
    stretch.value = d.stretch; stretch.addEventListener("change", () => setCD(c, "stretch", +stretch.value));
    const oct = document.createElement("select"); oct.className = "cd-oct";
    [-1,0,1].forEach(v => { const o=document.createElement("option"); o.value=v; o.textContent=v; oct.appendChild(o); });
    oct.value = d.octave; oct.addEventListener("change", () => setCD(c, "octave", +oct.value));
    const amp = document.createElement("input"); amp.type="range"; amp.min=0; amp.max=1.5; amp.step=0.01;
    amp.value = d.amp; amp.addEventListener("change", () => setCD(c, "amp", +amp.value));
    r.appendChild(mk("inst", inst)); r.appendChild(mk("stretch", stretch));
    r.appendChild(mk("oct", oct)); r.appendChild(mk("amp", amp));
    if (hasCut) { const cut = document.createElement("input"); cut.type="range"; cut.min=200; cut.max=6000; cut.step=10;
      cut.value = d.cutoff > 0 ? d.cutoff : 1000; cut.addEventListener("change", () => setCD(c, "cutoff", +cut.value)); r.appendChild(mk("cutoff", cut)); }
    if (hasPan) { const pan = document.createElement("input"); pan.type="range"; pan.min=-1; pan.max=1; pan.step=0.01;
      pan.value = d.pan >= -1 ? d.pan : 0; pan.addEventListener("change", () => setCD(c, "pan", +pan.value)); r.appendChild(mk("pan", pan)); }
    rows.appendChild(r);
  }
  document.getElementById("colordef-modal").hidden = false;
  send("/matrix/colordefs/get", vi);
}

function setCD(color, field, value) {
  if (cdEditVoice < 0) return;
  matColorDefs[cdEditVoice][color][field] = value;
  saveMatState();
  send("/matrix/colordef", cdEditVoice, color, field, value);
}

function closeColorDef() {
  if (cdAuditioning && cdEditVoice >= 0) { send("/matrix/audition", cdEditVoice, 0); cdAuditioning = false; }
  document.getElementById("colordef-modal").hidden = true;
  cdEditVoice = -1;
}
```

Wire the modal buttons in the `DOMContentLoaded` block:

```javascript
  document.getElementById("cd-close").addEventListener("click", closeColorDef);
  document.getElementById("cd-audition").addEventListener("click", () => {
    if (cdEditVoice < 0) return;
    cdAuditioning = !cdAuditioning;
    send("/matrix/audition", cdEditVoice, cdAuditioning ? 1 : 0);
    document.getElementById("cd-audition").classList.toggle("on", cdAuditioning);
  });
```

- [ ] **Step 4: Add the WS handler for `/matrix/colordef` echo**

Inside the `ws` message listener (after the `/matrix/mods` handler), add — the SC
bulk push uses the PLURAL `/matrix/colordefs` (`vi` then 36 values = 6 colors x 6
fields stretch,octave,amp,inst,cutoff,pan); the singular `/matrix/colordef` is the
web->SC set only and has no web handler:

```javascript
  if (address === "/matrix/colordefs") {
    const vi = Math.round(Number(args[0]));
    if (vi >= 0 && vi < 16) {
      for (let c = 1; c <= 6; c++) {
        const b = 1 + (c - 1) * 6;
        matColorDefs[vi][c] = { stretch:Number(args[b]), octave:Math.round(Number(args[b+1])),
          amp:Number(args[b+2]), inst:String(args[b+3] ?? "default"),
          cutoff:Number(args[b+4]), pan:Number(args[b+5]) };
      }
      saveMatState();
      if (cdEditVoice === vi && !document.getElementById("colordef-modal").hidden) renderColorDefRows(vi);
    }
    return;
  }
```

CRITICAL: the WS handler calls `renderColorDefRows(vi)` (row-render only), NOT
`openColorDef(vi)`. `openColorDef` sends `/matrix/colordefs/get`, which makes SC push
`/matrix/colordefs` again — calling `openColorDef` from the push handler creates an
infinite get/push loop. Factor the row-building out of `openColorDef` into a separate
`renderColorDefRows(vi)`; `openColorDef` = set state + `renderColorDefRows(vi)` +
unhide + send the get ONCE; the WS handler calls only `renderColorDefRows(vi)`.

Also: the per-row edit button is a 3rd sticky-left column (22px after label+select),
so the HEADER row needs a matching 22px spacer (`.minst-edit-head`) appended right
after the `.minst-head` spacer — otherwise bar numbers misalign with bar cells (same
class as `.minst-head`/`.mmod-head`).
```javascript
```

- [ ] **Step 5: Extend persistence + CSS**

In `saveMatState`, add `cdef: matColorDefs` to the stored object; in `loadMatState`,
after restoring `mod`, add `if (Array.isArray(raw.cdef) && raw.cdef.length === 16) matColorDefs = raw.cdef;`.

Add to `control.css`:

```css
.minst-edit { position: sticky; left: 132px; z-index: 2; width: 22px; font-size: 11px;
  background: #222; color: #ccc; border: 1px solid #333; flex-shrink: 0; }
.cd-modal { position: fixed; inset: 0; background: rgba(0,0,0,0.6); display: flex;
  align-items: center; justify-content: center; z-index: 50; }
.cd-modal[hidden] { display: none; }
.cd-panel { background: #161616; border: 1px solid #333; border-radius: 6px;
  padding: 12px; max-height: 90vh; overflow-y: auto; min-width: 320px; }
.cd-head { display: flex; gap: 8px; align-items: center; margin-bottom: 8px; }
.cd-aud.on { background: #2b6; color: #fff; }
.cd-row { display: flex; gap: 6px; align-items: center; padding: 4px; border-radius: 3px;
  border-left: 4px solid; margin-bottom: 3px; }
.cd-field { font-size: 9px; color: #999; display: flex; flex-direction: column; }
```

(The `.cd-row.m1`..`.m6` border-left colors reuse the existing `.mcell.mN`
background hues — reference them or set explicit `border-left-color` per `m1`-`m6`.)

- [ ] **Step 6: Static verification + manual checklist**

Run: `node --check web_realart/public/control/control.js` → no output.
Manual (data-only SC running): open the editor on a voice via `...`; change color
2's stretch and amp and hear it on the next bar; toggle AUDITION and hear the 6
colors cycle; set a per-color instrument and cutoff; close; save a named matrix,
reload the page, load it, and confirm the color defs restore.

- [ ] **Step 7: Commit**

```bash
git add web_realart/public/control/index.html web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: web matrix color editor modal"
```

---

## Self-Review

**Spec coverage:** per-voice editable 6 colors (variation + sound) → Task 1
(`~matColorDefs` + overlay) + Task 5 (modal). 6-step audition → Task 3 + Task 5
button. Per-color sound (inst/cutoff/pan) bounded to synth args → Task 1 (cdPairs +
`~matModTargets` gate) + Task 2 validation. Defaults reproduce current table → Task 1
`~matDefaultColorDefs`. Persistence in .matrix → Task 4. Reconciliation (glow first,
volOf, instPair, mod last) → Task 1 `~matVariationOverlay`. ✓

**Placeholder scan:** complete code in every step; no TBD. The CSS `.cd-row.mN`
border colors reference existing hues — Task 5 Step 5 states to reuse the `.mcell.mN`
values explicitly. ✓

**Type consistency:** `~matSetColorDef.(vi,color,field,value)` defined Task 2, used by
the OSCdef + Task 5 `setCD`. `~matColorDefPush.(vi)` Task 2, called in
`~matSetColorDef` + the get OSCdef. `~matDefaultColorDefs` Task 1, reused Task 4.
`/matrix/colordefs` bulk-push layout (vi + 36 vals) consistent between
`~matColorDefPush` (Task 2) and the JS WS handler (Task 5 Step 4); the singular
inbound `/matrix/colordef` (4 args) is distinct and has no web handler.
`matColorDefs[vi][1..6]` shape identical SC↔JS. ✓
