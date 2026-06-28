# Matrix Capture→Effect Modulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per matrix voice, bind a body-capture source (hand height/openness/speed, body height, depth) to a per-voice effect parameter (cutoff/amp/pan) with a depth amount, so movement modulates that instrument live; persist bindings in the named `.matrix` presets.

**Architecture:** A self-contained capture cache (`~matModCache`, fed by this
feature's own OSCdefs on `/pose/hands` + `/pose/center`) exposes normalized 0..1
scalars via `~matModSourceVal`. A per-voice `~matMod[vi]` binding `(source,target,
depth)` injects the target key (`\cutoff`/`\amp`/`\pan`) into the `~matVariation`
overlay as a `Pfunc`, sampled per note. The `.matrix` Event format (established by
the instrument-selection plan) gains a `mods` field. Web adds sticky-right per-row
source/target/depth controls.

**Tech Stack:** SuperCollider (sclang), vanilla browser JS, CSS sticky positioning, Node `node:test`.

## Dependencies & coordination precondition

- **Depends on `2026-06-28-matrix-instrument-selection.md` being implemented
  first** — it establishes the `.matrix` Event format `(grid:, instruments:)` (this
  plan adds `mods:`), the extended `~matVariation` overlay, and the sticky-column
  CSS pattern. Implement that plan, then this one.
- Same coordination precondition: do not start until the parallel "matrix presets"
  feature is frozen/merged.

## Global Constraints

- SC env vars lowercase `~xxx`; comments English; no emojis. — sound_algo/CLAUDE.md
- `.scd` edits keep `awk` balance `P:0 B:0`. — sound_algo/CLAUDE.md
- No audio-graph / SynthDef / `Out.ar` changes; no `server.js` change. — design spec
- Modulation is per-event (note-on sampled); within-note continuous is out of scope. — design spec
- Targets curated per voice by SynthDef args: `amp` all voices; `cutoff` acid/arp/
  lead/stab/pad; `pan` acid/arp/lead/stab. Invalid target for a voice → ignored. — design spec
- Depth `d` in 0..1; source `s` in 0..1. cutoff: `c0 * (s.linexp(0,1,200,6000)/c0)**d`;
  amp multiplier `(1 + d*(s*2-1)).max(0)`; pan `(s*2-1)*d`. — design spec
- `\matGlow` stays the FIRST overlay key; any mod `\amp` is appended AFTER the
  variation `\amp`. — design spec
- `.matrix` stays backward-compatible: files without `mods` default to no bindings. — design spec
- Commit subject <= 50 chars, no underscore in scope, no AI attribution. — CLAUDE.md

---

### Task 1: Capture cache + source readers

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (state + `~matModCache` OSCdefs + `~matModSourceVal`)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matModCache` (IdentityDictionary of latest normalized scalars),
  `~matModSources` (array of valid source symbols), `~matModSourceVal.(key)` →
  Float 0..1 (clamped), reading `~matModCache` with safe neutral defaults.

- [ ] **Step 1: Confirm the `/pose/hands` arg order**

Read `sound_algo/data_only/data_feeds.scd` around the `/pose/hands` OSCdef
(~line 502) and confirm the payload order. The design assumes
`[tag, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]` → in an OSCdef `msg`,
`msg[1]=tag, msg[2]=lx, msg[3]=ly, msg[4]=lopen, msg[5]=lspeed, msg[6]=rx,
msg[7]=ry, msg[8]=ropen, msg[9]=rspeed, msg[10]=dist`. If the existing handler maps
differently, adjust the indices in Step 4 to match it. Note the actual mapping in
your report.

- [ ] **Step 2: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Capture mod sources (Task 1) ---
pass = pass and: { ~matModSourceVal.notNil and: { ~matModSources.notNil } };
~matModCache = IdentityDictionary[ \rHandY -> 1.5, \rOpen -> -0.2, \handSpeed -> 0.6 ];
pass = pass and: { ~matModSourceVal.(\rHandY) == 1.0 };     // clamped to 1
pass = pass and: { ~matModSourceVal.(\rOpen) == 0.0 };      // clamped to 0
pass = pass and: { ~matModSourceVal.(\handSpeed) == 0.6 };
pass = pass and: { ~matModSourceVal.(\unknownKey) == 0.0 }; // safe default
```

- [ ] **Step 3: Run to verify failure** — Expected `TEST FAIL` (`~matModSourceVal` undefined).

- [ ] **Step 4: Add the cache, source list, OSCdefs, and reader**

Add to `matrix.scd` (state near the other init; functions near the helpers; OSCdefs
near the others):

```supercollider
~matModCache   = ~matModCache ? IdentityDictionary.new;
~matModSources = ~matModSources ?
    [\lHandY, \rHandY, \lOpen, \rOpen, \handSpeed, \handDist, \bodyY, \depth];

// reader: clamp to 0..1, default 0 when absent
~matModSourceVal = { |key| (~matModCache[key] ? 0).clip(0, 1) };

// own capture listeners (independent of the pose pipeline's internal dicts)
OSCdef(\mat_mod_hands, { |msg|
    ~matModCache[\lHandY]    = 1 - (msg[3] ? 0.5);   // image y top-down -> up=1
    ~matModCache[\rHandY]    = 1 - (msg[7] ? 0.5);
    ~matModCache[\lOpen]     = msg[4] ? 0;
    ~matModCache[\rOpen]     = msg[8] ? 0;
    ~matModCache[\handSpeed] = ((msg[5] ? 0) max: (msg[9] ? 0));
    ~matModCache[\handDist]  = msg[10] ? 0;
}, '/pose/hands');

OSCdef(\mat_mod_center, { |msg|
    ~matModCache[\bodyY] = 1 - (msg[3] ? 0.5);       // /pose/center [pid, cx, cy]
}, '/pose/center');

OSCdef(\mat_mod_span, { |msg|
    ~matModCache[\depth] = ((msg[2] ? 0) * 2.5).clip(0, 1);  // /pose/sho_span depth proxy
}, '/pose/sho_span');
```

(Adjust `msg` indices per Step 1 if the existing handlers differ.)

- [ ] **Step 5: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 6: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: matrix capture mod source cache"
```

---

### Task 2: Per-voice mod bindings + overlay injection

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matMod`, `~matModTargets`,
  `~matModNeutralCut`, `~matApplyMod`, `~matVariation` overlay, OSCdef)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matMod` (16 entries nil or `(source:,target:,depth:)`),
  `~matModTargets` (voiceName→[Symbol]), `~matApplyMod.(vi, srcOrNil, tgtOrNil, depth)`.
- Consumes: `~matModSourceVal` (Task 1), `~matVariation`, `~matApplyBar`.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Mod bindings (Task 2) ---
pass = pass and: { ~matMod.notNil and: { ~matMod.size == 16 } };
pass = pass and: { ~matMod.every({ |x| x.isNil }) };
pass = pass and: { ~matModTargets.notNil };

~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matApplyMod.(5, \rHandY, \cutoff, 0.7);            // acid -> cutoff ok
pass = pass and: { ~matMod[5].notNil and: { ~matMod[5][\target] == \cutoff } };
pass = pass and: { ~trigLog[0] == "/matrix/mod" and: { ~trigLog[1] == 5 } };

~matMod[0] = nil;
~matApplyMod.(0, \rHandY, \cutoff, 0.7);            // kick has no cutoff -> rejected
pass = pass and: { ~matMod[0].isNil };

~matModCache = IdentityDictionary[ \rHandY -> 1.0 ];
~matMod[5] = (source: \rHandY, target: \cutoff, depth: 1.0);
~trigLog2 = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~trigLog2[\cutoff].notNil and: { ~trigLog2[\cutoff] > 3000 } };  // hand up opens filter
~matVoices.size.do { |i| ~matMod[i] = nil };
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add state + targets + neutral cutoffs**

```supercollider
~matMod = ~matMod ? Array.fill(~matVoices.size, nil);
~matModTargets = ~matModTargets ? IdentityDictionary[
    \kick->[\amp], \hats->[\amp], \clap->[\amp], \perc->[\amp],
    \sub->[\amp], \acid->[\amp,\cutoff,\pan], \arp->[\amp,\cutoff,\pan],
    \lead->[\amp,\cutoff,\pan], \stab->[\amp,\cutoff,\pan], \pad->[\amp,\cutoff],
    \ride->[\amp], \rim->[\amp], \tom->[\amp], \reese->[\amp],
    \bells->[\amp], \sweep->[\amp]
];
~matModNeutralCut = ~matModNeutralCut ? IdentityDictionary[
    \acid->700, \arp->3000, \lead->4000, \stab->2200, \pad->1500
];
```

- [ ] **Step 4: Add `~matApplyMod`**

```supercollider
~matApplyMod = { |vi, srcOrNil, tgtOrNil, depth|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var src = ((srcOrNil == \none) or: { srcOrNil.isNil }).if({ nil }, { srcOrNil.asSymbol });
        var tgt = ((tgtOrNil == \none) or: { tgtOrNil.isNil }).if({ nil }, { tgtOrNil.asSymbol });
        var d = (depth ? 0).asFloat.clip(0, 1);
        var ok = (src.isNil or: tgt.isNil) or: {
            ~matModSources.includes(src) and: { (~matModTargets[name] ? []).includes(tgt) }
        };
        ok.if({
            ~matMod[vi] = (src.isNil or: tgt.isNil).if({ nil },
                { (source: src, target: tgt, depth: d) });
            ~matLastColor[vi] = -1;
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~toscSend !? { ~toscSend.("/matrix/mod", vi,
                (src ? \none).asString, (tgt ? \none).asString, d) }
        })
    })
};
```

- [ ] **Step 5: Extend `~matVariation` overlay with the mod target key**

In `~matVariation`, after the `\instrument` key added by the instrument-selection
plan, append a single mod key computed from `~matMod[vi]`. Because the key name is
dynamic (cutoff/amp/pan), build the overlay Pbind args conditionally. Replace the
overlay construction so a mod binding contributes its target key:

```supercollider
        var mod = ~matMod[vi];
        var modPairs = mod.isNil.if({ [] }, {
            var src = mod[\source], tgt = mod[\target], d = mod[\depth];
            (tgt == \cutoff).if({
                var c0 = ~matModNeutralCut[name] ? 1000;
                [\cutoff, Pfunc { var s = ~matModSourceVal.(src);
                    c0 * (s.linexp(0,1,200,6000) / c0).pow(d) }]
            }, {
                (tgt == \pan).if({
                    [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }]
                }, {  // amp: multiply the variation amp
                    [\amp, Pfunc { spec[\amp] * (1 + (d * (~matModSourceVal.(src) * 2 - 1))).max(0) }]
                })
            })
        });
        Pchain(
            Pbind(*([
                \matGlow, Pfunc { |e| ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0,1)); 0 },
                \stretch, spec[\stretch], \octave, spec[\octave], \amp, spec[\amp],
                \instrument, Pfunc { ~matInstruments[vi] }
            ] ++ modPairs)),
            base
        )
```

(This replaces the literal `Pbind(...)` from the instrument plan with a
`Pbind(*[...])` spread so the optional mod pair can be appended. The mod `\amp`,
when present, comes after the variation `\amp` and overrides it; `\matGlow` is still
first and reads the base amp.)

- [ ] **Step 6: Add the OSCdef**

```supercollider
OSCdef(\mat_mod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyMod.(msg[1].asInteger, (msg[2] ? \none).asSymbol,
        (msg[3] ? \none).asSymbol, (msg[4] ? 0).asFloat)
}, '/matrix/mod');
```

- [ ] **Step 7: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 8: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: per-voice matrix capture modulation"
```

---

### Task 3: Persist mods in the .matrix format

**Files:**
- Modify: `sound_algo/data_only/matrix.scd` (`~matSave`, `~matLoadFile`, `~matModPush`)
- Test: `sound_algo/data_only/test/test_matrix.scd`

**Interfaces:**
- Produces: `~matModPush` (sends `/matrix/mods`). Extends the `.matrix` Event with a
  `mods` field; load defaults missing/invalid mods to nil.

- [ ] **Step 1: Write failing tests** (append before final `pass.if(`)

```supercollider
// --- Mod persistence (Task 3) ---
pass = pass and: { ~matModPush.notNil };
~matVoices.size.do { |i| ~matMod[i] = nil };
~matApplyMod.(5, \rHandY, \cutoff, 0.5);
~matSave.("mod grid");
~matVoices.size.do { |i| ~matMod[i] = nil };
pass = pass and: { ~matLoad.("mod grid") };
pass = pass and: { ~matMod[5].notNil and: { ~matMod[5][\target] == \cutoff } };
File.delete(~matDir +/+ "mod_grid.matrix");
```

- [ ] **Step 2: Run to verify failure** — `TEST FAIL`.

- [ ] **Step 3: Add `~matModPush`** (after `~matInstrPush`)

```supercollider
// -- ~matModPush : send 16 mod triples (source,target,depth) flattened --
~matModPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/mods"] ++ ~matMod.collect({ |m|
            m.isNil.if({ ["none", "none", 0] },
                { [m[\source].asString, m[\target].asString, m[\depth]] })
        }).flatten)
    }
};
```

- [ ] **Step 4: Add `mods` to `~matSave`** — extend the payload Event:

```supercollider
    var payload = (
        grid: ~lp[\matrix],
        instruments: ~matInstruments.collect({ |x| (x ? \default) }),
        mods: ~matMod.collect({ |m| m.isNil.if({ \none },
            { [m[\source], m[\target], m[\depth]] }) })
    );
```

- [ ] **Step 5: Restore `mods` in `~matLoadFile`** — after the instrument-restore
loop, add a mod-restore loop (guard for legacy files where `raw[\mods]` is nil):

```supercollider
            // restore mods (validate via ~matApplyMod, which rejects invalid)
            ~matVoices.size.do { |i| ~matMod[i] = nil };
            ((raw.isArray.not) and: { raw[\mods].notNil }).if({
                raw[\mods].do { |m, vi|
                    (m != \none and: { m.isArray and: { m.size == 3 } }).if({
                        ~matApplyMod.(vi, m[0], m[1], m[2])
                    })
                }
            });
            ~matModPush.();
```

- [ ] **Step 6: Run tests + balance** → `TEST PASS`, `P:0 B:0`.

- [ ] **Step 7: Commit**

```bash
git add sound_algo/data_only/matrix.scd sound_algo/data_only/test/test_matrix.scd
git commit -m "feat: persist matrix mods in presets"
```

---

### Task 4: Web mod controls (sticky-right) + sync + persistence

**Files:**
- Modify: `web_realart/public/control/control.js` (`renderMatrix` right-side controls; WS handlers; persistence)
- Modify: `web_realart/public/control/control.css` (sticky-right `.mmod` block)

**Interfaces:**
- Consumes: `/matrix/mod <vi> <src> <tgt> <depth>`, `/matrix/mods <48 vals>`,
  `MATRIX_VOICES`, `matInst` persistence pattern (instrument plan).
- Produces: per-row source/target/depth controls, `matMod[16]` state, WS handlers.

- [ ] **Step 1: Add JS source/target tables + state (after `MATRIX_INST_CHOICES`)**

```javascript
const MATRIX_MOD_SOURCES = ["none","lHandY","rHandY","lOpen","rOpen","handSpeed","handDist","bodyY","depth"];
const MATRIX_MOD_TARGETS = {
  kick:["none","amp"], hats:["none","amp"], clap:["none","amp"], perc:["none","amp"],
  sub:["none","amp"], acid:["none","amp","cutoff","pan"], arp:["none","amp","cutoff","pan"],
  lead:["none","amp","cutoff","pan"], stab:["none","amp","cutoff","pan"], pad:["none","amp","cutoff"],
  ride:["none","amp"], rim:["none","amp"], tom:["none","amp"], reese:["none","amp"],
  bells:["none","amp"], sweep:["none","amp"]
};
let matMod = Array.from({length:16}, () => ({source:"none", target:"none", depth:0.5}));
```

- [ ] **Step 2: Extend persistence (`saveMatState`/`loadMatState`) to include `mod`**

```javascript
function saveMatState() {
  try { localStorage.setItem(MATRIX_STORAGE_KEY,
    JSON.stringify({ grid: matGrid, inst: matInst, mod: matMod })); } catch (_e) {}
}
```
In `loadMatState`, after restoring `inst`, add:
`if (Array.isArray(raw.mod) && raw.mod.length === 16) matMod = raw.mod;`

- [ ] **Step 3: Build the right-side controls in `renderMatrix`**

After the cell loop (just before `container.appendChild(row);`, ~L289), append a
mod control group for the voice:

```javascript
    const mod = document.createElement("span");
    mod.className = "mmod";
    const src = document.createElement("select"); src.className = "mmod-src"; src.dataset.vi = vi;
    MATRIX_MOD_SOURCES.forEach(s => { const o=document.createElement("option"); o.value=s; o.textContent=s; src.appendChild(o); });
    const tgt = document.createElement("select"); tgt.className = "mmod-tgt"; tgt.dataset.vi = vi;
    (MATRIX_MOD_TARGETS[MATRIX_VOICES[vi]]||["none","amp"]).forEach(t => { const o=document.createElement("option"); o.value=t; o.textContent=t; tgt.appendChild(o); });
    const dep = document.createElement("input"); dep.type="range"; dep.min=0; dep.max=1; dep.step=0.01;
    dep.className = "mmod-dep"; dep.dataset.vi = vi;
    src.value = matMod[vi].source; tgt.value = matMod[vi].target; dep.value = matMod[vi].depth;
    const sendMod = () => { matMod[vi] = {source:src.value, target:tgt.value, depth:+dep.value};
      saveMatState(); send("/matrix/mod", vi, src.value, tgt.value, +dep.value); };
    src.addEventListener("change", sendMod);
    tgt.addEventListener("change", sendMod);
    dep.addEventListener("change", sendMod);
    mod.appendChild(src); mod.appendChild(tgt); mod.appendChild(dep);
    row.appendChild(mod);
```

- [ ] **Step 4: Add WS handlers (after the `/matrix/instruments` block)**

```javascript
  if (address === "/matrix/mod") {
    const vi = Math.round(Number(args[0]));
    if (vi >= 0 && vi < 16) {
      matMod[vi] = { source:String(args[1]??"none"), target:String(args[2]??"none"), depth:Number(args[3])||0 };
      const r = document.querySelector(`.mmod-src[data-vi="${vi}"]`);
      if (r) { r.value = matMod[vi].source;
        document.querySelector(`.mmod-tgt[data-vi="${vi}"]`).value = matMod[vi].target;
        document.querySelector(`.mmod-dep[data-vi="${vi}"]`).value = matMod[vi].depth; }
      saveMatState();
    }
    return;
  }
  if (address === "/matrix/mods") {   // 16 triples flattened = 48 values
    for (let vi = 0; vi < 16; vi++) {
      const b = vi*3;
      matMod[vi] = { source:String(args[b]??"none"), target:String(args[b+1]??"none"), depth:Number(args[b+2])||0 };
      const r = document.querySelector(`.mmod-src[data-vi="${vi}"]`);
      if (r) { r.value=matMod[vi].source;
        document.querySelector(`.mmod-tgt[data-vi="${vi}"]`).value=matMod[vi].target;
        document.querySelector(`.mmod-dep[data-vi="${vi}"]`).value=matMod[vi].depth; }
    }
    saveMatState();
    return;
  }
```

- [ ] **Step 5: CSS — sticky-right mod block**

```css
.mmod { position: sticky; right: 0; z-index: 2; background: #111;
  display: flex; gap: 2px; align-items: center; flex-shrink: 0; padding-left: 4px; }
.mmod-src, .mmod-tgt { width: 64px; font-size: 9px; background: #1a1a1a; color: #ccc; border: 1px solid #333; }
.mmod-dep { width: 56px; }
```

- [ ] **Step 6: Static verification + manual checklist**

Run: `node --check web_realart/public/control/control.js` → OK.
Manual (capture pipeline live): bind `acid: rHandY → cutoff, depth 0.7`; raise the
right hand and hear the acid filter open in time; confirm the mod block stays pinned
to the right while the grid scrolls; save/reload a preset and confirm bindings restore.

- [ ] **Step 7: Commit**

```bash
git add web_realart/public/control/control.js web_realart/public/control/control.css
git commit -m "feat: web matrix capture mod controls"
```

---

## Self-Review

**Spec coverage:** free source+target+depth per voice → Task 2 (`~matApplyMod`) +
Task 4 (3 controls). Curated targets by synth args → Task 2 `~matModTargets`.
Per-event Pfunc injection → Task 2 Step 5. Depth mappings (cutoff/amp/pan) → Task 2
Step 5 verbatim from spec. Sources from capture → Task 1 cache + readers. Persist in
presets → Task 3 (+ Task 4 localStorage). `\matGlow` first / mod `\amp` after
variation `\amp` → Task 2 Step 5. Backward-compat → Task 3 Step 5 (legacy guard). ✓

**Placeholder scan:** complete code in every step; the only "verify-and-adjust" is
Task 1 Step 1 (confirm real OSC arg order), which guards a concrete assumption, not a
gap. ✓

**Type consistency:** `~matApplyMod.(vi,src,tgt,depth)` defined Task 2, used Task 1/3
tests + OSCdef + load. `/matrix/mod` (single) vs `/matrix/mods` (48-flat bulk)
consistent SC↔web. `matMod[vi] = {source,target,depth}` shape identical across Task 4
steps. `~matModSourceVal`/`~matModCache` consistent Task 1↔2. ✓
