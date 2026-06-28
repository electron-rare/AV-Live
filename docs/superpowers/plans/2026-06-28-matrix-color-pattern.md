# Matrix Per-Color Pattern Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each matrix color an autonomous pattern bundling its own instrument, 16-step sequence, capture effect, and pose binding — moving effect and pose from per-voice to per-color — with a color-centric editor.

**Architecture:** `~matColorDefs[vi][color]` gains `mod` and `pose` fields. The engine reads the effect from `spec[\mod]` (not `~matMod[vi]`); `~matPoseFire` iterates per-color pose lists. The per-voice `~matMod`/`~matPoseBindings` are removed. The web modal is reorganized as a color selector + one per-color pattern editor.

**Tech Stack:** SuperCollider (sclang), vanilla browser JS (classic control.js), CSS, Node `node:test`.

## Anchoring note (HEAD = main, after the per-instrument editor + richer-mod-palette merge)

Locate by surrounding code. Key current functions: `~matColorDefs`/
`~matDefaultColorDefs` (color Events with inst/stretch/octave/amp/cutoff/pan/steps);
`~matVariationOverlay.(name,vi,spec,volOf,instPair,cdPairs,base)` and
`~matColorStepPattern.(name,vi,color,spec,volOf,instPair,cdPairs)` — BOTH currently
build their mod keys from `~matMod[vi]` (the duplicated `modPairs` logic). `~matPoseFire`
reads `~matPoseBindings[vi]`. `~matSetColorDef`/`~matColorDefPush`/`~matLoadFile` handle
colorDefs persistence. `~matModSources`/`~matModTargets` (recently enriched) define the
valid mod palette.

## Global Constraints

- SC env vars lowercase `~xxx`; comments English; no emojis; `.scd` awk balance P:0 B:0. — CLAUDE.md
- Backward-compat: legacy `.matrix` with top-level per-voice `mods`/`poseBindings` MIGRATES into per-color on load; files without either load with nil mod / empty pose. — spec
- Empty mod (nil) / empty pose ⇒ no effect / no binding = today's default behavior (parity). — spec
- Engine invariants preserved: `\matGlow` first; instrument conditional `instPair`; `volOf`; stepped `\freq` pitched-only; mod key order unchanged (just the source). — spec + current engine
- No `server.js` change; no audio-graph change. — spec
- Commit subject <= 50 chars, no underscore in scope, no AI attribution. — CLAUDE.md
- `web_realart` is `"type":"module"`; tests use `node:test`. — package.json

---

### Task 1: SC per-color mod + pose state, setters, OSC

**Files:** Modify `sound_algo/data_only/matrix.scd`; Test `test_matrix.scd`

**Interfaces:**
- Produces: color Events gain `mod` (nil or `(source:,target:,depth:)`) and `pose`
  (Array of `(poseId:,action:)`). `~matSetColorMod.(vi,color,source,target,depth)`,
  `~matSetColorPose.(vi,color,poseId,action)`, `~matColorModPush.(vi,color)`,
  `~matColorPosePush.(vi,color)`, OSCdefs `/matrix/colormod`, `/matrix/colorpose`,
  `/matrix/colorpose/get`.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Per-color mod + pose state (Task 1) ---
pass = pass and: { ~matColorDefs[5][2][\mod].isNil };               // default no effect
pass = pass and: { ~matColorDefs[5][2][\pose].isArray and: { ~matColorDefs[5][2][\pose].isEmpty } };
pass = pass and: { ~matSetColorMod.notNil and: { ~matSetColorPose.notNil } };
~trigLog = nil; ~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetColorMod.(5, 2, \rHandY, \cutoff, 0.7);                      // acid supports cutoff
pass = pass and: { ~matColorDefs[5][2][\mod][\target] == \cutoff };
pass = pass and: { ~trigLog[0] == "/matrix/colormod" and: { ~trigLog[1] == 5 } };
~matSetColorMod.(0, 1, \rHandY, \cutoff, 0.7);                      // kick has no cutoff -> reject
pass = pass and: { ~matColorDefs[0][1][\mod].isNil };
~matSetColorMod.(5, 2, \none, \none, 0);                            // clears
pass = pass and: { ~matColorDefs[5][2][\mod].isNil };
~matSetColorPose.(5, 2, \poseA, \trigger);
pass = pass and: { ~matColorDefs[5][2][\pose][0][\poseId] == \poseA };
~matColorDefs[5][2][\pose] = [];
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add `mod`/`pose` to default color defs**

In `~matDefaultColorDefs`, add `mod: nil, pose: []` to EACH of the 6 color Events
(each color its own `[]`).

- [ ] **Step 4: Add the setters + pushes + OSCdefs**

```supercollider
// -- ~matSetColorMod : set/clear a color's capture effect; validate; re-source; echo --
~matSetColorMod = { |vi, color, source, target, depth|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }).if({
        var name = ~matVoices[vi];
        var src = ((source == \none) or: { source.isNil }).if({ nil }, { source.asSymbol });
        var tgt = ((target == \none) or: { target.isNil }).if({ nil }, { target.asSymbol });
        var d = (depth ? 0).asFloat.clip(0, 1);
        var ok = (src.isNil or: tgt.isNil) or: {
            ~matModSources.includes(src) and: { (~matModTargets[name] ? []).includes(tgt) } };
        ok.if({
            ~matColorDefs[vi][color][\mod] = (src.isNil or: tgt.isNil).if({ nil },
                { (source: src, target: tgt, depth: d) });
            ~matLastColor[vi] = -1;
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~matColorModPush.(vi, color)
        })
    })
};

// -- ~matSetColorPose : add/replace a pose binding in a color (dedup poseId; empty clears) --
~matSetColorPose = { |vi, color, poseId, action|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }).if({
        var pid = poseId.asSymbol;
        ((pid == '') or: { pid == \none }).if({
            ~matColorDefs[vi][color][\pose] = []
        }, {
            ~matColorDefs[vi][color][\pose] = (~matColorDefs[vi][color][\pose] ? [])
                .reject({ |b| b[\poseId] == pid }) ++ [ (poseId: pid, action: action.asSymbol) ];
        });
        ~matColorPosePush.(vi, color)
    })
};

// -- pushes --
~matColorModPush = { |vi, color|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }).if({
        ~toscSend !? {
            var m = ~matColorDefs[vi][color][\mod];
            ~toscSend.("/matrix/colormod", vi, color,
                (m.isNil).if({ "none" }, { m[\source].asString }),
                (m.isNil).if({ "none" }, { m[\target].asString }),
                (m.isNil).if({ 0 }, { m[\depth] }))
        }
    })
};
~matColorPosePush = { |vi, color|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }).if({
        ~toscSend !? {
            var list = ~matColorDefs[vi][color][\pose] ? [];
            var flat = list.collect({ |b| [b[\poseId].asString, b[\action].asString] }).flatten;
            ~toscSend.valueArray(["/matrix/colorpose", vi, color, list.size] ++ flat)
        }
    })
};

OSCdef(\mat_colormod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetColorMod.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger,
        (msg[3] ? \none).asSymbol, (msg[4] ? \none).asSymbol, (msg[5] ? 0).asFloat)
}, '/matrix/colormod');
OSCdef(\mat_colorpose, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetColorPose.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger,
        (msg[3] ? \none).asSymbol, (msg[4] ? \trigger).asSymbol)
}, '/matrix/colorpose');
OSCdef(\mat_colorpose_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    (1..6).do { |c| ~matColorModPush.((msg[1] ? 0).asInteger, c); ~matColorPosePush.((msg[1] ? 0).asInteger, c) }
}, '/matrix/colordefs/get/ext');
```

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: per-color mod and pose state"
```

---

### Task 2: Engine reads per-color mod; pose fire per-color; remove per-voice

**Files:** Modify `sound_algo/data_only/matrix.scd`; Test `test_matrix.scd`

**Interfaces:**
- Produces: `~matModPairs.(name, spec, volOf)` → the mod-key array built from
  `spec[\mod]` (factored from the duplicated logic). `~matVariationOverlay` and
  `~matColorStepPattern` call it. `~matPoseFire.(poseId)` reads per-color `pose`.
  `~matMod`, `~matPoseBindings`, and their per-voice OSCdefs/pushes are removed.

- [ ] **Step 1: Write failing tests**

```supercollider
// --- Engine reads per-color mod + per-color pose fire (Task 2) ---
pass = pass and: { ~matModPairs.notNil };
// a color with a cutoff mod -> the produced event has a \cutoff key
~matModCache = IdentityDictionary[ \rHandY -> 1.0 ];
~matColorDefs[5][2][\mod] = (source: \rHandY, target: \cutoff, depth: 1.0);
~ev = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~ev[\cutoff].notNil and: { ~ev[\cutoff] > 3000 } };
~matColorDefs[5][2][\mod] = nil;
// per-voice ~matMod removed
pass = pass and: { ~matMod.isNil };
pass = pass and: { ~matPoseBindings.isNil };
// per-color pose fire: a binding under a color, firing re-sources (no raise)
~matColorDefs[5][3][\pose] = [ (poseId: \poseX, action: \trigger) ];
try { ~matPoseFire.(\poseX) } { |e| pass = false; ("EXC poseFire: " ++ e.class.name).postln };
try { ~matPoseFire.(\unknown) } { |e| pass = false };
~matColorDefs[5][3][\pose] = [];
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Factor `~matModPairs` reading `spec[\mod]`**

Add `~matModPairs` just before `~matVariationOverlay`. Move the CURRENT mod-key
logic (today inside `~matVariationOverlay`/`~matColorStepPattern`, sourced from
`~matMod[vi]`) here, sourced from `spec[\mod]`:

```supercollider
// -- ~matModPairs : capture-effect keys from the color's own mod (spec[\mod]) --
~matModPairs = { |name, spec, volOf|
    var mod = spec[\mod];
    mod.isNil.if({ [] }, {
        var src = mod[\source], tgt = mod[\target], d = mod[\depth];
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            [\cutoff, Pfunc { var s = ~matModSourceVal.(src); c0 * (s.linexp(0,1,200,6000)/c0).pow(d) }]
        }, {
            (tgt == \pan).if({
                [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }]
            }, {
                [\amp, Pfunc { ((spec[\amp] ? 1.0) * volOf.value) * (1 + (d * (~matModSourceVal.(src) * 2 - 1))).max(0) }]
            })
        })
    })
};
```

- [ ] **Step 4: Use `~matModPairs` in both pattern builders**

In `~matVariationOverlay`: delete its inline `var mod = ~matMod[vi]; var modPairs = ...`
block and replace with `var modPairs = ~matModPairs.(name, spec, volOf);`. In
`~matColorStepPattern`: same — replace its inline `modPairs` (which excluded amp;
now the helper handles amp too — fine for stepped) with `var modPairs =
~matModPairs.(name, spec, volOf);`. Keep both builders' key order otherwise identical.

- [ ] **Step 5: Remove per-voice mod/pose state + OSCdefs; rewrite `~matPoseFire`**

Delete the `~matMod` and `~matPoseBindings` initializers, the `~matSetMod`/
`~matApplyMod`/`~matModPush`/`~matSetPoseBind`/`~matPosesPush` functions, and the
OSCdefs `\mat_mod`, `\mat_posebind`, `\mat_poses_get` (the old per-voice ones).
Rewrite `~matPoseFire` to iterate per-color:

```supercollider
~matPoseFire = { |poseId|
    var pid = poseId.asSymbol;
    ~matVoices.do { |name, vi|
        var key = ("lp_" ++ name).asSymbol;
        (1..6).do { |color|
            ((~matColorDefs[vi][color][\pose]) ? []).do { |b|
                (b[\poseId] == pid).if({
                    (b[\action] == \trigger).if({
                        Pdef.all.includesKey(key).if({
                            var pat = ~matVariation.(name, color, vi);
                            pat.notNil.if({ Pdef(key, pat); Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) })
                        })
                    });
                    (b[\action] == \gate).if({
                        Pdef.all.includesKey(key).if({ Pdef(key).isPlaying.if({ Pdef(key).stop }, { Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) }) })
                    });
                })
            }
        }
    }
};
```

(The `/matrix/pose` OSCdef calling `~matPoseFire` stays.)

- [ ] **Step 6: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 7: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: engine reads per-color mod and pose"
```

---

### Task 3: SC persistence + legacy migration

**Files:** Modify `sound_algo/data_only/matrix.scd` (`~matSave`, `~matLoadFile`); Test `test_matrix.scd`

**Interfaces:** colorDefs Events round-trip `mod`+`pose`; legacy top-level `mods`/
`poseBindings` migrate into per-color on load.

- [ ] **Step 1: Write failing tests**

```supercollider
// --- Per-color mod/pose persistence + migration (Task 3) ---
~matSetColorMod.(4, 3, \rHandY, \amp, 0.5);
~matSetColorPose.(4, 3, \poseM, \gate);
~matSave.("cp grid");
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
pass = pass and: { ~matLoad.("cp grid") };
pass = pass and: { ~matColorDefs[4][3][\mod][\target] == \amp };
pass = pass and: { ~matColorDefs[4][3][\pose][0][\poseId] == \poseM };
File.delete(~matDir +/+ "cp_grid.matrix");
// legacy migration: a saved Event with top-level mods + poseBindings
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
File.use(~matDir +/+ "legc.matrix", "w", { |f| f.write((
    grid: Array.fill(16, { Array.fill(32, 0) }),
    mods: Array.fill(16, \none).put(4, [\rHandY, \cutoff, 0.6]),
    poseBindings: Array.fill(16, []).put(4, [ [\poseL, \trigger, 3] ])
).asCompileString) });
pass = pass and: { ~matLoad.("legc") };
pass = pass and: { ~matColorDefs[4][1][\mod][\target] == \cutoff };   // voice mod -> all colors
pass = pass and: { ~matColorDefs[4][3][\pose][0][\poseId] == \poseL }; // pose -> its color
File.delete(~matDir +/+ "legc.matrix");
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Extend the load allow-list + add migration**

In `~matLoadFile`'s colorDefs restore loop, after copying `steps`, copy `mod` and
`pose`:
```supercollider
                    (d[\mod].notNil).if({ ~matColorDefs[vi][ci + 1][\mod] = d[\mod] });
                    (d[\pose].notNil and: { d[\pose].isArray }).if({ ~matColorDefs[vi][ci + 1][\pose] = d[\pose] });
```
After the colorDefs block, add legacy migration (only when the new per-color fields
were absent, i.e. a legacy save):
```supercollider
            // migrate legacy per-voice mods -> all colors; poseBindings -> their color
            ((raw.isArray.not) and: { raw[\mods].notNil }).if({
                raw[\mods].do { |m, vi|
                    (m != \none and: { m.isArray and: { m.size == 3 } and: { vi < ~matVoices.size } }).if({
                        (1..6).do { |c| ~matColorDefs[vi][c][\mod] = (source: m[0], target: m[1], depth: m[2]) }
                    })
                }
            });
            ((raw.isArray.not) and: { raw[\poseBindings].notNil }).if({
                raw[\poseBindings].do { |list, vi|
                    (list.isArray and: { vi < ~matVoices.size }).if({
                        list.do { |b| (b.isArray and: { b.size == 3 }).if({
                            var c = b[2].asInteger.clip(1, 6);
                            ~matColorDefs[vi][c][\pose] = ~matColorDefs[vi][c][\pose] ++ [ (poseId: b[0], action: b[1]) ]
                        }) }
                    })
                }
            });
```
`~matSave` needs no change for mod/pose (nested in colorDefs Events, already
serialized) — but REMOVE the now-dead top-level `mods:`/`poseBindings:` keys from
the `~matSave` payload (they no longer exist as `~matMod`/`~matPoseBindings`).

- [ ] **Step 4: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: persist and migrate per-color mod pose"
```

---

### Task 4: Web color-centric modal + persistence

**Files:** Modify `web_realart/public/control/index.html`, `control.js`, `control.css`

**Interfaces:** Consumes `/matrix/colormod`, `/matrix/colorpose`, `/matrix/colordefs/get/ext`,
`/matrix/instrument`, `/matrix/colordef`, `/matrix/step`. Produces a color selector +
per-color pattern editor; `matColorDefs[vi][color]` JS mirror gains `mod`+`pose`+`steps`.

- [ ] **Step 1: Modal markup (index.html)** — replace the tabbed `#colordef-modal`
internals with a color selector + a single pattern pane:

```html
<div id="colordef-modal" class="cd-modal" hidden>
  <div class="cd-panel">
    <div class="cd-head"><span id="cd-title">voice</span>
      <button id="cd-audition" class="cd-aud">AUDITION</button>
      <button id="cd-close" class="cd-close">X</button></div>
    <div id="cd-colorsel" class="cd-colorsel"></div>
    <div id="cd-pattern" class="cd-pattern"></div>
  </div>
</div>
```

- [ ] **Step 2: JS state + color selector + pattern editor**

Fold `matSteps`/`matMod`/`matPoses` into `matColorDefs[vi][color]` (each gains
`mod:{source,target,depth}|null`, `pose:[{poseId,action}]`, `steps:[16]`). Add
`let cdColor = 1;`. Build `renderColorSel(vi)` (6 tinted buttons setting `cdColor`
then `renderPattern(vi)`) and `renderPattern(vi)` showing, for `matColorDefs[vi][cdColor]`:
instrument select (→ `/matrix/colordef vi cdColor inst v`), variation controls
(stretch/octave/amp/cutoff/pan → `/matrix/colordef`), a 16-step row (→ `/matrix/step
vi cdColor s deg vel`, rest deg=-99), effect (source/target/depth → `/matrix/colormod
vi cdColor ...`), pose (poseId+action+add list → `/matrix/colorpose vi cdColor ...`).
`openColorDef(vi)` sets `cdColor=1`, renders both, and sends `/matrix/colordefs/get`,
`/matrix/steps/get`, `/matrix/colordefs/get/ext`. (Reuse the existing step
cell/wheel handlers and the inst/variation control builders, retargeted to `cdColor`.)

- [ ] **Step 3: WS handlers for /matrix/colormod + /matrix/colorpose**

```javascript
  if (address === "/matrix/colormod") {
    const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1]));
    if (vi>=0&&vi<16&&c>=1&&c<=6) {
      const src=String(args[2]??"none");
      matColorDefs[vi][c].mod = (src==="none") ? null : {source:src, target:String(args[3]??"none"), depth:Number(args[4])||0};
      saveMatState();
      if (cdEditVoice===vi && cdColor===c && !document.getElementById("colordef-modal").hidden) renderPattern(vi);
    }
    return;
  }
  if (address === "/matrix/colorpose") {
    const vi=Math.round(Number(args[0])), c=Math.round(Number(args[1])), n=Math.round(Number(args[2]));
    if (vi>=0&&vi<16&&c>=1&&c<=6) {
      matColorDefs[vi][c].pose = [];
      for (let k=0;k<n;k++){ const b=3+k*2; matColorDefs[vi][c].pose.push({poseId:String(args[b]),action:String(args[b+1])}); }
      saveMatState();
      if (cdEditVoice===vi && cdColor===c && !document.getElementById("colordef-modal").hidden) renderPattern(vi);
    }
    return;
  }
```
Remove the old `/matrix/mod(s)` and `/matrix/poses` WS handlers.

- [ ] **Step 4: Persistence — fold into cdef**

`saveMatState` stores `{ grid, inst, cdef: matColorDefs }` (cdef now carries
mod/pose/steps per color); drop the separate `mod`/`steps`/`pose` keys.
`loadMatState` restores `cdef` and tolerates legacy `{grid,inst,mod,cdef}` (ignore
the old top-level mod/steps/pose keys). Default-guard `matColorDefs[vi][c].mod`
(may be undefined in old cache) in `renderPattern`.

- [ ] **Step 5: Restore the per-row LIVE instrument select (left of each matrix row)**

For fast live access, re-add a per-voice instrument `<select>` on the LEFT of each
matrix row (it was removed when controls moved into the modal). It sets the VOICE
DEFAULT instrument (`~matInstruments[vi]`, used by any color whose own `inst` is
nil) — per-color overrides stay in the modal. In `renderMatrix`'s voice-row loop,
after the `.mvoice-label` (before the `.minst-edit` "..." button), insert:

```javascript
    const vinst = document.createElement("select");
    vinst.className = "minst"; vinst.dataset.vi = vi;
    [["default","default"]].concat((MATRIX_INST_CHOICES[MATRIX_VOICES[vi]]||[]).map(s=>[s,s]))
      .forEach(([val,txt])=>{const o=document.createElement("option");o.value=val;o.textContent=txt;vinst.appendChild(o);});
    vinst.value = matInst[vi] || "default";
    vinst.addEventListener("change", ()=>{ matInst[vi]=vinst.value; saveMatState(); send("/matrix/instrument", vi, vinst.value); });
    row.appendChild(vinst);
```

Re-add the header spacer so bar numbers stay aligned: in the header-row build, after
the voice-label corner, append `const ih=document.createElement("span"); ih.className="minst-head"; headerRow.appendChild(ih);` and restore the `.minst`/`.minst-head` CSS (sticky-left, 78px). Keep `matInst[vi]` in sync from the existing `/matrix/instrument` WS handler (update the row select by `.minst[data-vi]`).

- [ ] **Step 6: CSS + verify**

`.cd-colorsel { display:flex; gap:4px; margin:6px 0; } .cd-colorsel button.on { outline:2px solid #fff; } .cd-pattern { display:flex; flex-direction:column; gap:6px; }`
plus restore `.minst { position:sticky; left:54px; z-index:2; width:78px; font-size:10px; background:#1a1a1a; color:#ccc; border:1px solid #333; flex-shrink:0; }` and `.minst-head { width:78px; flex-shrink:0; }`, and reuse `.seq-*`/`.cd-*` rules. Run `node --check`. Manual: the row-left instrument select changes the voice default live; the color selector switches the pattern; editing a color's instrument/variation/sequence/effect/pose only affects that color and round-trips; audition cycles colors.

- [ ] **Step 6: Commit**

```bash
git add web_realart/public/control/index.html web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: web color-centric pattern editor"
```

---

## Self-Review

**Spec coverage:** per-color mod+pose state -> Task 1. Engine reads spec[\mod] +
~matModPairs DRY -> Task 2 Steps 3-4. Per-color pose fire -> Task 2 Step 5. Remove
per-voice ~matMod/~matPoseBindings -> Task 2 Step 5. Persistence + legacy migration
-> Task 3. Color-centric modal (selector + per-color pattern: inst/variation/seq/
effect/pose) -> Task 4. Parity (empty mod/pose = today) -> Task 1 defaults + Task 2
~matModPairs nil branch. OSC contract (/matrix/colormod, /matrix/colorpose) -> Task
1 + Task 4. ✓

**Placeholder scan:** complete code in each SC step; Task 4 web reuses existing
control builders (named: step cell/wheel handlers, inst/variation builders) which
exist on the branch — the step says "reuse", not "implement later". ✓

**Type consistency:** `~matSetColorMod.(vi,color,source,target,depth)` /
`~matSetColorPose.(vi,color,poseId,action)` / `~matModPairs.(name,spec,volOf)`
consistent across Tasks 1-2. `/matrix/colormod` (vi,color,src,tgt,depth) and
`/matrix/colorpose` (vi,color,n,(poseId,action)*) identical SC push ↔ JS decode
(Task 1/Task 4). `matColorDefs[vi][c].{mod,pose,steps}` shape consistent SC↔JS. ✓
