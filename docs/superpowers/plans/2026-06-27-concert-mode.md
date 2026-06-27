# Concert Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A body-driven techno concert — a sequential setlist of 8 custom-mapped morceaux (hard/dub/acid/hypnotic), advanced by an arms-crossed gesture, played by the iPhone-tracked body through SuperCollider.

**Architecture:** A `~concert` engine (setlist + crossfade + gesture detector + lifecycle) runs a control Routine on a TempoClock; each morceau is a self-contained `.load` file that registers a uniform module `(name, style, start, update, tick, stop)` via `~concertAdd` and `.add`s its own `\cc_*` SynthDefs. Engine reads a per-tick pose snapshot (`~poseKin`/`~poseState`/`~poseCenter`/`~handFeat`) and calls the current morceau's `update`/`tick`; `stop` releases via gated envelopes for the crossfade.

**Tech Stack:** SuperCollider (sclang + scsynth), the existing data-only patch (`sound_algo/data_only/`), the live pose OSC pipeline (`/pose/*` → SC vars).

## Global Constraints

- SC traps (MANDATORY): lowercase `~vars` only (uppercase parses as CLASSNAME); NEVER `{ _ / n }` underscore-in-`{}` closure (it builds a function-returning-function → MustBeBooleanError; use explicit `{ |x| x / n }` or `coll / n`); `doneAction: 2` on every one-shot envelope; sustained voices (drones, acid, dub chords, subs) use a gated `Env.asr`/`Env.adsr` so `update`/`stop` can `.set(\gate, 0)` to release+free; nil-guard every pose read (`? 0`, `? ()`); clip frequencies before `.midicps`/oscillators.
- Every `.scd` file edited is `.load`-ed → must be ONE top-level `(...)` block: balance `P:0 B:0 TLB:1` (run the awk check; confirm via sclang `.load`). NOTE: `boot.scd` has a pre-existing `P:-8 TLB:3` false positive from parens in French comments — confirm your edit is balance-NEUTRAL vs HEAD, not absolute zero.
- Stereo out into the global FX rack: `Out.ar(0, Pan2.ar(sig, pan) * amp)`. Do not add reverb/limiter per-synth — the engine FX rack on `out=0` handles it.
- Morceau SynthDef names are prefixed `\cc_<short>_*` (e.g. `\cc_drift_drone`). Module isolation: all live synths/counters live in the `ctx` Event the engine passes; no globals from a morceau.
- Tests: headless `sclang` runs LOCALLY on GrosMac (`/Applications/SuperCollider.app/Contents/MacOS/sclang`). Each test is a `/tmp/*.scd` script that boots a server output-only (`s.options.numInputBusChannels = 0; s.options.numOutputBusChannels = 2`), loads the file(s), and posts `[PASS]`/`[FAIL]`. Grep the output. The live audio smoke (Task 9) runs on macm1 with the iphone-usb stack.
- Pose signal reference (already populated by `control/data_feeds.scd` OSCdefs, per pid): `~poseKin[pid]=(speed:,accel:,symmetry:)`, `~poseState[pid]=(labelIdx:,probs:)`, `~handFeat=(lx:,ly:,lopen:,lspeed:,rx:,ry:,ropen:,rspeed:)` (normalized 0–1; y=0 top so hands HIGH = small ry/ly). `~poseCenter` is added in Task 1.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `sound_algo/control/data_feeds.scd` (modify) | + OSCdef `\poseCenter` (`/pose/center`) and depth from `/pose/sho_span` → `~poseCenter` |
| `sound_algo/data_only/scene_concert.scd` (new) | the `~concert` engine: setlist, snapshot, gesture, crossfade, lifecycle, `~doSceneConcert`, `~concertAdd` |
| `sound_algo/data_only/morceaux/01_hypno_drift.scd` … `08_dub_space.scd` (new) | one self-contained morceau each: its `\cc_*` SynthDefs + its module via `~concertAdd` |
| `sound_algo/data_only/scenes.scd` (modify) | + `\concert` case → `~doSceneConcert.value` |
| `sound_algo/data_only/boot.scd` (modify) | load `scene_concert.scd` then `morceaux/NN_*.scd` in order, with `s.sync` |

---

## Task 1: Engine + `~poseCenter` + first morceau (Hypno Drift)

**Files:**
- Modify: `sound_algo/control/data_feeds.scd` (add `\poseCenter` OSCdef near the other `\pose*` OSCdefs ~line 466–505)
- Create: `sound_algo/data_only/scene_concert.scd`
- Create: `sound_algo/data_only/morceaux/01_hypno_drift.scd`
- Modify: `sound_algo/data_only/scenes.scd` (the `~doScene` switch ~line 311–322)
- Modify: `sound_algo/data_only/boot.scd` (load section ~line 159–161)
- Test: `/tmp/test_concert_engine.scd`

**Interfaces:**
- Produces: `~concert` (Event with `[\start]`, `[\stop]`, `[\next]`, `[\morceaux]`), `~concertAdd` (`{ |m| ... }` appends a module), `~ccPose` (`{ -> (kin:,state:,center:,hands:,hasBody:) }`), `~ccCtlDur` (0.05, control tick in beats), `~doSceneConcert`. Every morceau module is `(name:, style:, start:{|ctx|}, update:{|ctx,pose|}, tick:{|ctx,pose,beat|} (optional), stop:{|ctx|})`.
- Consumes: `~poseKin`, `~poseState`, `~handFeat` (data_feeds.scd), `~doRegisterPriv` (scenes.scd).

- [ ] **Step 1: Write the failing test** — `/tmp/test_concert_engine.scd`

```supercollider
(
s = Server.local;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.memSize = 65536;
s.waitForBoot({
    var base = "/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/";
    var fail = 0;
    // minimal lifecycle stub so scene_concert can register
    ~doActivePriv = IdentityDictionary.new;
    ~doRegisterPriv = { |name, killFn| ~doActivePriv[name] = killFn };
    // pose vars the engine reads
    ~poseKin = Dictionary.new; ~poseState = Dictionary.new;
    ~poseCenter = Dictionary.new; ~handFeat = ();
    (base ++ "scene_concert.scd").load;
    s.sync;
    if(~concert.isNil) { "[FAIL] ~concert nil".postln; fail = 1 };
    if(~concertAdd.isNil) { "[FAIL] ~concertAdd nil".postln; fail = 1 };
    if(~doSceneConcert.isNil) { "[FAIL] ~doSceneConcert nil".postln; fail = 1 };
    (base ++ "morceaux/01_hypno_drift.scd").load;
    s.sync;
    if(~concert[\morceaux].size != 1) {
        ("[FAIL] expected 1 morceau, got " ++ ~concert[\morceaux].size).postln; fail = 1
    };
    // start the concert; simulate a body present
    ~poseKin[0] = (speed: 0.1, accel: 0, symmetry: 0);
    ~poseState[0] = (labelIdx: 1, probs: [0,1,0]);
    ~handFeat = (rx: 0.5, ry: 0.3, lx: 0.5, ly: 0.3, ropen: 0.5, lopen: 0.5, rspeed: 0, lspeed: 0);
    ~doSceneConcert.value;
    0.4.wait;
    if(~concert[\running] != true) { "[FAIL] concert not running".postln; fail = 1 };
    // simulate arms crossed held > 1.5s -> gesture fires (clamps at last morceau, logs)
    ~handFeat[\rx] = 0.30; ~handFeat[\lx] = 0.70;   // R left of L
    2.0.wait;
    // teardown via doStopAll-style kill
    ~doActivePriv[\concert].value;
    0.2.wait;
    if(~concert[\running] != false) { "[FAIL] concert still running after kill".postln; fail = 1 };
    if(fail == 0) { "[PASS] concert engine + 1 morceau + lifecycle".postln };
    0.5.wait; s.quit;
});
)
```

- [ ] **Step 2: Run to verify it fails**

`/Applications/SuperCollider.app/Contents/MacOS/sclang /tmp/test_concert_engine.scd 2>&1 | grep -E "PASS|FAIL|ERROR"`
Expected: FAIL / error (scene_concert.scd and the morceau don't exist).

- [ ] **Step 3a: Add `~poseCenter` OSCdef in `data_feeds.scd`**

Right after the `\poseHands` OSCdef (the `/pose/hands` block ~line 499–505), add:

```supercollider
~poseCenter = ~poseCenter ? Dictionary.new;
OSCdef(\poseCenter, { |msg|
    var pid = msg[1].asInteger;
    var e = ~poseCenter[pid] ? ();
    e[\cx] = msg[2]; e[\cy] = msg[3];
    ~poseCenter[pid] = e;
}, '/pose/center');
OSCdef(\poseShoSpan, { |msg|
    var pid = msg[1].asInteger;
    var e = ~poseCenter[pid] ? ();
    e[\depth] = msg[2];   // shoulder span proxy: bigger = closer
    ~poseCenter[pid] = e;
}, '/pose/sho_span');
```

(Keep `~poseCenter` cleared on `\poseLeave` too: in the existing `\poseLeave` OSCdef add `~poseCenter.removeAt(pid);`.)

- [ ] **Step 3b: Write `scene_concert.scd`** (the engine)

```supercollider
// =====================================================================
//  data_only/scene_concert.scd -- moteur de concert (setlist techno).
//  Setlist sequentielle, geste bras-croises = morceau suivant, crossfade.
//  Active via ~doScene.(\concert). Les morceaux s'enregistrent via
//  ~concertAdd depuis morceaux/NN_*.scd (charges apres ce fichier).
// =====================================================================
(
~ccCtlDur   = 0.05;   // periode du tick de controle, en BEATS
~ccCrossHold = 1.5;   // duree de maintien du geste bras-croises (s)
~ccCrossCool = 3.0;   // cooldown apres declenchement (s)

// -- snapshot pose (premiere personne), tout nil-garde --
~ccPose = {
    var kin = ~poseKin.notNil.if({ ~poseKin.values.detect({ |v| v.notNil }) });
    var st  = ~poseState.notNil.if({ ~poseState.values.detect({ |v| v.notNil }) });
    var ctr = ~poseCenter.notNil.if({ ~poseCenter.values.detect({ |v| v.notNil }) });
    (kin: (kin ? ()), state: (st ? ()), center: (ctr ? ()),
     hands: (~handFeat ? ()), hasBody: kin.notNil);
};

// -- registre des morceaux --
~concert = ~concert ? ();
~concert[\morceaux] = [];
~concertAdd = { |m| ~concert[\morceaux] = ~concert[\morceaux].add(m) };

~concert[\running]  = false;
~concert[\idx]      = 0;
~concert[\clock]    = nil;
~concert[\routine]  = nil;
~concert[\ctx]      = nil;       // (m: module, ctx: scratch) du morceau courant
~concert[\crossT]   = 0.0;
~concert[\lastFire] = -100.0;

~concert[\startMorceau] = { |i|
    var m = ~concert[\morceaux][i];
    var ctx = ();
    m[\start].(ctx);
    ~concert[\ctx] = (m: m, ctx: ctx);
    ("[concert] " ++ (i + 1) ++ "/" ++ ~concert[\morceaux].size
        ++ " : " ++ m[\name]).postln;
};

~concert[\stopMorceau] = {
    ~concert[\ctx] !? { |c| c[\m][\stop].(c[\ctx]) };
    ~concert[\ctx] = nil;
};

~concert[\next] = {
    if(~concert[\idx] < (~concert[\morceaux].size - 1)) {
        ~concert[\stopMorceau].();              // fade out (stop releve les gates)
        ~concert[\idx] = ~concert[\idx] + 1;
        ~concert[\startMorceau].(~concert[\idx]);  // fade in
    } {
        "[concert] derniere piste (fin de set)".postln;
    };
};

// geste bras-croises : main D a gauche de main G, a mi-hauteur, maintenu
~concert[\detectCross] = { |pose, now|
    var hf = pose[\hands];
    var crossed = pose[\hasBody] and: {
        ((hf[\rx] ? 0.5) < ((hf[\lx] ? 0.5) - 0.08))
        and: { (hf[\ry] ? 0).inRange(0.25, 0.75) }
        and: { (hf[\ly] ? 0).inRange(0.25, 0.75) }
    };
    if(crossed) {
        if(~concert[\crossT] <= 0) { ~concert[\crossT] = now };
        if(((now - ~concert[\crossT]) >= ~ccCrossHold)
            and: { (now - ~concert[\lastFire]) > ~ccCrossCool }) {
            ~concert[\lastFire] = now;
            ~concert[\crossT] = 0;
            ~concert[\next].();
        };
    } { ~concert[\crossT] = 0 };
};

~concert[\start] = {
    if(~concert[\running]) { "[concert] deja en cours".postln } {
        if(~concert[\morceaux].size < 1) {
            "[concert] aucun morceau enregistre".warn;
        } {
            ~concert[\running] = true;
            ~concert[\idx] = 0;
            ~concert[\clock] = TempoClock(126/60).permanent_(true);
            ~concert[\startMorceau].(0);
            ~concert[\routine] = Routine({
                var beat = 0;
                inf.do {
                    var pose = ~ccPose.value;
                    var now = thisThread.seconds;
                    var c;
                    ~concert[\detectCross].(pose, now);
                    c = ~concert[\ctx];          // relire (next a pu permuter)
                    c !? { |cc|
                        cc[\m][\update].(cc[\ctx], pose);
                        cc[\m][\tick] !? { |t| t.(cc[\ctx], pose, beat) };
                    };
                    beat = beat + 1;
                    ~ccCtlDur.wait;
                };
            }).play(~concert[\clock]);
            "[concert] STARTED".postln;
        };
    };
};

~concert[\stop] = {
    ~concert[\routine] !? { |r| r.stop };
    ~concert[\stopMorceau].();
    ~concert[\clock] !? { |c| c.stop };
    ~concert[\clock] = nil;
    ~concert[\running] = false;
    "[concert] STOPPED".postln;
};

~doSceneConcert = {
    ~concert[\start].();
    ~doRegisterPriv.(\concert, { ~concert[\stop].() });
};

"[data-only/scene_concert] engine ready".postln;
)
```

- [ ] **Step 3c: Write `morceaux/01_hypno_drift.scd`** (template morceau)

```supercollider
// Morceau 1 -- Hypno Drift (hypnotic). Drone filtre + sub pulse + kick sparse.
// mains hautes -> ouvre le filtre ; cx -> pan ; kick lent quand corps present.
(
SynthDef(\cc_drift_drone, { |out=0, freq=55, cutoff=300, amp=0.0, pan=0, gate=1|
    var sig = Mix(Saw.ar(freq * [1, 1.003, 0.5])) * 0.25;
    sig = RLPF.ar(sig, cutoff.clip(100, 6000), 0.4);
    sig = sig * EnvGen.kr(Env.asr(3, 1, 4), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp.lag(1.0));
}).add;
SynthDef(\cc_drift_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 200)) * LFPulse.kr(0.5, 0, 0.35);
    sig = sig * EnvGen.kr(Env.asr(0.5, 1, 1), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.5));
}).add;
SynthDef(\cc_drift_kick, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.001, 0.4), doneAction: 2);
    var fenv = EnvGen.kr(Env([120, 45], [0.08], \exp));
    var sig = SinOsc.ar(fenv) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Hypno Drift", style: \hypnotic,
    start: { |ctx|
        ctx[\drone] = Synth(\cc_drift_drone, [\freq, 55, \cutoff, 300, \amp, 0.22]);
        ctx[\sub]   = Synth(\cc_drift_sub,   [\freq, 55, \amp, 0.18]);
        ctx[\cut]   = 300; ctx[\pan] = 0;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var ctr = pose[\center];
        var hi = (1 - (((hf[\ry] ? 1) + (hf[\ly] ? 1)) * 0.5)).clip(0, 1);
        var tgt = hi.linexp(0, 1, 250, 4500);
        var panT = ((ctr[\cx] ? 0.5) * 2 - 1).clip(-1, 1);
        ctx[\cut] = ctx[\cut] + ((tgt - ctx[\cut]) * 0.05);
        ctx[\pan] = ctx[\pan] + ((panT - ctx[\pan]) * 0.05);
        ctx[\drone].set(\cutoff, ctx[\cut], \pan, ctx[\pan]);
    },
    tick: { |ctx, pose, beat|
        if(((beat % (0.5 / ~ccCtlDur).round.max(1)) == 0) and: { pose[\hasBody] }) {
            Synth(\cc_drift_kick, [\amp, 0.5]);
        };
    },
    stop: { |ctx|
        ctx[\drone] !? { |s| s.set(\gate, 0) };
        ctx[\sub]   !? { |s| s.set(\gate, 0) };
    },
));
"[morceau] Hypno Drift loaded".postln;
)
```

- [ ] **Step 3d: Add the `\concert` case in `scenes.scd`**

In the `~doScene` switch (after the `\play, { ~doScenePlay.value },` case ~line 321) add:
```supercollider
        \concert, { ~doSceneConcert.value },
```

- [ ] **Step 3e: Load in `boot.scd`**

After the body-play engine load (`scene_pose_play.scd`, ~line 160–161), add:
```supercollider
    // -- 6d. Concert engine + morceaux -----
    (~base ++ "scene_concert.scd").load;
    0.3.wait;
    [
        "morceaux/01_hypno_drift.scd",
    ].do { |f| (~base ++ f).load; 0.1.wait; };
    s.sync;
```
(Each later morceau task appends its filename to this list.)

- [ ] **Step 4: Run the test to verify it passes**

`/Applications/SuperCollider.app/Contents/MacOS/sclang /tmp/test_concert_engine.scd 2>&1 | grep -E "PASS|FAIL|ERROR"`
Expected: `[PASS] concert engine + 1 morceau + lifecycle`. Also run the balance check on the 3 new/edited `.scd` (scene_concert.scd, morceaux/01_hypno_drift.scd: `P:0 B:0 TLB:1`; data_feeds.scd/scenes.scd: balance-neutral vs HEAD).

- [ ] **Step 5: Commit**

```bash
git add sound_algo/control/data_feeds.scd sound_algo/data_only/scene_concert.scd \
        sound_algo/data_only/morceaux/01_hypno_drift.scd \
        sound_algo/data_only/scenes.scd sound_algo/data_only/boot.scd
git commit -m "feat(sound): concert engine + hypno drift morceau"
```

---

## Task 2: Morceau 2 — Hypno Roll (hypnotic)

**Files:**
- Create: `sound_algo/data_only/morceaux/02_hypno_roll.scd`
- Modify: `sound_algo/data_only/boot.scd` (append `"morceaux/02_hypno_roll.scd"` to the load list)
- Test: `/tmp/test_morceau_advance.scd`

**Interfaces:** Consumes `~concertAdd`, `~ccCtlDur`, `~concert` (Task 1). Produces a 2nd registered morceau → enables testing the crossfade advance (morceau 1 → 2).

- [ ] **Step 1: Write the failing test** — `/tmp/test_morceau_advance.scd`

```supercollider
(
s = Server.local; s.options.numInputBusChannels = 0; s.options.numOutputBusChannels = 2;
s.options.memSize = 65536;
s.waitForBoot({
    var base = "/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/";
    var fail = 0;
    ~doActivePriv = IdentityDictionary.new;
    ~doRegisterPriv = { |name, killFn| ~doActivePriv[name] = killFn };
    ~poseKin = Dictionary.new; ~poseState = Dictionary.new;
    ~poseCenter = Dictionary.new; ~handFeat = ();
    (base ++ "scene_concert.scd").load; s.sync;
    [ "morceaux/01_hypno_drift.scd", "morceaux/02_hypno_roll.scd" ].do { |f|
        (base ++ f).load; s.sync;
    };
    if(~concert[\morceaux].size != 2) {
        ("[FAIL] expected 2 morceaux, got " ++ ~concert[\morceaux].size).postln; fail = 1 };
    ~poseKin[0] = (speed: 0.2, accel: 0, symmetry: 0);
    ~handFeat = (rx: 0.5, ry: 0.3, lx: 0.5, ly: 0.3, ropen: 0.5, lopen: 0.5, rspeed: 0, lspeed: 0);
    ~doSceneConcert.value; 0.4.wait;
    if(~concert[\idx] != 0) { "[FAIL] not starting at idx 0".postln; fail = 1 };
    ~handFeat[\rx] = 0.30; ~handFeat[\lx] = 0.70;   // arms crossed
    2.0.wait;                                        // hold > 1.5s
    if(~concert[\idx] != 1) { ("[FAIL] did not advance, idx=" ++ ~concert[\idx]).postln; fail = 1 };
    ~doActivePriv[\concert].value; 0.2.wait;
    if(fail == 0) { "[PASS] advance morceau 1 -> 2".postln };
    0.5.wait; s.quit;
});
)
```

- [ ] **Step 2: Run to verify it fails**

`sclang /tmp/test_morceau_advance.scd 2>&1 | grep -E "PASS|FAIL|ERROR"` → FAIL (02 missing → 1 morceau, no advance).

- [ ] **Step 3: Write `morceaux/02_hypno_roll.scd`**

```supercollider
// Morceau 2 -- Hypno Roll (hypnotic). Boucle 16e roulante : stab mute + kick
// tight + shaker. vitesse -> densite/energie ; main G -> sweep filtre ;
// profondeur (recul) -> reverb send (via amp du stab, le FX rack reverbe).
(
SynthDef(\cc_roll_stab, { |out=0, freq=110, cutoff=800, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.18), doneAction: 2);
    var sig = Pulse.ar(freq.clip(40, 800) * [1, 1.5], 0.4).sum * 0.3;
    sig = RLPF.ar(sig, cutoff.clip(200, 5000), 0.3) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_roll_kick, { |out=0, amp=0.55|
    var env = EnvGen.kr(Env.perc(0.001, 0.25), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([110, 48], [0.06], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;
SynthDef(\cc_roll_shaker, { |out=0, amp=0.12, pan=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 0.06), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 6000) * env;
    Out.ar(out, Pan2.ar(sig, pan) * amp);
}).add;

~concertAdd.((
    name: "Hypno Roll", style: \hypnotic,
    start: { |ctx| ctx[\cut] = 800; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var loT = (1 - (hf[\ly] ? 1)).clip(0, 1).linexp(0, 1, 400, 4000);  // main G hauteur
        ctx[\cut] = ctx[\cut] + ((loT - ctx[\cut]) * 0.06);
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter   = (1.0  / ~ccCtlDur).round.max(1);
        var speed = (pose[\kin][\speed] ? 0);
        var dens = speed.linlin(0, 0.6, 1, 4).round.clip(1, 4);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_roll_kick, [\amp, 0.55]) };
            if((beat % sixteenth) == 0) {
                Synth(\cc_roll_stab, [\freq, 110, \cutoff, ctx[\cut],
                    \amp, 0.16, \pan, 0.2.rand2]);
                if(dens >= 2) { Synth(\cc_roll_shaker, [\amp, 0.10, \pan, 0.3.rand2]) };
            };
            if((dens >= 3) and: { (beat % (sixteenth * 2).max(1)) == (sixteenth) }) {
                Synth(\cc_roll_shaker, [\amp, 0.08, \pan, -0.3]);
            };
        };
    },
    stop: { |ctx| },   // percussif one-shot : rien a release
));
"[morceau] Hypno Roll loaded".postln;
)
```

- [ ] **Step 4: Append to boot load list** — add `"morceaux/02_hypno_roll.scd",` to the `.do` list in `boot.scd` (step 3e of Task 1). Then run `sclang /tmp/test_morceau_advance.scd 2>&1 | grep -E "PASS|FAIL|ERROR"` → `[PASS] advance morceau 1 -> 2`. Balance-check `02_hypno_roll.scd` (`P:0 B:0 TLB:1`).

- [ ] **Step 5: Commit**

```bash
git add sound_algo/data_only/morceaux/02_hypno_roll.scd sound_algo/data_only/boot.scd
git commit -m "feat(sound): hypno roll morceau"
```

---

## Tasks 3–8: morceaux 3–8

Each follows the SAME shape as Task 2: create `morceaux/NN_<name>.scd` (its `\cc_*` SynthDefs + a `~concertAdd` module), append the filename to the `boot.scd` load list, run a per-morceau load test (`/tmp/test_morceau_NN.scd` — boots server, loads engine + this morceau alone, asserts it registers and its SynthDefs are present via `SynthDescLib.global.at(\cc_..).notNil`, and `~concert[\morceaux].last[\name]` matches), then commit `feat(sound): <name> morceau`. The per-morceau load test template:

```supercollider
(
s = Server.local; s.options.numInputBusChannels = 0; s.options.numOutputBusChannels = 2;
s.options.memSize = 65536;
s.waitForBoot({
    var base = "/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/";
    var fail = 0, defs = [ /* the \cc_* names this morceau adds */ ];
    ~doActivePriv = IdentityDictionary.new;
    ~doRegisterPriv = { |name, killFn| ~doActivePriv[name] = killFn };
    ~poseKin = Dictionary.new; ~poseState = Dictionary.new; ~poseCenter = Dictionary.new; ~handFeat = ();
    (base ++ "scene_concert.scd").load; s.sync;
    (base ++ "morceaux/NN_<name>.scd").load; s.sync;
    if(~concert[\morceaux].size != 1) { "[FAIL] not registered".postln; fail = 1 };
    defs.do { |d| if(SynthDescLib.global.at(d).isNil) { ("[FAIL] missing " ++ d).postln; fail = 1 } };
    // run start/update/tick/stop once without error (synthetic body)
    ~poseKin[0] = (speed: 0.3, accel: 0.2, symmetry: 0);
    ~handFeat = (rx: 0.4, ry: 0.4, lx: 0.6, ly: 0.5, ropen: 0.6, lopen: 0.4, rspeed: 0.2, lspeed: 0.1);
    ~doSceneConcert.value; 1.0.wait; ~doActivePriv[\concert].value; 0.2.wait;
    if(fail == 0) { "[PASS] <name> registers + runs".postln };
    0.5.wait; s.quit;
});
)
```

### Task 3: `morceaux/03_acid_line.scd` — Acid Line (acid)

```supercollider
// 303 resonante + slide + kick. main D hauteur -> cutoff, ouverture -> reso,
// main G -> octave/accent, vitesse -> tempo (set sur ~concert[\clock]).
(
SynthDef(\cc_acid_303, { |out=0, freq=55, cutoff=600, res=0.3, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.22), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 2.5, cutoff], [0.12], \exp)).clip(80, 6000);
    var sig = Saw.ar(freq.clip(20, 440) * SinOsc.kr(0).range(1, 1));
    sig = RLPF.ar(sig, fenv, res.clip(0.05, 0.9).linlin(0.05, 0.9, 0.6, 0.08));
    sig = (sig * env * 2).tanh;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_acid_kick, { |out=0, amp=0.6|
    var env = EnvGen.kr(Env.perc(0.001, 0.3), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([130, 45], [0.07], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Acid Line", style: \acid,
    start: { |ctx|
        ctx[\pat] = [0, 0, 12, 0, 3, 0, 7, 0];   // degres (demi-tons depuis root)
        ctx[\root] = 45; ctx[\step] = 0;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\cut] = (1 - (hf[\ry] ? 1)).clip(0, 1).linexp(0, 1, 200, 4000);
        ctx[\res] = (hf[\ropen] ? 0.3).clip(0, 1);
        ctx[\oct] = ((hf[\ly] ? 0.5) < 0.4).if({ 12 }, { 0 });
        ~concert[\clock] !? { |c| c.tempo = speed.linlin(0, 0.6, 124, 140).clip(124, 140) / 60 };
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_acid_kick, [\amp, 0.6]) };
            if((beat % sixteenth) == 0) {
                var deg = ctx[\pat].wrapAt(ctx[\step]);
                var note = (ctx[\root] + deg + (ctx[\oct] ? 0));
                Synth(\cc_acid_303, [\freq, note.midicps,
                    \cutoff, (ctx[\cut] ? 600), \res, (ctx[\res] ? 0.3),
                    \amp, 0.28, \pan, 0.15.rand2]);
                ctx[\step] = ctx[\step] + 1;
            };
        };
    },
    stop: { |ctx| ~concert[\clock] !? { |c| c.tempo = 126/60 } },
));
"[morceau] Acid Line loaded".postln;
)
```
Test defs: `[\cc_acid_303, \cc_acid_kick]`.

### Task 4: `morceaux/04_acid_storm.scd` — Acid Storm (acid/hard)

```supercollider
// 303 saturee + kick dur + bruit. controles acid + vitesse main D -> drive ;
// deux bras hauts -> screech/fill.
(
SynthDef(\cc_storm_303, { |out=0, freq=55, cutoff=800, res=0.4, drive=2, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.004, 0.2), doneAction: 2);
    var fenv = EnvGen.kr(Env([cutoff * 3, cutoff], [0.1], \exp)).clip(80, 7000);
    var sig = Saw.ar(freq.clip(20, 440));
    sig = RLPF.ar(sig, fenv, res.clip(0.05, 0.9).linlin(0.05, 0.9, 0.5, 0.06));
    sig = (sig * env * drive.clip(1, 8)).tanh;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_storm_kick, { |out=0, amp=0.7|
    var env = EnvGen.kr(Env.perc(0.001, 0.28), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([150, 48], [0.05], \exp))) * env;
    sig = (sig * 1.5).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_storm_screech, { |out=0, amp=0.2|
    var env = EnvGen.kr(Env.perc(0.01, 0.6), doneAction: 2);
    var sig = RHPF.ar(Saw.ar(LFNoise1.kr(8).exprange(800, 4000)), 3000, 0.1);
    Out.ar(out, Pan2.ar(sig * env, 0) * amp);
}).add;

~concertAdd.((
    name: "Acid Storm", style: \acid,
    start: { |ctx| ctx[\pat] = [0, 12, 0, 3, 10, 0, 7, 5]; ctx[\root] = 43; ctx[\step] = 0; ctx[\screeched] = 0; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        ctx[\cut] = (1 - (hf[\ry] ? 1)).clip(0, 1).linexp(0, 1, 250, 5000);
        ctx[\res] = (hf[\ropen] ? 0.4).clip(0, 1);
        ctx[\drive] = (hf[\rspeed] ? 0).clip(0, 0.6).linlin(0, 0.6, 1.5, 6);
        // deux bras hauts (ry et ly tres petits) -> screech, une fois par montee
        if(((hf[\ry] ? 1) < 0.18) and: { (hf[\ly] ? 1) < 0.18 }) {
            if(ctx[\screeched] == 0) { Synth(\cc_storm_screech, [\amp, 0.18]); ctx[\screeched] = 1 };
        } { ctx[\screeched] = 0 };
    },
    tick: { |ctx, pose, beat|
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_storm_kick, [\amp, 0.7]) };
            if((beat % sixteenth) == 0) {
                var note = ctx[\root] + ctx[\pat].wrapAt(ctx[\step]);
                Synth(\cc_storm_303, [\freq, note.midicps, \cutoff, (ctx[\cut] ? 800),
                    \res, (ctx[\res] ? 0.4), \drive, (ctx[\drive] ? 2), \amp, 0.26, \pan, 0.2.rand2]);
                ctx[\step] = ctx[\step] + 1;
            };
        };
    },
    stop: { |ctx| },
));
"[morceau] Acid Storm loaded".postln;
)
```
Test defs: `[\cc_storm_303, \cc_storm_kick, \cc_storm_screech]`.

### Task 5: `morceaux/05_hard_pump.scd` — Hard Pump (hard)

```supercollider
// kick dur sature + rumble + perc. vitesse -> intensite/disto kick + rumble ;
// main G -> highpass ; position cx -> couche perc.
(
SynthDef(\cc_pump_kick, { |out=0, amp=0.8, drive=2|
    var env = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 44], [0.06], \exp));
    var sig = SinOsc.ar(fenv) * env;
    sig = (sig * drive.clip(1, 6)).tanh;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;
SynthDef(\cc_pump_rumble, { |out=0, amp=0.0, gate=1|
    var sig = BPF.ar(PinkNoise.ar, 60, 0.5) * 4;
    sig = sig + SinOsc.ar(40) * 0.3;
    sig = sig * EnvGen.kr(Env.asr(0.5, 1, 0.5), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp.lag(0.3));
}).add;
SynthDef(\cc_pump_perc, { |out=0, amp=0.2, pan=0, hp=2000|
    var env = EnvGen.kr(Env.perc(0.001, 0.09), doneAction: 2);
    var sig = HPF.ar(GrayNoise.ar, hp.clip(500, 9000)) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Hard Pump", style: \hard,
    start: { |ctx| ctx[\rumble] = Synth(\cc_pump_rumble, [\amp, 0.0]); },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var speed = (pose[\kin][\speed] ? 0);
        ctx[\drive] = speed.linlin(0, 0.6, 1.5, 5);
        ctx[\hp] = (hf[\ly] ? 0.5).clip(0, 1).linexp(0, 1, 800, 6000);
        ctx[\rumble].set(\amp, speed.linlin(0, 0.6, 0.05, 0.22));
        ctx[\cx] = (pose[\center][\cx] ? 0.5);
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var eighth = (0.5 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) { Synth(\cc_pump_kick, [\amp, 0.8, \drive, (ctx[\drive] ? 2)]) };
            if((beat % eighth) == (eighth div: 2)) {
                Synth(\cc_pump_perc, [\amp, 0.18, \pan, ((ctx[\cx] ? 0.5) * 2 - 1), \hp, (ctx[\hp] ? 2000)]);
            };
        };
    },
    stop: { |ctx| ctx[\rumble] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Hard Pump loaded".postln;
)
```
Test defs: `[\cc_pump_kick, \cc_pump_rumble, \cc_pump_perc]`.

### Task 6: `morceaux/06_hard_rave.scd` — Hard Rave (hard)

```supercollider
// hoover/stabs + break dur + crash. main D -> stab+note ; main G hauteur ->
// transpose ; saut (accel) -> crash ; vitesse -> densite break.
(
SynthDef(\cc_rave_stab, { |out=0, freq=220, amp=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.25), doneAction: 2);
    var sig = Mix(Saw.ar(freq.clip(40, 880) * [1, 1.005, 1.5, 2])) * 0.2;
    sig = RLPF.ar(sig, 3000, 0.3) * env;
    Out.ar(out, Pan2.ar((sig * 1.5).tanh, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_rave_break, { |out=0, amp=0.25, pan=0, tone=2000|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, tone.clip(400, 8000)) * env;
    sig = sig + (SinOsc.ar(160) * env * 0.4);
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_rave_crash, { |out=0, amp=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 1.5), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 4000) * env;
    Out.ar(out, Pan2.ar(sig, 0) * amp);
}).add;

~concertAdd.((
    name: "Hard Rave", style: \hard,
    start: { |ctx| ctx[\last] = 0.0; ctx[\crashed] = 0; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var accel = (pose[\kin][\accel] ? 0);
        ctx[\trans] = ((hf[\ly] ? 0.5) < 0.4).if({ 5 }, { 0 });
        // saut : pic d'acceleration -> crash (anti-rebond)
        if(accel > 0.45) {
            if(ctx[\crashed] == 0) { Synth(\cc_rave_crash, [\amp, 0.3]); ctx[\crashed] = 1 };
        } { ctx[\crashed] = 0 };
        // stab au geste main D (vitesse main D)
        if(((hf[\rspeed] ? 0) > 0.18) and: { (thisThread.seconds - ctx[\last]) > 0.12 }) {
            var note = 50 + (ctx[\trans] ? 0) + [0, 7, 12].choose;
            ctx[\last] = thisThread.seconds;
            Synth(\cc_rave_stab, [\freq, note.midicps,
                \amp, (hf[\rspeed] ? 0).linlin(0.18, 0.6, 0.18, 0.4),
                \pan, ((hf[\rx] ? 0.5) * 2 - 1)]);
        };
    },
    tick: { |ctx, pose, beat|
        var quarter = (1.0 / ~ccCtlDur).round.max(1);
        var sixteenth = (0.25 / ~ccCtlDur).round.max(1);
        var speed = (pose[\kin][\speed] ? 0);
        var dens = speed.linlin(0, 0.6, 1, 4).round.clip(1, 4);
        if(pose[\hasBody]) {
            if((beat % quarter) == 0) {
                Synth(\cc_rave_break, [\amp, 0.3, \pan, 0, \tone, 1200]);   // beat fort
            };
            if(((beat % sixteenth) == 0) and: { dens >= 2 } and: { 0.5.coin }) {
                Synth(\cc_rave_break, [\amp, 0.18, \pan, 0.4.rand2, \tone, 3000]);
            };
        };
    },
    stop: { |ctx| },
));
"[morceau] Hard Rave loaded".postln;
)
```
Test defs: `[\cc_rave_stab, \cc_rave_break, \cc_rave_crash]`.

### Task 7: `morceaux/07_dub_chords.scd` — Dub Chords (dub)

```supercollider
// accord dub filtre + delay long + sub. main D -> trigger accord ;
// mains -> feedback delay + filtre ; aere, lent.
(
SynthDef(\cc_dub_chord, { |out=0, freq=110, cutoff=1200, amp=0.3, pan=0, fb=0.6|
    var env = EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2);
    var sig = Mix(Pulse.ar(freq.clip(40, 600) * [1, 1.19, 1.5], 0.3)) * 0.2;  // ~min triad
    sig = RLPF.ar(sig, cutoff.clip(200, 5000), 0.3) * env;
    sig = sig + CombL.ar(sig, 0.8, 0.66, fb.clip(0, 0.95).linlin(0, 0.95, 1, 6));
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;
SynthDef(\cc_dub_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 120));
    sig = sig * EnvGen.kr(Env.asr(0.3, 1, 0.5), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.4));
}).add;
SynthDef(\cc_dub_kick, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.001, 0.35), doneAction: 2);
    var sig = SinOsc.ar(EnvGen.kr(Env([100, 45], [0.08], \exp))) * env;
    Out.ar(out, Pan2.ar(sig.tanh, 0) * amp);
}).add;

~concertAdd.((
    name: "Dub Chords", style: \dub,
    start: { |ctx|
        ctx[\sub] = Synth(\cc_dub_sub, [\freq, 41.midicps * 0 + 55, \amp, 0.16]);
        ctx[\last] = 0.0; ctx[\root] = 50;
    },
    update: { |ctx, pose|
        var hf = pose[\hands];
        ctx[\cut] = (1 - (hf[\ly] ? 1)).clip(0, 1).linexp(0, 1, 400, 3000);
        ctx[\fb]  = (hf[\ropen] ? 0.5).clip(0, 1);
        if(((hf[\rspeed] ? 0) > 0.12) and: { (thisThread.seconds - ctx[\last]) > 0.4 }) {
            var note = ctx[\root] + [0, 3, 7, 10].choose;
            ctx[\last] = thisThread.seconds;
            Synth(\cc_dub_chord, [\freq, note.midicps, \cutoff, (ctx[\cut] ? 1200),
                \fb, (ctx[\fb] ? 0.6), \amp, 0.26, \pan, 0.3.rand2]);
        };
    },
    tick: { |ctx, pose, beat|
        var halfNote = (2.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody] and: { (beat % halfNote) == 0 }) { Synth(\cc_dub_kick, [\amp, 0.5]) };
    },
    stop: { |ctx| ctx[\sub] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Dub Chords loaded".postln;
)
```
Test defs: `[\cc_dub_chord, \cc_dub_sub, \cc_dub_kick]`.

### Task 8: `morceaux/08_dub_space.scd` — Dub Space (dub)

```supercollider
// minimal : sub + clics + grande reverb. profondeur (recul) -> taille reverb
// (via amp des clics, le FX rack reverbe) ; mains -> triggers sparse. Outro.
(
SynthDef(\cc_space_sub, { |out=0, freq=48, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 90)) + (SinOsc.ar(freq * 2) * 0.1);
    sig = sig * EnvGen.kr(Env.asr(1, 1, 2), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.8));
}).add;
SynthDef(\cc_space_click, { |out=0, amp=0.2, pan=0|
    var env = EnvGen.kr(Env.perc(0.0005, 0.04), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 5000) * env;
    Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)) * amp);
}).add;

~concertAdd.((
    name: "Dub Space", style: \dub,
    start: { |ctx| ctx[\sub] = Synth(\cc_space_sub, [\freq, 48, \amp, 0.14]); ctx[\last] = 0.0; },
    update: { |ctx, pose|
        var hf = pose[\hands];
        var depth = (pose[\center][\depth] ? 0.5);   // grand = proche ; recul = petit
        ctx[\space] = (1 - depth.clip(0, 1));         // recul -> plus d'espace -> clics plus forts (reverb)
        if(((hf[\rspeed] ? 0) > 0.10) and: { (thisThread.seconds - ctx[\last]) > 0.5 }) {
            ctx[\last] = thisThread.seconds;
            Synth(\cc_space_click, [\amp, 0.12 + ((ctx[\space] ? 0) * 0.25), \pan, 0.6.rand2]);
        };
    },
    tick: { |ctx, pose, beat|
        var twoBars = (8.0 / ~ccCtlDur).round.max(1);
        if(pose[\hasBody] and: { (beat % twoBars) == 0 }) {
            Synth(\cc_space_click, [\amp, 0.10, \pan, 0]);
        };
    },
    stop: { |ctx| ctx[\sub] !? { |s| s.set(\gate, 0) } },
));
"[morceau] Dub Space loaded".postln;
)
```
Test defs: `[\cc_space_sub, \cc_space_click]`.

---

## Task 9: Live smoke (manual)

- [ ] On macm1 (iphone-usb stack up: `data_only_viz --pose --iphone-usb` + SC booted with the concert files loaded): send `/control/doScene "concert"` (via `SimpleUDPClient('127.0.0.1', 57121).send_message('/control/doScene','concert')`). Stand in front of the iPhone and perform the full set: confirm each of the 8 morceaux sounds distinct, the body drives its mapping (hands/speed/position), **arms crossed ~1.5s advances to the next morceau** (crossfade, no stuck synths), the set ends cleanly on Dub Space, and `/control/doScene "stop"` tears everything down. Tune amplitudes/thresholds by ear. (Manual — no automated assertion.) Optionally flip `boot.scd` default scene to `\concert`.

---

## Self-Review notes

- **Spec coverage:** engine (T1) · morceau interface start/update/tick/stop+ctx (T1, every morceau) · crossfade via gated release (T1 stop + T2 advance test) · arms-crossed gesture rx<lx mid-height 1.5s + cooldown (T1) · `/pose/center`+`/pose/sho_span`→`~poseCenter` (T1) · `\concert` scene + boot load (T1) · 8 morceaux hard/dub/acid/hypnotic with custom mappings (T1–T8, matching the spec table) · live smoke (T9). All spec sections covered.
- **Interface consistency:** every morceau is `(name:, style:, start:{|ctx|}, update:{|ctx,pose|}, tick:{|ctx,pose,beat|}, stop:{|ctx|})` registered via `~concertAdd`; the engine calls exactly those. `pose` shape `(kin:,state:,center:,hands:,hasBody:)` is produced by `~ccPose` (T1) and consumed identically in every morceau. `~ccCtlDur` (0.05 beats) drives all `tick` subdivisions.
- **SC-trap scan:** no underscore-in-`{}` closures (all closures use explicit `|x|`); every sustained voice (drone/sub/rumble/acid-as-perc one-shots are doneAction:2; drones/subs/rumble are gated asr) releases via `\gate`; pose reads nil-guarded; freqs clipped. Each morceau file is one top-level block (TLB:1).
- **Known tuning (live, T9):** amplitudes, gesture thresholds (rx<lx margin 0.08, hold 1.5s), tempo ranges, and per-morceau densities are first-pass — tuned by ear at the smoke. The crossfade is fade-out-via-release overlapping fade-in (no hard cut); if transitions feel abrupt, lengthen the gated release times.
