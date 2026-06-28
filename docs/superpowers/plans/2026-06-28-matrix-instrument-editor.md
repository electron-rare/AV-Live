# Matrix Complete Per-Instrument Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clicking a matrix voice opens one complete editor modal (Instrument · Colors · Sequence · Assignments · Poses); add a per-color 16-step note+velocity sequencer that replaces the base pattern, and pose→action bindings.

**Architecture:** Extend `~matColorDefs[vi][color]` with a `steps` field (16 × `(degree,vel)`|rest); when non-empty `~matVariation` builds a dedicated 16-step Pbind (replacing the base+overlay path), else the current path runs. Add `~matPoseBindings` driven by a `/matrix/pose` OSC contract. Web consolidates the per-row instrument/mod controls into a tabbed modal; new Sequence and Poses tabs; SC pushes editor state via fixed-stride `/matrix/steps` and `/matrix/poses` messages (the existing stride-6 `/matrix/colordefs` is unchanged).

**Tech Stack:** SuperCollider (sclang), vanilla browser JS (classic control.js), CSS, Node `node:test`.

## Anchoring note (HEAD 8a3e7fa)

All line numbers below reference HEAD `8a3e7fa`; locate by surrounding code if shifted.
Current engine (librarian-verified):
- `~matVariation` (matrix.scd:205-223) reads `spec = ~matColorDefs[vi][color]`, resolves
  inst, builds `cdPairs` (cutoff/pan gated by `~matModTargets`), calls
  `~matVariationOverlay.(name, vi, spec, volOf, instPair, cdPairs, base)`.
- `~matVariationOverlay` (164-195): `Pchain(Pbind(*([\matGlow, \stretch, \amp] ++ instPair
  ++ cdPairs ++ freqPair ++ modPairs)), base)`; `freqRatio = 2 ** (spec[\octave] ? 0)`.
- `~lpNote.(deg, oct)` (launchpad.scd:146) → MIDI note; use `~lpNote.(deg,0).midicps` for `\freq`.
- `~matColorDefs[vi][color]` Event fields: `stretch, octave, amp, inst, cutoff, pan`.
- Load allow-list (matrix.scd:511) hardcodes those 6 fields — MUST extend for `steps`.

## Global Constraints

- SC env vars lowercase `~xxx`; comments English; no emojis; `.scd` awk balance P:0 B:0. — CLAUDE.md
- Backward-compat: a color with an EMPTY steps array (all rests) falls back to the base
  Pdef (existing behavior); `.matrix` files without `steps`/`poseBindings` load clean. — spec
- Step notes are scale DEGREES via `~lpNote` (relative to harmony); 16 steps = 16th notes
  over one bar (`\dur = ~matBeatsPerBar / 16`); velocity scales amp. — spec
- The stepped Pbind keeps `\matGlow` FIRST and still applies inst/cutoff/pan/mod and the
  `freqRatio = 2**octave` multiply. — spec + current overlay
- Pose RECOGNITION is out of scope — this consumes `/matrix/pose <poseId>` only. — spec
- No `server.js` change; no audio-graph/SynthDef change. — spec
- Commit subject <= 50 chars, no underscore in scope, no AI attribution. — CLAUDE.md
- `web_realart` is `"type":"module"`; tests use `node:test`. — package.json

---

### Task 1: SC step state + CRUD + push

**Files:** Modify `sound_algo/data_only/matrix.scd`; Test `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: each `~matColorDefs[vi][color]` gains `steps` (Array of 16, each `nil` or
  `(degree: Int, vel: Float)`). `~matStepsEmpty.(steps)` → Bool. `~matSetStep.(vi, color,
  stepIdx, degree, vel)` (degree `\rest`/nil clears). `~matStepsPush.(vi, color)` sends
  `/matrix/steps vi color <32 vals>` (16 × `[degree, vel]`, rest encoded `degree=-99, vel=0`).

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Step sequencer state (Task 1) ---
pass = pass and: { ~matStepsEmpty.notNil and: { ~matSetStep.notNil and: { ~matStepsPush.notNil } } };
// default: every color's steps is a 16-slot all-nil array -> empty
pass = pass and: { ~matColorDefs[5][2][\steps].size == 16 };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]) };
// set a step, then not empty; step holds degree+vel
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetStep.(5, 2, 3, 7, 0.8);
pass = pass and: { ~matColorDefs[5][2][\steps][3][\degree] == 7 };
pass = pass and: { ~matColorDefs[5][2][\steps][3][\vel] == 0.8 };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]).not };
pass = pass and: { ~trigLog[0] == "/matrix/steps" and: { ~trigLog[1] == 5 } };
pass = pass and: { ~trigLog.size == 35 };   // path + vi + color + 32 vals = 35
// rest clears the step
~matSetStep.(5, 2, 3, \rest, 0);
pass = pass and: { ~matColorDefs[5][2][\steps][3].isNil };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]) };
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL` (`~matStepsEmpty` undefined).

- [ ] **Step 3: Add `steps` to the default color defs**

In `~matDefaultColorDefs` (matrix.scd:40-48), add a `steps:` field (a fresh 16-nil array)
to each of the 6 color Events. Example for color 1 (do the same for 2-6):

```supercollider
        (stretch: 1.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
```

(Each color gets its own `Array.fill(16, nil)`.)

- [ ] **Step 4: Add helpers + OSCdef**

Add near the other color-def helpers:

```supercollider
// -- ~matStepsEmpty : true when no step has a note (all rests) --
~matStepsEmpty = { |steps| steps.isNil or: { steps.every({ |s| s.isNil }) } };

// -- ~matSetStep : write one step (degree \rest/nil clears), re-source, echo --
~matSetStep = { |vi, color, stepIdx, degree, vel|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }
        and: { stepIdx >= 0 and: { stepIdx < 16 } }).if({
        var steps = ~matColorDefs[vi][color][\steps];
        ((degree == \rest) or: { degree.isNil }).if({
            steps[stepIdx] = nil
        }, {
            steps[stepIdx] = (degree: degree.asInteger, vel: vel.asFloat.clip(0, 1))
        });
        ~matLastColor[vi] = -1;
        (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
        ~matStepsPush.(vi, color)
    })
};

// -- ~matStepsPush : send one color's 16 steps (degree, vel); rest -> (-99, 0) --
~matStepsPush = { |vi, color|
    ~toscSend !? {
        var flat = ~matColorDefs[vi][color][\steps].collect({ |s|
            s.isNil.if({ [-99, 0] }, { [s[\degree], s[\vel]] })
        }).flatten;
        ~toscSend.valueArray(["/matrix/steps", vi, color] ++ flat)
    }
};

OSCdef(\mat_step, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetStep.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger, (msg[3] ? 0).asInteger,
        msg[4], (msg[5] ? 0))
}, '/matrix/step');

OSCdef(\mat_steps_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    (1..6).do { |c| ~matStepsPush.((msg[1] ? 0).asInteger, c) }
}, '/matrix/steps/get');
```

Note: `/matrix/step` arg `degree` (msg[4]) may arrive as the float `-99` (web sends rest as
`-99`); `~matSetStep` treats `\rest`/nil as clear — so the web sends the symbol-less rest by
sending degree `-99`; handle it: in the OSCdef, map `msg[4] == -99` to `\rest`. Update the
OSCdef body to: `var deg = ((msg[4] ? -99) == -99).if({ \rest }, { msg[4] });` then pass `deg`.

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0` (awk on matrix.scd).

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix per-color step state and push"
```

---

### Task 2: Sequence engine — stepped Pbind replaces base

**Files:** Modify `sound_algo/data_only/matrix.scd` (`~matVariation`); Test `test_matrix.scd`

**Interfaces:**
- Produces: `~matColorStepPattern.(name, vi, color, spec, volOf, instPair, cdPairs)` → a
  Pbind that plays `spec[\steps]` as 16th notes. `~matVariation` calls it when
  `~matStepsEmpty.(spec[\steps])` is false; else the existing overlay path.

- [ ] **Step 1: Write failing tests**

```supercollider
// --- Sequence engine (Task 2) ---
pass = pass and: { ~matColorStepPattern.notNil };
// empty steps -> base path unchanged (parity): consuming yields the base-equivalent event
~matVoices.size.do { |i| ~matMod[i] = nil };
~matColorDefs[5][2][\steps] = Array.fill(16, nil);
~sv = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~sv[\stretch] == 0.5 };       // color 2 stretch, base path
// non-empty steps -> stepped pattern; first non-rest step degree shows up
~matColorDefs[5][2][\steps][0] = (degree: 4, vel: 0.9);
~sv2 = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~sv2[\degree] == 4 };          // step 0 degree
pass = pass and: { ~sv2[\dur] == (~matBeatsPerBar / 16) };
~matColorDefs[5][2][\steps] = Array.fill(16, nil);  // restore empty
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL` (`~matColorStepPattern` undefined).

- [ ] **Step 3: Add `~matColorStepPattern`**

Add just before `~matVariation`:

```supercollider
// -- ~matColorStepPattern : 16-step note+vel sequence (replaces base) --
// \matGlow first; \degree/\type from steps; \freq via ~lpNote x 2**octave; \amp =
// colorAmp x stepVel x volOf; \dur = bar/16; inst/cutoff/pan/mod applied like the overlay.
~matColorStepPattern = { |name, vi, color, spec, volOf, instPair, cdPairs|
    var steps = spec[\steps];
    var freqRatio = 2 ** (spec[\octave] ? 0);
    var mod = ~matMod[vi];
    var modPairs = mod.isNil.if({ [] }, {
        var src = mod[\source], tgt = mod[\target], d = mod[\depth];
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            [\cutoff, Pfunc { var s = ~matModSourceVal.(src); c0 * (s.linexp(0,1,200,6000)/c0).pow(d) }]
        }, {
            (tgt == \pan).if({ [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }] },
                { [] })   // amp mod handled in the \amp Pfunc below
        })
    });
    Pbind(*([
        \matGlow, Pfunc { |e| ~matEmitTrig.(vi, (e[\amp] ? 0).clip(0, 1)); 0 },
        \stepIdx, Pseq((0..15), inf),
        \type, Pfunc { |e| steps[e[\stepIdx]].isNil.if({ \rest }, { \note }) },
        \degree, Pfunc { |e| var s = steps[e[\stepIdx]]; s.isNil.if({ 0 }, { s[\degree] }) },
        \freq, Pfunc { |e| ~lpNote.(e[\degree], 0).midicps * freqRatio },
        \amp, Pfunc { |e|
            var s = steps[e[\stepIdx]];
            ((spec[\amp] ? 1.0) * (s.isNil.if({ 0 }, { s[\vel] }))) * volOf.value },
        \stretch, spec[\stretch],
        \dur, ~matBeatsPerBar / 16
    ] ++ instPair ++ cdPairs ++ modPairs))
};
```

(Note: when `mod[\target] == \amp` the amp Pfunc above does not include the mod factor —
amp modulation of a stepped sequence is out of scope for v1; cutoff/pan mod still apply.)

- [ ] **Step 4: Branch `~matVariation` on non-empty steps**

In `~matVariation` (matrix.scd:213-220), after `var spec = ~matColorDefs[vi][color];` and the
`spec.notNil.if({` block computes `inst`/`volOf`/`instPair`/`cdPairs`, replace the final
`~matVariationOverlay.(...)` call with a steps branch:

```supercollider
                (~matStepsEmpty.(spec[\steps]).not).if({
                    ~matColorStepPattern.(name, vi, color, spec, volOf, instPair, cdPairs)
                }, {
                    ~matVariationOverlay.(name, vi, spec, volOf, instPair, cdPairs, base)
                })
```

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix per-color step sequence engine"
```

---

### Task 3: Persist steps (extend the load allow-list)

**Files:** Modify `sound_algo/data_only/matrix.scd` (`~matLoadFile`); Test `test_matrix.scd`

**Interfaces:** `.matrix` colorDefs Events now carry `steps`; load restores them.

- [ ] **Step 1: Write failing tests**

```supercollider
// --- Step persistence (Task 3) ---
~matColorDefs[4][3][\steps][2] = (degree: 5, vel: 0.7);
~matSave.("step grid");
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
pass = pass and: { ~matLoad.("step grid") };
pass = pass and: { ~matColorDefs[4][3][\steps][2][\degree] == 5 };
pass = pass and: { ~matColorDefs[4][3][\steps][2][\vel] == 0.7 };
File.delete(~matDir +/+ "step_grid.matrix");
// legacy grid-only file -> default empty steps
File.use(~matDir +/+ "sleg.matrix", "w", { |f|
    f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matColorDefs[4][3][\steps][2] = (degree: 9, vel: 0.5);
pass = pass and: { ~matLoad.("sleg") };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[4][3][\steps]) };
File.delete(~matDir +/+ "sleg.matrix");
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL` (steps not restored).

- [ ] **Step 3: Extend the load allow-list**

`~matSave` already serializes `steps` (it's a field of the colorDef Event that
`asCompileString` persists — no save change needed). In `~matLoadFile`'s colorDefs restore
loop (matrix.scd:511), the field-copy list hardcodes 6 scalar fields. Add `steps` with a
value-aware copy (it is an array, copy it directly; default stays an empty 16-array):

```supercollider
                    [\stretch, \octave, \amp, \inst, \cutoff, \pan].do { |f|
                        d[f].notNil.if({ ~matColorDefs[vi][ci + 1][f] = d[f] })
                    };
                    (d[\steps].notNil and: { d[\steps].isArray }).if({
                        ~matColorDefs[vi][ci + 1][\steps] = d[\steps]
                    });
```

- [ ] **Step 4: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: persist matrix step sequences"
```

---

### Task 4: SC pose bindings + /matrix/pose

**Files:** Modify `sound_algo/data_only/matrix.scd`; Test `test_matrix.scd`

**Interfaces:**
- Produces: `~matPoseBindings` (Array of 16, each a list of `(poseId: Sym, action: Sym,
  color: Int)`). `~matSetPoseBind.(vi, poseId, action, color)` (empty poseId clears that
  voice's bindings). `~matPosesPush.(vi)` sends `/matrix/poses vi <n> <poseId,action,color>*`.
  `OSCdef(\mat_pose)` on `/matrix/pose <poseId>` runs matching bindings: `\trigger` re-sources
  the voice to `color` now; `\gate` toggles the voice's Pdef.

- [ ] **Step 1: Write failing tests**

```supercollider
// --- Pose bindings (Task 4) ---
pass = pass and: { ~matPoseBindings.notNil and: { ~matSetPoseBind.notNil } };
pass = pass and: { ~matPoseBindings.size == 16 };
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetPoseBind.(5, \poseA, \trigger, 3);
pass = pass and: { ~matPoseBindings[5].size == 1 };
pass = pass and: { ~matPoseBindings[5][0][\poseId] == \poseA };
pass = pass and: { ~trigLog[0] == "/matrix/poses" and: { ~trigLog[1] == 5 } };
// firing an unknown pose must not raise
try { ~matPoseFire.(\nope) } { |e| pass = false; ("EXCEPTION matPoseFire: " ++ e.class.name).postln };
// clear
~matSetPoseBind.(5, \poseA, \trigger, 3);   // same id again toggles/replaces
~matPoseBindings.size.do { |i| ~matPoseBindings[i] = [] };
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add state + helpers + OSCdef**

```supercollider
~matPoseBindings = ~matPoseBindings ? Array.fill(~matVoices.size, { [] });

// -- ~matSetPoseBind : add/replace a (poseId, action, color) for a voice; empty clears --
~matSetPoseBind = { |vi, poseId, action, color|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var pid = poseId.asSymbol;
        ((pid == '') or: { pid == \none }).if({
            ~matPoseBindings[vi] = []
        }, {
            // replace any existing binding for this poseId, else add
            ~matPoseBindings[vi] = ~matPoseBindings[vi].reject({ |b| b[\poseId] == pid })
                ++ [ (poseId: pid, action: action.asSymbol, color: color.asInteger.clip(1, 6)) ];
        });
        ~matPosesPush.(vi)
    })
};

// -- ~matPosesPush : send a voice's pose bindings --
~matPosesPush = { |vi|
    ~toscSend !? {
        var flat = ~matPoseBindings[vi].collect({ |b|
            [b[\poseId].asString, b[\action].asString, b[\color]] }).flatten;
        ~toscSend.valueArray(["/matrix/poses", vi, ~matPoseBindings[vi].size] ++ flat)
    }
};

// -- ~matPoseFire : run every binding matching poseId across all voices --
~matPoseFire = { |poseId|
    var pid = poseId.asSymbol;
    ~matVoices.do { |name, vi|
        var key = ("lp_" ++ name).asSymbol;
        ~matPoseBindings[vi].do { |b|
            (b[\poseId] == pid).if({
                (b[\action] == \trigger).if({
                    Pdef.all.includesKey(key).if({
                        var pat = ~matVariation.(name, b[\color], vi);
                        pat.notNil.if({ Pdef(key, pat); Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) })
                    })
                });
                (b[\action] == \gate).if({
                    Pdef.all.includesKey(key).if({ Pdef(key).isPlaying.if({ Pdef(key).stop }, { Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) }) })
                });
            })
        }
    }
};

OSCdef(\mat_posebind, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetPoseBind.((msg[1] ? 0).asInteger, (msg[2] ? \none).asSymbol,
        (msg[3] ? \trigger).asSymbol, (msg[4] ? 1).asInteger)
}, '/matrix/posebind');

OSCdef(\mat_pose, { |msg, time, addr|
    ~matPoseFire.((msg[1] ? \none).asSymbol)
}, '/matrix/pose');

OSCdef(\mat_poses_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPosesPush.((msg[1] ? 0).asInteger)
}, '/matrix/poses/get');
```

- [ ] **Step 4: Persist pose bindings** — extend `~matSave` payload and `~matLoadFile`:

In `~matSave` payload Event add:
```supercollider
        poseBindings: ~matPoseBindings
```
In `~matLoadFile`, after the colorDefs restore block, add:
```supercollider
            ~matPoseBindings = Array.fill(~matVoices.size, { [] });
            ((raw.isArray.not) and: { raw[\poseBindings].notNil }).if({
                raw[\poseBindings].do { |list, vi|
                    (list.isArray and: { vi < ~matVoices.size }).if({ ~matPoseBindings[vi] = list })
                }
            });
            ~matVoices.size.do { |vi| ~matPosesPush.(vi) };
```
Add a persistence assertion to the test: set a binding, save, clear, load, assert restored.

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix pose bindings and fire"
```

---

### Task 5: Web — consolidate row controls into a tabbed modal

**Files:** Modify `web_realart/public/control/index.html` (modal markup), `control.js`
(`renderMatrix`, modal, WS handlers), `control.css`.

**Interfaces:** Consumes `/matrix/instrument`, `/matrix/mod`, `/matrix/colordefs`,
`/matrix/audition` (existing). Produces a tabbed `#colordef-modal` with tab buttons and tab
panes; `renderMatrix` rows lose `.minst` and `.mmod` (and the `.minst-head`/`.mmod-head`
header spacers); the `.minst-edit` "..." button stays as the modal trigger. Mod + instrument
controls now live in the modal; WS echo handlers target modal elements.

- [ ] **Step 1: Make the modal tabbed in index.html**

Replace the `#colordef-modal` block (index.html:180-187) with:

```html
<div id="colordef-modal" class="cd-modal" hidden>
  <div class="cd-panel">
    <div class="cd-head"><span id="cd-title">voice</span>
      <button id="cd-audition" class="cd-aud">AUDITION</button>
      <button id="cd-close" class="cd-close">X</button></div>
    <div class="cd-tabs">
      <button class="cd-tab on" data-tab="inst">Instrument</button>
      <button class="cd-tab" data-tab="colors">Colors</button>
      <button class="cd-tab" data-tab="seq">Sequence</button>
      <button class="cd-tab" data-tab="assign">Assign</button>
      <button class="cd-tab" data-tab="poses">Poses</button>
    </div>
    <div id="cd-pane-inst" class="cd-pane"></div>
    <div id="cd-pane-colors" class="cd-pane" hidden></div>
    <div id="cd-pane-seq" class="cd-pane" hidden></div>
    <div id="cd-pane-assign" class="cd-pane" hidden></div>
    <div id="cd-pane-poses" class="cd-pane" hidden></div>
  </div>
</div>
```

- [ ] **Step 2: Remove `.minst` + `.mmod` from `renderMatrix`**

In `control.js` `renderMatrix` (344-444): delete the `.minst` select block (380-394) and the
`.mmod` span block (426-441). KEEP the `.minst-edit` button (395-398). In the header-row
construction, delete the `.minst-head` (355-357) and `.mmod-head` (367-369) spacer appends;
KEEP `.minst-edit-head` (358-360).

- [ ] **Step 3: Build the Instrument, Colors, Assign panes**

Add a `renderInstEdit(vi)` that fills the panes. The Colors pane reuses the existing
per-color rows logic (move the body of `renderColorDefRows` to fill `#cd-pane-colors`).
Instrument pane = the curated select; Assign pane = the source/target/depth controls.

```javascript
function renderInstEdit(vi) {
  // Instrument pane
  const ip = document.getElementById("cd-pane-inst"); ip.innerHTML = "";
  const sel = document.createElement("select"); sel.id = "cd-inst-sel";
  [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
    .forEach(([v,t])=>{const o=document.createElement("option");o.value=v;o.textContent=t;sel.appendChild(o);});
  sel.value = matInst[vi] || "default";
  sel.addEventListener("change", ()=>{ matInst[vi]=sel.value; saveMatState(); send("/matrix/instrument", vi, sel.value); });
  ip.appendChild(sel);
  // Colors pane: reuse renderColorDefRows but target #cd-pane-colors
  renderColorDefRows(vi);
  // Assign pane
  const ap = document.getElementById("cd-pane-assign"); ap.innerHTML = "";
  const src = document.createElement("select");
  MATRIX_MOD_SOURCES.forEach(s=>{const o=document.createElement("option");o.value=s;o.textContent=s;src.appendChild(o);});
  const tgt = document.createElement("select");
  (MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]]||["none","amp"]).forEach(t=>{const o=document.createElement("option");o.value=t;o.textContent=t;tgt.appendChild(o);});
  const dep = document.createElement("input"); dep.type="range"; dep.min=0; dep.max=1; dep.step=0.01;
  src.value=matMod[vi].source; tgt.value=matMod[vi].target; dep.value=matMod[vi].depth;
  src.className="cd-mod-src"; tgt.className="cd-mod-tgt"; dep.className="cd-mod-dep";
  const sm=()=>{matMod[vi]={source:src.value,target:tgt.value,depth:+dep.value};saveMatState();send("/matrix/mod",vi,src.value,tgt.value,+dep.value);};
  src.addEventListener("change",sm); tgt.addEventListener("change",sm); dep.addEventListener("change",sm);
  [src,tgt,dep].forEach(e=>ap.appendChild(e));
}
```

Change `renderColorDefRows` to write into `#cd-pane-colors` instead of `#cd-rows` (rename the
target element id). Change `openColorDef(vi)` to call `renderInstEdit(vi)` (which calls
`renderColorDefRows`) and send `/matrix/instrument`, `/matrix/colordefs/get`,
`/matrix/steps/get`, `/matrix/poses/get` on open. Wire the tab buttons (show/hide panes).

- [ ] **Step 4: Fix the WS echo handlers**

The `/matrix/instrument`, `/matrix/mod`, `/matrix/colordefs` handlers (215-272) query
`.minst[data-vi]` / `.mmod-src[data-vi]` which no longer exist on the row. Repoint them to the
modal elements (`#cd-inst-sel`, `.cd-mod-src/tgt/dep`) and only update DOM when the modal is
open for that vi. Keep updating the JS state (`matInst`/`matMod`/`matColorDefs`) regardless.

- [ ] **Step 5: CSS for tabs + verify**

Add `.cd-tabs { display:flex; gap:4px; margin:6px 0; } .cd-tab.on { background:#2b6; color:#fff; } .cd-pane[hidden] { display:none; }` to control.css.
Run `node --check web_realart/public/control/control.js`. Manual: open the modal; instrument,
colors, assign tabs edit and round-trip; rows are decluttered.

- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/index.html web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: unified per-instrument editor modal"
```

---

### Task 6: Web — Sequence tab (6×16 step grid)

**Files:** Modify `control.js` (sequence pane + `/matrix/steps` handler + state), `control.css`.

**Interfaces:** Consumes `/matrix/step` (set) and `/matrix/steps` (push, vi+color+32 vals).
`matSteps[vi][color]` = 16 × `{degree, vel}`|null.

- [ ] **Step 1: Add state + render the step grid**

```javascript
let matSteps = Array.from({length:16}, () => Array.from({length:7}, () => new Array(16).fill(null)));
function renderSeq(vi) {
  const p = document.getElementById("cd-pane-seq"); p.innerHTML = "";
  for (let c = 1; c <= 6; c++) {
    const row = document.createElement("div"); row.className = "seq-row m" + c;
    for (let s = 0; s < 16; s++) {
      const cell = document.createElement("button"); cell.className = "seq-cell";
      const st = matSteps[vi][c][s];
      cell.textContent = st ? st.degree : "";
      if (st) cell.classList.add("on");
      cell.addEventListener("click", () => {           // left: toggle on with degree 0
        if (matSteps[vi][c][s]) { matSteps[vi][c][s] = null; send("/matrix/step", vi, c, s, -99, 0); }
        else { matSteps[vi][c][s] = {degree:0, vel:0.8}; send("/matrix/step", vi, c, s, 0, 0.8); }
        saveMatState(); renderSeq(vi);
      });
      cell.addEventListener("wheel", (e) => {           // wheel: change degree
        e.preventDefault(); const st2 = matSteps[vi][c][s]; if (!st2) return;
        st2.degree += (e.deltaY < 0 ? 1 : -1);
        send("/matrix/step", vi, c, s, st2.degree, st2.vel); saveMatState(); renderSeq(vi);
      });
      row.appendChild(cell);
    }
    p.appendChild(row);
  }
}
```

(Call `renderSeq(vi)` from `renderInstEdit`. Velocity edit: a shift+wheel adjusts `vel` by
0.1 and sends — add that to the wheel handler.)

- [ ] **Step 2: Add the `/matrix/steps` WS handler**

Inside the ws message listener:

```javascript
  if (address === "/matrix/steps") {
    const vi = Math.round(Number(args[0])), c = Math.round(Number(args[1]));
    if (vi>=0 && vi<16 && c>=1 && c<=6) {
      for (let s=0; s<16; s++) {
        const deg = Number(args[2 + s*2]), vel = Number(args[3 + s*2]);
        matSteps[vi][c][s] = (deg === -99) ? null : {degree:deg, vel:vel};
      }
      saveMatState();
      if (cdEditVoice===vi && !document.getElementById("colordef-modal").hidden) renderSeq(vi);
    }
    return;
  }
```

- [ ] **Step 3: CSS + verify**

`.seq-row { display:flex; gap:1px; } .seq-cell { width:20px; height:20px; font-size:9px; background:#1a1a1a; color:#ccc; border:1px solid #333; } .seq-cell.on { background:#4c8; color:#000; }`
`node --check`. Manual: toggle steps, wheel changes degree, the voice plays the sequence on the next bar.

- [ ] **Step 4: Commit**

```bash
git add web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: web matrix step sequencer grid"
```

---

### Task 7: Web — Poses tab + persistence

**Files:** Modify `control.js` (poses pane + `/matrix/poses` handler + state + persistence).

**Interfaces:** Consumes `/matrix/posebind` (set), `/matrix/poses` (push). `matPoses[vi]` = list
of `{poseId, action, color}`. localStorage `pose` key + `steps` already saved under `cdef`.

- [ ] **Step 1: Add state + render the poses pane**

```javascript
let matPoses = Array.from({length:16}, () => []);
function renderPoses(vi) {
  const p = document.getElementById("cd-pane-poses"); p.innerHTML = "";
  const add = document.createElement("div");
  const id = document.createElement("input"); id.placeholder = "poseId"; id.className = "pose-id";
  const act = document.createElement("select");
  ["trigger","gate"].forEach(a=>{const o=document.createElement("option");o.value=a;o.textContent=a;act.appendChild(o);});
  const col = document.createElement("select");
  [1,2,3,4,5,6].forEach(c=>{const o=document.createElement("option");o.value=c;o.textContent="color "+c;col.appendChild(o);});
  const go = document.createElement("button"); go.textContent = "+";
  go.addEventListener("click", ()=>{
    if (!id.value) return;
    matPoses[vi] = matPoses[vi].filter(b=>b.poseId!==id.value).concat([{poseId:id.value, action:act.value, color:+col.value}]);
    saveMatState(); send("/matrix/posebind", vi, id.value, act.value, +col.value); renderPoses(vi);
  });
  [id,act,col,go].forEach(e=>add.appendChild(e)); p.appendChild(add);
  matPoses[vi].forEach(b=>{ const line=document.createElement("div");
    line.textContent = `${b.poseId} -> ${b.action} color ${b.color}`; p.appendChild(line); });
}
```

(Call `renderPoses(vi)` from `renderInstEdit`.)

- [ ] **Step 2: Add the `/matrix/poses` WS handler**

```javascript
  if (address === "/matrix/poses") {
    const vi = Math.round(Number(args[0])), n = Math.round(Number(args[1]));
    if (vi>=0 && vi<16) {
      matPoses[vi] = [];
      for (let k=0; k<n; k++) { const b=2+k*3;
        matPoses[vi].push({poseId:String(args[b]), action:String(args[b+1]), color:Math.round(Number(args[b+2]))}); }
      saveMatState();
      if (cdEditVoice===vi && !document.getElementById("colordef-modal").hidden) renderPoses(vi);
    }
    return;
  }
```

- [ ] **Step 3: Persist steps + poses in localStorage**

In `saveMatState` add `steps: matSteps, pose: matPoses` to the stored object. In
`loadMatState`, after restoring `cdef`, add:
```javascript
    if (Array.isArray(raw.steps) && raw.steps.length === 16) matSteps = raw.steps;
    if (Array.isArray(raw.pose) && raw.pose.length === 16) matPoses = raw.pose;
```

- [ ] **Step 4: Verify** — `node --check`. Manual: add a pose binding; send `/matrix/pose poseId`
from SC/another client and confirm the voice triggers/gates; reload page and confirm bindings restore.

- [ ] **Step 5: Commit**

```bash
git add web_realart/public/control/control.js
git commit -m "feat: web matrix pose bindings tab"
```

---

## Self-Review

**Spec coverage:** unified modal (tabs) → Task 5. Per-color 16-step note+vel sequence
replacing base → Task 1 (state/CRUD) + Task 2 (engine) + Task 6 (UI). Empty→base fallback →
Task 2 Step 4 (`~matStepsEmpty` branch). Pose bind + `/matrix/pose` contract → Task 4 + Task 7.
Persistence (steps + poseBindings, backward-compat) → Task 3 + Task 4 Step 4 + Task 7 Step 3.
Row consolidation (remove .minst/.mmod) → Task 5 Step 2. Degree via `~lpNote`, dur bar/16,
freqRatio → Task 2 Step 3. Pose recognition out-of-scope → not implemented (contract only). ✓

**Placeholder scan:** complete code per step; the rest sentinel (`degree -99`) is defined and
used consistently SC↔web; velocity-edit detail noted concretely in Task 6 Step 1. ✓

**Type consistency:** `~matSetStep.(vi,color,stepIdx,degree,vel)` / `~matStepsPush.(vi,color)` /
`~matColorStepPattern.(name,vi,color,spec,volOf,instPair,cdPairs)` consistent across Tasks 1-2.
`/matrix/steps` layout (vi+color+32, rest=-99) identical SC push (Task 1) ↔ JS decode (Task 6).
`/matrix/poses` layout (vi+n+triples) identical SC (Task 4) ↔ JS (Task 7). `matSteps[vi][c][s]`
and `matPoses[vi]` shapes consistent across Task 6/7. ✓
