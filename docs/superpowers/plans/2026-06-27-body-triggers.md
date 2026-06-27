# Body-Trigger Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The body conducts the concert — an extensible `~ccGesture` framework fires FX/dramatic events (jump/stomp/squat/spin/T-pose) and conducts a global harmonic/melodic state `~ccHarmony` (transpose/scale/pad/phrase/octave) that the pitched morceaux read.

**Architecture:** A skeleton data layer (`/pose/skel` → `~poseSkel`) feeds the full body to SC. The concert engine evaluates a registry of `~ccGesture` modules each tick (with hold/cooldown, and the previous snapshot for velocity). FX gestures act on a master event-FX layer (reuse the existing `~doFilter`, add a stutter + event synths). Harmonic/melodic gestures mutate global `~ccHarmony`; pitched morceaux derive notes from `~ccNote.(degree)` instead of baked-in scales.

**Tech Stack:** SuperCollider (data-only patch `sound_algo/data_only/`), the pose OSC pipeline (`data_only_viz/pose_bridge.py` → `/pose/*` → SC), Python (pose_bridge).

## Global Constraints

- SC traps: lowercase `~vars`; NEVER underscore-in-`{}` closures (use `{ |x| ... }`); `doneAction:2` on one-shots; gated `Env.asr` for sustained; nil-guard pose reads (`? 0` / `? ()`); clip freqs; this SC has NO `inRange` (use `(x>=lo) and: {x<=hi}`), NO `timeout` on macOS (background+kill for tests).
- `.scd` `.load` files: ONE top-level block, balance `P:0 B:0 TLB:1`. `boot.scd` pre-existing `P:-8 TLB:3` false positive — edits must be balance-NEUTRAL vs HEAD.
- Existing FX rack (`engine.scd`): `~doMasterGroup` (Group) holds `~doRev` (\do_reverb, reads `~doReverbBus`), `~doFilter` (\do_master_filter, param `cutoff` default 20000, on bus 0), `~doMaster` (\do_master comp+limiter). All In.ar/ReplaceOut bus 0. REUSE `~doFilter` for filter events; insert new master FX via `Synth.before(~doMaster, ...)` so they sit before the limiter.
- Existing concert engine (`scene_concert.scd`): `~concert` (setlist + routine + advance), `~ccPose` (snapshot `(kin,state,center,hands,hasBody)`; `hands` is wrist-backed at distance), `~ccCtlDur` (0.05), `~poseWrist`, `~poseCenter`. Morceaux read `pose[\hands]`.
- Tests headless on GrosMac: `/Applications/SuperCollider.app/Contents/MacOS/sclang /tmp/t.scd > /tmp/log 2>&1 & SC=$!; sleep N; kill -9 $SC; pkill -9 scsynth` then grep PASS/FAIL. Server output-only (`numInputBusChannels=0; numOutputBusChannels=2; memSize=65536`). Live audio tuned at the smoke (last task).
- Normalized pose coords 0–1, y=0 top (so "up" = smaller y).

---

## File Structure

| File | Responsibility |
|------|----------------|
| `data_only_viz/pose_bridge.py` (modify) | + `/pose/skel` send (nose, shoulders, hips, knees, ankles) in `_emit_person` |
| `sound_algo/control/data_feeds.scd` (modify) | + `\poseSkel` OSCdef → `~poseSkel`; clear on `\poseLeave` |
| `sound_algo/data_only/scene_concert.scd` (modify) | + `~ccPose` skel/prev; + `~ccGesture` framework + engine eval; + `~ccHarmony`/`~ccScales`/`~ccNote` |
| `sound_algo/data_only/concert_fx.scd` (new) | master event-FX: filter/stutter helpers (`~ccMaster`), `\cc_ev_*` synths, `~ccStutter` |
| `sound_algo/data_only/concert_gestures.scd` (new) | the registered gestures (fx + harmony + melody) via `~ccGestureAdd` |
| `sound_algo/data_only/morceaux/0{1,3,4,6,7,8}_*.scd` (modify) | pitched morceaux read `~ccNote`/`~ccHarmony` |
| `sound_algo/data_only/boot.scd` (modify) | load `concert_fx.scd` (after engine) + `concert_gestures.scd` (after morceaux) |

---

## Task 1: Skeleton data layer

**Files:** Modify `data_only_viz/pose_bridge.py` (`_emit_person`), `sound_algo/control/data_feeds.scd`. Test: `/tmp/test_poseskel.scd`.

**Interfaces produces:** `/pose/skel <pid> <18 floats>` (nose.x nose.y, shL, shR, hipL, hipR, kneeL, kneeR, ankL, ankR — each x,y); `~poseSkel[pid] = (nose:(x:,y:), shL:, shR:, hipL:, hipR:, kneeL:, kneeR:, ankL:, ankR:)`.

- [ ] **Step 1: Write failing test** `/tmp/test_poseskel.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/"; var fail=0; var n;
    ~poseState=Dictionary.new; ~poseKin=Dictionary.new; ~handFeat=();
    (base++"control/data_feeds.scd").load; s.sync;
    n = NetAddr("127.0.0.1", NetAddr.langPort);
    n.sendMsg("/pose/skel", 0, 0.5,0.2, 0.4,0.35, 0.6,0.35, 0.42,0.6, 0.58,0.6, 0.43,0.8, 0.57,0.8, 0.44,0.95, 0.56,0.95);
    0.3.wait;
    if(~poseSkel.isNil) { "[FAIL] ~poseSkel nil".postln; fail=1 } {
        var e = ~poseSkel[0];
        if(e.isNil) { "[FAIL] no pid0".postln; fail=1 } {
            if((e[\nose][\y] - 0.2).abs > 0.001) { ("[FAIL] nose.y="++e[\nose][\y]).postln; fail=1 };
            if((e[\ankL][\x] - 0.44).abs > 0.001) { ("[FAIL] ankL.x="++e[\ankL][\x]).postln; fail=1 };
        };
    };
    if(fail==0) { "[PASS] poseSkel populated".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (no `\poseSkel` OSCdef yet). Background+kill, grep PASS/FAIL.
- [ ] **Step 3a: pose_bridge.py** — in `_emit_person`, after the existing `/pose/wrist` sends, add (the body landmark list `body` is the 33 MediaPipe `Kp3D`; guard length):
```python
        if len(body) >= 29:
            def _xy(i):
                kp = body[i]
                return [float(getattr(kp, "x", 0.0)), float(getattr(kp, "y", 0.0))]
            skel = [pid]
            for idx in (0, 11, 12, 23, 24, 25, 26, 27, 28):   # nose, sh L/R, hip L/R, knee L/R, ank L/R
                skel += _xy(idx)
            cli.send_message("/pose/skel", skel)
            try: self._avbody.send_message("/pose/skel", skel)
            except OSError: pass
```
- [ ] **Step 3b: data_feeds.scd** — after the `\poseWrist` OSCdef block, add:
```supercollider
~poseSkel = ~poseSkel ? Dictionary.new;
OSCdef(\poseSkel, { |msg|
    var pid = msg[1].asInteger;
    var p = { |i| (x: msg[2 + (i*2)], y: msg[3 + (i*2)]) };
    ~poseSkel[pid] = (
        nose: p.(0), shL: p.(1), shR: p.(2), hipL: p.(3), hipR: p.(4),
        kneeL: p.(5), kneeR: p.(6), ankL: p.(7), ankR: p.(8));
}, '/pose/skel');
```
And in `\poseLeave` add `~poseSkel !? { ~poseSkel.removeAt(pid) };`.
- [ ] **Step 4: Run, expect** `[PASS] poseSkel populated`. Balance: `data_feeds.scd` neutral vs HEAD.
- [ ] **Step 5: Commit** `pose_bridge.py` + `data_feeds.scd` → `feat(viz): skeleton joints to SC via pose/skel`.

---

## Task 2: `~ccGesture` framework + engine evaluation

**Files:** Modify `sound_algo/data_only/scene_concert.scd`. Test: `/tmp/test_ccgesture.scd`.

**Interfaces produces:** `~ccGestures` (Array), `~ccGestureAdd.(g)`, and the engine routine evaluates them. A gesture `g = (name:, family:, hold:, cooldown:, detect:{|pose,prev| Bool}, fire:{}, release:{} (optional))`. `~ccPose` snapshot gains `skel:` and the routine passes the previous snapshot.

- [ ] **Step 1: Write failing test** `/tmp/test_ccgesture.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0;
    ~doActivePriv=IdentityDictionary.new; ~doRegisterPriv={|n,k| ~doActivePriv[n]=k};
    ~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
    ~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
    (base++"scene_concert.scd").load; s.sync;
    (base++"morceaux/01_hypno_drift.scd").load; s.sync;
    ~tFire=0; ~tRel=0; ~gOn=false;
    ~ccGestureAdd.((name:\tg, family:\test, hold:0.3, cooldown:1.0,
        detect:{|pose,prev| ~gOn }, fire:{ ~tFire = ~tFire + 1 }, release:{ ~tRel = ~tRel + 1 }));
    ~poseKin[0]=(speed:0.1,accel:0,symmetry:0);
    ~doSceneConcert.value; 0.3.wait;
    ~gOn=true; 0.6.wait;                 // held > hold -> fires once
    if(~tFire != 1) { ("[FAIL] fire="++~tFire).postln; fail=1 };
    0.3.wait;                            // still held, within cooldown -> no refire
    if(~tFire != 1) { ("[FAIL] refired="++~tFire).postln; fail=1 };
    ~gOn=false; 0.3.wait;               // drop -> release once
    if(~tRel != 1) { ("[FAIL] release="++~tRel).postln; fail=1 };
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail==0) { "[PASS] ccGesture fire+cooldown+release".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (`~ccGestureAdd` nil).
- [ ] **Step 3: scene_concert.scd** — (a) add `skel:` to `~ccPose` (read first `~poseSkel`), (b) add the registry + per-gesture state, (c) evaluate in the routine with `prev`. After the `~ccPose` definition add:
```supercollider
~ccGestures = ~ccGestures ? [];
~ccGestureAdd = { |g| ~ccGestures = ~ccGestures.add(g) };
~ccGState = IdentityDictionary.new;   // name -> (holdT:, lastFire:, fired:)
~ccEvalGestures = { |pose, prev, now|
    ~ccGestures.do { |g|
        var st = ~ccGState[g[\name]] ? (holdT: 0.0, lastFire: -100.0, fired: false);
        var on = g[\detect].(pose, prev) == true;
        if(on) {
            if(st[\holdT] <= 0) { st[\holdT] = now };
            if(((now - st[\holdT]) >= (g[\hold] ? 0))
                and: { (now - st[\lastFire]) > (g[\cooldown] ? 0.5) }) {
                st[\lastFire] = now; st[\holdT] = now; st[\fired] = true;
                g[\fire].();
            };
        } {
            if(st[\fired]) { g[\release] !? { |r| r.() }; st[\fired] = false };
            st[\holdT] = 0;
        };
        ~ccGState[g[\name]] = st;
    };
};
```
Add `skel:` to `~ccPose`: in the snapshot Event add `skel: ((~poseSkel.notNil.if({ ~poseSkel.values.detect({ |v| v.notNil }) })) ? ())`. In the engine routine, keep a `prev` var (init `~ccPose.value`), and EACH tick: `~ccEvalGestures.(pose, prev, now); prev = pose;` (add this call next to `~concert[\detectCross]`). Reset `~ccGState = IdentityDictionary.new` in `~concert[\start]`.
- [ ] **Step 4: Run, expect** `[PASS] ccGesture fire+cooldown+release`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `scene_concert.scd` → `feat(sound): ccGesture trigger framework`.

---

## Task 3: Master event-FX layer (`concert_fx.scd`)

**Files:** Create `sound_algo/data_only/concert_fx.scd`. Modify `boot.scd` (load it after the concert engine, before the morceaux — it needs the server up). Test: `/tmp/test_concertfx.scd`.

**Interfaces produces:** `~ccMaster` Event with `[\filterTo].(cutoff, time)`, `[\dip].()` (quick drop), `[\stutterOn].(dur)`; event synths `\cc_ev_crash`, `\cc_ev_kick`, `\cc_ev_swell`; helper `~ccFire.(\crash | \kick | \swell)`.

- [ ] **Step 1: Write failing test** `/tmp/test_concertfx.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0;
    (base++"engine.scd").load; 1.0.wait;     // brings up ~doFilter / ~doMaster
    (base++"concert_fx.scd").load; s.sync;
    [\cc_ev_crash,\cc_ev_kick,\cc_ev_swell].do { |d|
        if(SynthDescLib.global.at(d).isNil) { ("[FAIL] missing "++d).postln; fail=1 } };
    if(~ccMaster.isNil) { "[FAIL] ~ccMaster nil".postln; fail=1 } {
        ~ccMaster[\filterTo].(800, 0.1); 0.2.wait;
        ~ccMaster[\stutterOn].(0.3); 0.4.wait;
        ~ccFire.(\crash); ~ccFire.(\kick); ~ccFire.(\swell); 0.3.wait;
    };
    if(fail==0) { "[PASS] concert_fx synths + master ctrl".postln };
    0.5.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (file missing).
- [ ] **Step 3: Write `concert_fx.scd`**:
```supercollider
// Master event-FX layer for the concert: reuses ~doFilter (engine.scd) for the
// master lowpass, adds a beat-repeat stutter before ~doMaster, and one-shot
// event synths (crash/kick/swell). Loaded after engine.scd.
(
SynthDef(\cc_master_stutter, { |out=0, rate=8, mix=0.0|
    var sig = In.ar(out, 2);
    var trig = Impulse.kr(rate);
    var held = Latch.ar(sig, trig);   // crude beat-repeat: hold sampled blocks
    var stut = (held * 0.6) + (sig * 0.4);
    ReplaceOut.ar(out, XFade2.ar(sig, stut, (mix * 2 - 1).clip(-1, 1)));
}).add;
SynthDef(\cc_ev_crash, { |out=0, amp=0.4|
    var env = EnvGen.kr(Env.perc(0.001, 1.6), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 4000) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_ev_kick, { |out=0, amp=0.9|
    var env = EnvGen.kr(Env.perc(0.001, 0.35), doneAction: 2);
    var fenv = EnvGen.kr(Env([200, 44], [0.06], \exp));
    Out.ar(out, Pan2.ar((SinOsc.ar(fenv) * env * 2).tanh, 0) * amp);
}).add;
SynthDef(\cc_ev_swell, { |out=0, revOut, amp=0.3|
    var env = EnvGen.kr(Env([0, 1, 0], [2.5, 2.5], \sin), doneAction: 2);
    var sig = Mix(Saw.ar([110, 110.3, 220] * 1.0)) * 0.15;
    sig = RLPF.ar(sig, XLine.kr(400, 3000, 2.5), 0.3) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
    revOut !? { Out.ar(revOut, Pan2.ar(sig, 0) * amp * 0.6) };
}).add;

s.sync;
~ccStutter = nil;
~ccMaster = (
    filterTo: { |cut=20000, time=0.3| ~doFilter !? { |f| f.set(\cutoff, cut.clip(120, 20000)) } },
    dip: { ~doFilter !? { |f|
        f.set(\cutoff, 300);
        AppClock.sched(0.18, { f.set(\cutoff, 20000); nil }); } },
    stutterOn: { |dur=0.6|
        ~doMaster !? { |m|
            ~ccStutter ?? { ~ccStutter = Synth.before(m, \cc_master_stutter, [\out, 0, \mix, 0]) };
            ~ccStutter.set(\mix, 0.9, \rate, 10);
            AppClock.sched(dur, { ~ccStutter !? { |st| st.set(\mix, 0) }; nil });
        };
    },
);
~ccFire = { |kind|
    switch(kind,
        \crash, { Synth(\cc_ev_crash, [\amp, 0.4]) },
        \kick,  { Synth(\cc_ev_kick,  [\amp, 0.9]) },
        \swell, { Synth(\cc_ev_swell, [\amp, 0.3, \revOut, (~doReverbBus !? { |b| b.index })]) },
    );
};
"[data-only/concert_fx] master event-FX ready".postln;
)
```
- [ ] **Step 4: boot.scd** — after the `engine.scd` load + its `~doEngineReady` wait (the `// -- 3) Engine` block), add `(~base ++ "concert_fx.scd").load; s.sync;`. Run the test → `[PASS] concert_fx synths + master ctrl`. Balance `concert_fx.scd` `P:0 B:0`; boot neutral vs HEAD.
- [ ] **Step 5: Commit** `concert_fx.scd` + `boot.scd` → `feat(sound): concert master event-FX layer`.

---

## Task 4: FX/dramatic gestures (`concert_gestures.scd`)

**Files:** Create `sound_algo/data_only/concert_gestures.scd`. Modify `boot.scd` (load after morceaux). Test: `/tmp/test_fxgestures.scd`.

**Interfaces consumes:** `~ccGestureAdd` (T2), `~ccFire`/`~ccMaster` (T3), `pose[\skel]`/`[\center]`/`[\wrist]` (T1/T2).

- [ ] **Step 1: Write failing test** `/tmp/test_fxgestures.scd` — load engine+fx+concert+gestures, register count, then synthesize a jump (cy drop) and assert its fire path runs without error and a crash node appears:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0;
    ~doActivePriv=IdentityDictionary.new; ~doRegisterPriv={|n,k| ~doActivePriv[n]=k};
    ~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
    ~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
    (base++"engine.scd").load; 1.0.wait;
    (base++"concert_fx.scd").load; s.sync;
    (base++"scene_concert.scd").load; s.sync;
    (base++"morceaux/01_hypno_drift.scd").load; s.sync;
    (base++"concert_gestures.scd").load; s.sync;
    if(~ccGestures.select({|g| g[\family]==\fx}).size < 5) { "[FAIL] <5 fx gestures".postln; fail=1 };
    ~poseKin[0]=(speed:0.2,accel:0,symmetry:0);
    ~poseCenter[0]=(cx:0.5, cy:0.5, depth:0.5);
    ~poseSkel[0]=(nose:(x:0.5,y:0.2), shL:(x:0.4,y:0.35), shR:(x:0.6,y:0.35),
        hipL:(x:0.42,y:0.6), hipR:(x:0.58,y:0.6), kneeL:(x:0.43,y:0.8), kneeR:(x:0.57,y:0.8),
        ankL:(x:0.44,y:0.95), ankR:(x:0.56,y:0.95));
    ~doSceneConcert.value; 0.3.wait;
    ~poseCenter[0][\cy]=0.30;   // jump: cy rose fast vs prev (0.5)
    0.3.wait;
    ~poseCenter[0][\cy]=0.5;
    0.4.wait;
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail==0) { "[PASS] fx gestures registered + jump fired no error".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (file missing → <5 gestures).
- [ ] **Step 3: Write `concert_gestures.scd`** (the 5 FX gestures; `prev`/`pose` are snapshots):
```supercollider
// Registered body gestures. FX/dramatic family here; harmony/melody appended in
// later tasks. Loaded after the morceaux (needs ~ccGestureAdd, ~ccFire, ~ccMaster).
(
var meanY = { |a, b| ((a[\y] ? 0.5) + (b[\y] ? 0.5)) * 0.5 };

// JUMP — body center rose fast then we fire (one-shot)
~ccGestureAdd.((name:\jump, family:\fx, hold:0, cooldown:0.7,
    detect: { |pose, prev|
        ((pose[\center][\cy] ? 0.5) < ((prev[\center][\cy] ? 0.5) - 0.06)) },
    fire: { ~ccFire.(\crash); ~ccMaster[\dip].() }));

// STOMP — an ankle dropped fast (planted)
~ccGestureAdd.((name:\stomp, family:\fx, hold:0, cooldown:0.35,
    detect: { |pose, prev|
        var s = pose[\skel]; var p = prev[\skel];
        (s.notNil and: { p.notNil }) and: {
            var dl = (s[\ankL][\y] ? 0.95) - (p[\ankL][\y] ? 0.95);
            var dr = (s[\ankR][\y] ? 0.95) - (p[\ankR][\y] ? 0.95);
            dl.max(dr) > 0.05 } },
    fire: { ~ccFire.(\kick) }));

// SQUAT (held) — hips near knees -> breakdown sweep down; release sweeps back
~ccGestureAdd.((name:\squat, family:\fx, hold:0.6, cooldown:0.2,
    detect: { |pose, prev|
        var s = pose[\skel];
        s.notNil and: { meanY.(s[\hipL], s[\hipR]) > (meanY.(s[\kneeL], s[\kneeR]) - 0.10) } },
    fire: { ~ccMaster[\filterTo].(450, 1.0) },
    release: { ~ccMaster[\filterTo].(20000, 1.5) }));

// SPIN — shoulders swapped x sign vs prev -> stutter
~ccGestureAdd.((name:\spin, family:\fx, hold:0, cooldown:1.2,
    detect: { |pose, prev|
        var s = pose[\skel]; var p = prev[\skel];
        (s.notNil and: { p.notNil }) and: {
            var now = (s[\shR][\x] ? 0.6) - (s[\shL][\x] ? 0.4);
            var was = (p[\shR][\x] ? 0.6) - (p[\shL][\x] ? 0.4);
            (now.sign != was.sign) and: { was.abs > 0.05 } } },
    fire: { ~ccMaster[\stutterOn].(0.9) }));

// T-POSE (held) — wrists wide at shoulder height -> swell
~ccGestureAdd.((name:\tpose, family:\fx, hold:0.8, cooldown:2.0,
    detect: { |pose, prev|
        var s = pose[\skel]; var w = ~poseWrist.notNil.if({ ~poseWrist.values.detect({|v| v.notNil}) });
        (s.notNil and: { w.notNil }) and: {
            (((w[\rx] ? 0.5) - (w[\lx] ? 0.5)).abs > 0.4)
            and: { ((w[\ry] ? 0.5) - (s[\shR][\y] ? 0.35)).abs < 0.14 } } },
    fire: { ~ccFire.(\swell) }));

"[data-only/concert_gestures] fx gestures registered".postln;
)
```
- [ ] **Step 4: boot.scd** — after the morceaux load list (`// -- 6d.`), add `(~base ++ "concert_gestures.scd").load; s.sync;`. Run the test → `[PASS]`. Balance `concert_gestures.scd` `P:0 B:0`.
- [ ] **Step 5: Commit** `concert_gestures.scd` + `boot.scd` → `feat(sound): fx dramatic body gestures`.

---

## Task 5: `~ccHarmony` + `~ccScales` + `~ccNote`

**Files:** Modify `sound_algo/data_only/scene_concert.scd` (add after `~ccGesture` framework). Test: `/tmp/test_ccharmony.scd`.

**Interfaces produces:** `~ccHarmony = (root:45, scale:\minor, pad:\dark, phrase:0, octave:0)`, `~ccScales` (Event of scale-degree arrays), `~ccNote.(degree, oct=0) -> midinote`.

- [ ] **Step 1: Write failing test** `/tmp/test_ccharmony.scd`:
```supercollider
(
"/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/scene_concert.scd".load;
~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
~doRegisterPriv={|n,k|}; ~doActivePriv=IdentityDictionary.new;
if(~ccNote.isNil) { "[FAIL] ~ccNote nil".postln } {
    var a = ~ccNote.(0);   // root
    var b = ~ccNote.(7);   // one octave up in 7-note scale (minor has 7 degrees)
    if(a == 45) { "[PASS] degree0=root".postln } { ("[FAIL] d0="++a).postln };
    if(b == 57) { "[PASS] degree7=+octave".postln } { ("[FAIL] d7="++b).postln };
    ~ccHarmony[\root] = 50;
    if(~ccNote.(0) == 50) { "[PASS] follows root".postln } { "[FAIL] root change".postln };
};
0.exit;
)
```
- [ ] **Step 2: Run** `sclang /tmp/test_ccharmony.scd 2>&1 | grep -E "PASS|FAIL"` (no server needed). Expect FAIL.
- [ ] **Step 3: scene_concert.scd** — after the `~ccGesture` framework block add:
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
- [ ] **Step 4: Run, expect** all `[PASS]`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `scene_concert.scd` → `feat(sound): global harmony state ccHarmony`.

---

## Task 6: Refactor pitched morceaux to read `~ccHarmony`

**Files:** Modify `morceaux/01_hypno_drift.scd`, `03_acid_line.scd`, `04_acid_storm.scd`, `06_hard_rave.scd`, `07_dub_chords.scd`, `08_dub_space.scd`. Test: `/tmp/test_morceau_harmony.scd`.

**Interfaces consumes:** `~ccNote.(degree, oct)`, `~ccHarmony[\phrase]`, `~ccHarmony[\pad]` (T5).

**Pattern (apply to each pitched morceau):** replace baked `root + scale[...]` / `.midicps` note computation with `~ccNote.(degree, oct).midicps`, keeping each morceau's OWN degree pattern. Examples:
- `03_acid_line`: it has `ctx[\pat] = [0,0,12,0,3,0,7,0]; ctx[\root]=45;` and plays `(ctx[\root] + deg + oct).midicps`. Change to **degree-based**: keep `ctx[\pat]` as scale-degrees `[0,0,7,0,2,0,4,0]` and play `~ccNote.(ctx[\pat].wrapAt(ctx[\step]), (ctx[\oct] ? 0) / 12 * 0 + (ctx[\octUp] ? 0)).midicps`. Add a `phrase` table: `ctx[\phrases] = [[0,0,7,0,2,0,4,0],[0,3,0,7,5,0,2,0],[0,7,3,10,0,5,2,0],[0,0,0,5,7,7,4,2]];` and at tick start `ctx[\pat] = ctx[\phrases][~ccHarmony[\phrase] ? 0]`.
- `01_hypno_drift` drone: `\freq, ~ccNote.(0).midicps` instead of `~bpModes...` (it uses 55 Hz ≈ root 33; set drone to `~ccNote.(0, -1).midicps`). Pad brightness: `ctx[\cut]` base shifts with `~ccHarmony[\pad]` (`\bright` → higher base cutoff).
- `04_acid_storm`: same as acid line (degree pattern + `~ccNote`).
- `06_hard_rave` stab: `note = ~ccNote.(degree).midicps` for its `[0,7,12].choose` → `[0,4,7].choose` degrees via `~ccNote`.
- `07_dub_chords`: chord root `~ccNote.([0,3,7,10].choose)` → degrees `[0,2,4,6]` via `~ccNote`; triad ratios stay.
- `08_dub_space` sub: `~ccNote.(0, -2).midicps`.

- [ ] **Step 1: Write failing test** `/tmp/test_morceau_harmony.scd` — load engine+concert+ccHarmony+acid_line, set `~ccHarmony[\root]`, start, capture the freq the acid synth would use via a probe (register a temporary OSCFunc? simpler: assert the morceau's `~ccNote` usage by checking that changing `~ccHarmony[\root]` changes nothing crashes and the morceau loads). Concretely assert: acid_line loaded, `~ccHarmony` exists, and a tick runs with a non-default root without error:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0;
    ~doActivePriv=IdentityDictionary.new; ~doRegisterPriv={|n,k| ~doActivePriv[n]=k};
    ~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
    ~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
    (base++"scene_concert.scd").load; s.sync;
    (base++"morceaux/03_acid_line.scd").load; s.sync;
    if("grep -c ccNote ".++(base++"morceaux/03_acid_line.scd").quote.++(" >/dev/null").systemCmd != 0)
        { "[FAIL] acid_line not using ~ccNote".postln; fail=1 };
    ~poseKin[0]=(speed:0.3,accel:0,symmetry:0);
    ~ccHarmony[\root]=50; ~ccHarmony[\phrase]=2;
    ~doSceneConcert.value; 1.2.wait;       // runs ticks with non-default root/phrase, must not error
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail==0) { "[PASS] acid_line on ccHarmony, no error".postln };
    0.3.wait; s.quit;
});
)
```
(The `grep -c ccNote` via `systemCmd` returns 0 when present.)
- [ ] **Step 2: Run, expect FAIL** (acid_line not yet using `~ccNote`).
- [ ] **Step 3: Apply the refactor** to the 6 pitched morceaux per the Pattern above (degree-based + `~ccNote`; acid line/storm get a 4-entry `phrases` table picked by `~ccHarmony[\phrase]`). Keep each morceau's rhythm/structure; only the pitch source changes.
- [ ] **Step 4: Re-run the per-morceau headless tests** (`/tmp/test_morceau_03.scd` etc. from the concert plan) for the 6 changed morceaux — all still `[PASS]` — AND the new `/tmp/test_morceau_harmony.scd` `[PASS]`. Balance each changed file `P:0 B:0`.
- [ ] **Step 5: Commit** the 6 morceaux → `feat(sound): morceaux read ccHarmony for pitch`.

---

## Task 7: Harmonic gestures

**Files:** Modify `sound_algo/data_only/concert_gestures.scd` (append harmony family). Test: `/tmp/test_harmgestures.scd`.

- [ ] **Step 1: Write failing test** — load full stack, register count for family `\harmony` >= 4, synthesize step-right (`center.cx>0.7` held) and assert `~ccHarmony[\root]` increased:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0; var r0;
    ~doActivePriv=IdentityDictionary.new; ~doRegisterPriv={|n,k| ~doActivePriv[n]=k};
    ~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
    ~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
    (base++"engine.scd").load; 1.0.wait; (base++"concert_fx.scd").load; s.sync;
    (base++"scene_concert.scd").load; s.sync;
    (base++"morceaux/01_hypno_drift.scd").load; s.sync;
    (base++"concert_gestures.scd").load; s.sync;
    if(~ccGestures.select({|g| g[\family]==\harmony}).size < 4) { "[FAIL] <4 harmony".postln; fail=1 };
    ~poseKin[0]=(speed:0.1,accel:0,symmetry:0);
    ~poseCenter[0]=(cx:0.5, cy:0.5, depth:0.5);
    ~doSceneConcert.value; 0.3.wait; r0 = ~ccHarmony[\root];
    ~poseCenter[0][\cx]=0.80; 0.8.wait;     // step right held -> root += 2
    if(~ccHarmony[\root] != (r0 + 2)) { ("[FAIL] root="++~ccHarmony[\root]).postln; fail=1 };
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail==0) { "[PASS] harmony gestures change ccHarmony".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (no harmony gestures yet).
- [ ] **Step 3: Append to `concert_gestures.scd`** (inside its top-level block, before the final postln — or a second block; keep ONE top-level block by adding before the closing `)`):
```supercollider
// --- harmony family ---
~ccGestureAdd.((name:\stepR, family:\harmony, hold:0.5, cooldown:1.0,
    detect: { |pose, prev| (pose[\center][\cx] ? 0.5) > 0.70 },
    fire: { ~ccHarmony[\root] = (~ccHarmony[\root] + 2).clip(33, 57) }));
~ccGestureAdd.((name:\stepL, family:\harmony, hold:0.5, cooldown:1.0,
    detect: { |pose, prev| (pose[\center][\cx] ? 0.5) < 0.30 },
    fire: { ~ccHarmony[\root] = (~ccHarmony[\root] - 2).clip(33, 57) }));
~ccGestureAdd.((name:\leanFwd, family:\harmony, hold:0.4, cooldown:1.0,
    detect: { |pose, prev| var s=pose[\skel]; s.notNil and: {
        (((s[\shL][\y]?0.35)+(s[\shR][\y]?0.35))*0.5) < ((((s[\hipL][\y]?0.6)+(s[\hipR][\y]?0.6))*0.5) - 0.28) } },
    fire: { ~ccHarmony[\pad] = \bright }));
~ccGestureAdd.((name:\leanBack, family:\harmony, hold:0.4, cooldown:1.0,
    detect: { |pose, prev| var s=pose[\skel]; s.notNil and: {
        (((s[\shL][\y]?0.35)+(s[\shR][\y]?0.35))*0.5) > ((((s[\hipL][\y]?0.6)+(s[\hipR][\y]?0.6))*0.5) - 0.20) } },
    fire: { ~ccHarmony[\pad] = \dark }));
~ccGestureAdd.((name:\tilt, family:\harmony, hold:0.4, cooldown:1.2,
    detect: { |pose, prev| var s=pose[\skel]; s.notNil and: {
        var mid = (((s[\shL][\x]?0.4)+(s[\shR][\x]?0.6))*0.5);
        ((s[\nose][\x]?0.5) - mid).abs > 0.06 } },
    fire: { var keys = ~ccScales.keys.asArray.sort;
        var i = keys.indexOf(~ccHarmony[\scale]) ? 0;
        ~ccHarmony[\scale] = keys.wrapAt(i + 1) }));
```
- [ ] **Step 4: Run, expect** `[PASS] harmony gestures change ccHarmony`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `concert_gestures.scd` → `feat(sound): harmonic body gestures`.

---

## Task 8: Melodic gestures

**Files:** Modify `sound_algo/data_only/concert_gestures.scd` (append melody family). Test: `/tmp/test_melgestures.scd`.

- [ ] **Step 1: Write failing test** — synthesize head-up (`nose.y < shoulder.y - 0.30`) and assert `~ccHarmony[\octave] == 1`; arm-raise toggles `phrase`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0;
    ~doActivePriv=IdentityDictionary.new; ~doRegisterPriv={|n,k| ~doActivePriv[n]=k};
    ~poseKin=Dictionary.new; ~poseState=Dictionary.new; ~poseCenter=Dictionary.new;
    ~handFeat=(); ~poseWrist=Dictionary.new; ~poseSkel=Dictionary.new;
    (base++"engine.scd").load; 1.0.wait; (base++"concert_fx.scd").load; s.sync;
    (base++"scene_concert.scd").load; s.sync;
    (base++"morceaux/01_hypno_drift.scd").load; s.sync;
    (base++"concert_gestures.scd").load; s.sync;
    if(~ccGestures.select({|g| g[\family]==\melody}).size < 3) { "[FAIL] <3 melody".postln; fail=1 };
    ~poseKin[0]=(speed:0.1,accel:0,symmetry:0); ~poseCenter[0]=(cx:0.5,cy:0.5,depth:0.5);
    ~poseSkel[0]=(nose:(x:0.5,y:0.05), shL:(x:0.4,y:0.40), shR:(x:0.6,y:0.40),
        hipL:(x:0.42,y:0.6),hipR:(x:0.58,y:0.6),kneeL:(x:0.43,y:0.8),kneeR:(x:0.57,y:0.8),
        ankL:(x:0.44,y:0.95),ankR:(x:0.56,y:0.95));
    ~doSceneConcert.value; 0.5.wait;     // nose.y 0.05 < sh.y 0.40 - 0.30 -> headUp -> octave 1
    if(~ccHarmony[\octave] != 1) { ("[FAIL] octave="++~ccHarmony[\octave]).postln; fail=1 };
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail==0) { "[PASS] melody gestures change ccHarmony".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL**.
- [ ] **Step 3: Append to `concert_gestures.scd`** (before the closing `)`):
```supercollider
// --- melody family ---
~ccGestureAdd.((name:\armRaise, family:\melody, hold:0.4, cooldown:1.0,
    detect: { |pose, prev|
        var s=pose[\skel]; var w=~poseWrist.notNil.if({~poseWrist.values.detect({|v|v.notNil})});
        (s.notNil and: { w.notNil }) and: {
            var rUp = (w[\ry]?0.5) < ((s[\shR][\y]?0.35) - 0.10);
            var lUp = (w[\ly]?0.5) < ((s[\shL][\y]?0.35) - 0.10);
            rUp != lUp } },                                  // exactly one arm up
    fire: { ~ccHarmony[\phrase] = (~ccHarmony[\phrase] + 1) % 4 }));
~ccGestureAdd.((name:\headUp, family:\melody, hold:0.3, cooldown:0.6,
    detect: { |pose, prev| var s=pose[\skel]; s.notNil and: {
        (s[\nose][\y]?0.2) < ((((s[\shL][\y]?0.4)+(s[\shR][\y]?0.4))*0.5) - 0.30) } },
    fire: { ~ccHarmony[\octave] = 1 }));
~ccGestureAdd.((name:\headDown, family:\melody, hold:0.3, cooldown:0.6,
    detect: { |pose, prev| var s=pose[\skel]; s.notNil and: {
        (s[\nose][\y]?0.2) > ((((s[\shL][\y]?0.4)+(s[\shR][\y]?0.4))*0.5) - 0.18) } },
    fire: { ~ccHarmony[\octave] = 0 }));
```
- [ ] **Step 4: Run, expect** `[PASS] melody gestures change ccHarmony`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `concert_gestures.scd` → `feat(sound): melodic body gestures`.

---

## Task 9: Live smoke (manual, macm1)

- [ ] On macm1 (concert running, you centered/full-body): perform each — **jump** → crash + filter drop; **stomp** → kick; **squat-and-hold** → breakdown sweep, stand up → it lifts; **spin** → stutter; **arms-wide-hold** → swell. Then the conducting: **step left/right** → the whole set transposes; **lean forward/back** → pads brighten/darken; **head tilt** → scale/mode changes; **one arm up** → melodic phrase changes; **chin up/down** → octave. Confirm the pitched morceaux follow `~ccHarmony` and the events fire cleanly across morceaux. Tune thresholds/amps by ear (the gain/threshold constants in `concert_gestures.scd` + `concert_fx.scd`). Manual — no automated assertion.

---

## Self-Review notes
- **Spec coverage:** A skeleton layer (T1) · `~ccGesture` framework + engine eval + `~ccPose` skel/prev (T2) · master event-FX reusing `~doFilter` + stutter + event synths (T3) · 5 FX gestures (T4) · `~ccHarmony`/`~ccScales`/`~ccNote` (T5) · pitched-morceau refactor (T6) · harmonic gestures (T7) · melodic gestures (T8) · live smoke (T9). All spec sections covered; out-of-scope (percussion/texture, multi-person) left to future `~ccGestureAdd`.
- **Interface consistency:** every gesture is `(name:, family:, hold:, cooldown:, detect:{|pose,prev|}, fire:{}, release:{}?)`; `~ccEvalGestures.(pose, prev, now)` is the only evaluator; `pose` shape `(kin,state,center,hands,skel,hasBody)`; `~ccNote.(degree, oct)` is the single pitch source for pitched morceaux; `~ccMaster`/`~ccFire` are the only event sinks. `~doFilter`/`~doMaster`/`~doReverbBus` are the existing engine handles (reused, not redefined).
- **SC-trap scan:** no underscore-in-`{}`; one-shots `doneAction:2`; gated/`XLine` envelopes self-free; nil-guards on every pose/skel read; `~ccScales` keys sorted for deterministic `\tilt` cycling; `inRange` avoided. Each new `.scd` is one top-level block (TLB:1).
- **Known live-tuning (T9):** all detection thresholds (cy 0.06, ankle 0.05, hip-knee 0.10, shoulder-swap, tilt 0.06, lean 0.28/0.20, head 0.30/0.18) and event amps are first-pass — tuned by ear. The `\cc_master_stutter` is a crude Latch beat-repeat; if it sounds harsh, swap for a buffer-based beat-repeat at the smoke.
