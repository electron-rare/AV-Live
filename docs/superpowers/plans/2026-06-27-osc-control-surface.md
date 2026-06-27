# Web OSC Control Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A browser control surface (served from macm1) that launches a bank of musical patterns/sequences/melodies and controls the running concert (morceau, harmony, master FX) over OSC into the macm1 SC engine.

**Architecture:** Browser ⇄ WebSocket ⇄ Node server (on macm1, extends `web_realart`) ⇄ OSC/UDP ⇄ local SC `127.0.0.1:57121`. A new SC file `launchpad.scd` owns the launchable `Pdef` bank + all the new `/launch` and `/control/*` OSCdefs; the Node bridge forwards browser `{address,args}` to OSC; the web page is a pad/fader grid.

**Tech Stack:** SuperCollider (data-only engine), Node ≥20 ESM (`express`, `ws`, `osc`), vanilla HTML/JS/CSS.

## Global Constraints

- SC traps: lowercase `~vars`; NEVER underscore-in-`{}` (use `{ |x| ... }`); `doneAction:2` on one-shots; gated `Env.asr` for sustained (release on disarm); nil-guard every pose/`~cc*`/`~lp` read (`? 0` / `!?`); clip freqs; NO `inRange` (use `>=`/`<=`); NO `timeout` on macOS (background+kill for SC tests).
- `.scd` `.load` files: ONE top-level block, `P:0 B:0 TLB:1`. `boot.scd` pre-existing imbalance is a false positive — edits must be balance-NEUTRAL vs HEAD.
- `launchpad.scd` loads LAST in boot (after `engine.scd` → `concert_fx.scd` → `scene_concert.scd` → morceaux → `concert_gestures.scd`), so `~ccNote`, `~ccHarmony`, `~ccScales`, `~ccMaster`, `~ccFire`, `~doReverbBus` all exist at runtime. Nil-guard them anyway so headless tests can load `launchpad.scd` without the full concert.
- Existing concert handles to REUSE (do not redefine): `~ccNote.(degree,oct)` → midinote; `~ccHarmony` (root/scale/pad/phrase/octave); `~ccScales` (Event of degree arrays); `~ccMaster` (`[\filterTo].(cut,time)`, `[\stutterOn].(dur)`); `~ccFire.(\crash|\kick|\swell)`.
- SC headless tests on GrosMac: `/Applications/SuperCollider.app/Contents/MacOS/sclang /tmp/t.scd > /tmp/log 2>&1 & SC=$!; sleep N; kill -9 $SC; pkill -9 scsynth` then grep PASS/FAIL. Server output-only (`numInputBusChannels=0; numOutputBusChannels=2; memSize=65536`).
- Node lives in `web_realart/`: ESM (`import`), Node ≥20, deps already present (`express`, `ws`, `osc`). server.js today: `HTTP_PORT` (4400), `DATA_PORT_IN` (57124, inbound feeds → broadcast). Additive only — keep feeds working.
- Node OSC OUT target: `AVLIVE_SC_HOST` (default `127.0.0.1`), `AVLIVE_SC_PORT` (default `57121`). Web port stays `HTTP_PORT` (4400).
- OSC arg convention: `/launch <nameString> <0|1>`; `/launch/tempo <bpm>`; `/launch/clear`; harmony/fx routes per Task 3. The browser sends JSON `{address, args:[...]}`.
- No AI attribution in commits; subject ≤50 chars; no underscore in scope; no `--no-verify`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `sound_algo/data_only/launchpad.scd` (new) | `\lp_*` SynthDefs, `~lp` clock/registry, the launchable `Pdef` bank, `~lpArm`, and ALL new OSCdefs (`/launch*`, `/control/harmony/*`, `/control/fx/*`) |
| `sound_algo/data_only/boot.scd` (modify) | load `launchpad.scd` last |
| `web_realart/server.js` (modify) | add outbound OSC port to SC + `ws.on("message")` → OSC; env `AVLIVE_SC_HOST/PORT` |
| `web_realart/test/bridge.test.mjs` (new) | node:test — WS message → OSC packet reaches a loopback listener |
| `web_realart/public/control/index.html` (new) | the control surface page |
| `web_realart/public/control/control.js` (new) | WS sender + pad/fader wiring + armed-state |
| `web_realart/public/control/control.css` (new) | dark grid styling |

---

## Task 1: SC launchpad framework + drum patterns

**Files:** Create `sound_algo/data_only/launchpad.scd`; modify `sound_algo/data_only/boot.scd`. Test: `/tmp/test_lp_drums.scd`.

**Interfaces — Produces:** `~lp` (Event: `[\clock]` TempoClock, `[\armed]` Set); `~lpArm.(nameString, onBool)` arms/disarms `Pdef(\lp_<name>)`; OSC `/launch <name> <0|1>`, `/launch/tempo <bpm>`, `/launch/clear`. Drum names: `kick`, `hats`, `clap`, `perc`.

- [ ] **Step 1: Write failing test** `/tmp/test_lp_drums.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0; var n;
    (base++"launchpad.scd").load; s.sync; 0.3.wait;
    [\lp_kick,\lp_hat,\lp_clap,\lp_perc].do { |d|
        if(SynthDescLib.global.at(d).isNil) { ("[FAIL] missing "++d).postln; fail=1 } };
    if(~lp.isNil or: { ~lp[\clock].isNil }) { "[FAIL] ~lp/clock nil".postln; fail=1 };
    n = NetAddr("127.0.0.1", NetAddr.langPort);
    n.sendMsg("/launch", "kick", 1); n.sendMsg("/launch", "hats", 1); 0.5.wait;
    if(~lp[\armed].includes(\kick).not) { "[FAIL] kick not armed".postln; fail=1 };
    if(Pdef(\lp_kick).isPlaying.not) { "[FAIL] kick Pdef not playing".postln; fail=1 };
    n.sendMsg("/launch", "kick", 0); 0.3.wait;
    if(~lp[\armed].includes(\kick)) { "[FAIL] kick still armed".postln; fail=1 };
    n.sendMsg("/launch/tempo", 140); 0.2.wait;
    if((~lp[\clock].tempo - (140/60)).abs > 0.01) { "[FAIL] tempo".postln; fail=1 };
    n.sendMsg("/launch/clear"); 0.4.wait;
    if(~lp[\armed].size != 0) { ("[FAIL] clear, armed="++~lp[\armed].size).postln; fail=1 };
    if(fail==0) { "[PASS] launchpad drums arm/tempo/clear".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (file missing). Background+kill (sleep 14), grep.
- [ ] **Step 3: Write `launchpad.scd`** (drum half — ONE top-level block):
```supercollider
// Launchpad: OSC-armable Pdef bank for the web control surface + the concert
// control OSC routes. Loaded LAST by boot (after concert_fx + scene_concert +
// morceaux + gestures), so ~ccNote/~ccHarmony/~ccMaster/~ccFire exist; all are
// nil-guarded so this file still loads alone in tests. Patterns play on
// ~lp[\clock] and route Out.ar(0) through the FX rack.
(
SynthDef(\lp_kick, { |out=0, amp=0.9|
    var env = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 45], [0.06], \exp));
    Out.ar(out, Pan2.ar((SinOsc.ar(fenv) * env * 2).tanh, 0) * amp);
}).add;
SynthDef(\lp_hat, { |out=0, amp=0.3|
    var env = EnvGen.kr(Env.perc(0.001, 0.045), doneAction: 2);
    Out.ar(out, Pan2.ar(HPF.ar(WhiteNoise.ar, 8000) * env, 0) * amp);
}).add;
SynthDef(\lp_clap, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.004, 0.18), doneAction: 2);
    Out.ar(out, Pan2.ar(BPF.ar(WhiteNoise.ar, 1500, 0.6) * env, 0) * amp);
}).add;
SynthDef(\lp_perc, { |out=0, amp=0.4, freq=420|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction: 2);
    Out.ar(out, Pan2.ar(RLPF.ar(Saw.ar(freq.clip(80,2000)), (freq*3).clip(200,8000), 0.3) * env, 0.3) * amp);
}).add;

s.sync;

~lp = ~lp ? ();
~lp[\clock] = ~lp[\clock] ? TempoClock(126/60).permanent_(true);
~lp[\armed] = ~lp[\armed] ? Set.new;

Pdef(\lp_kick, Pbind(\instrument, \lp_kick, \dur, 1, \amp, 0.9));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat, \dur, Pseq([Rest(0.5), 0.5], inf), \amp, 0.28));
Pdef(\lp_clap, Pbind(\instrument, \lp_clap, \dur, Pseq([Rest(1), 1], inf), \amp, 0.5));
Pdef(\lp_perc, Pbind(\instrument, \lp_perc, \dur, Pseq([0.75, 0.25, 0.5, 0.5], inf),
    \freq, Pseq([420, 640, 520], inf), \amp, 0.32));

~lpArm = { |name, on|
    var nm = name.asSymbol;
    var key = ("lp_" ++ name.asString).asSymbol;
    if(Pdef.all.includesKey(key)) {
        on.if({
            Pdef(key).play(~lp[\clock], quant: 1);
            ~lp[\armed].add(nm);
        }, {
            Pdef(key).stop;
            ~lp[\armed].remove(nm);
        });
    };
};

OSCdef(\lpLaunch, { |msg|
    ~lpArm.((msg[1] ? \nil).asString, (msg[2] ? 0) > 0);
}, '/launch');
OSCdef(\lpTempo, { |msg|
    ~lp[\clock].tempo = ((msg[1] ? 126).clip(60, 200)) / 60;
}, '/launch/tempo');
OSCdef(\lpClear, { |msg|
    ~lp[\armed].copy.do { |nm| ~lpArm.(nm, false) };
}, '/launch/clear');

"[data-only/launchpad] drums + arm/tempo/clear ready".postln;
)
```
- [ ] **Step 4: boot.scd** — after the `concert_gestures.scd` load line, add `(~base ++ "launchpad.scd").load; s.sync;`. Run the test → `[PASS] launchpad drums arm/tempo/clear`. Balance `launchpad.scd` `P:0 B:0`; boot neutral vs HEAD.
- [ ] **Step 5: Commit** `launchpad.scd` + `boot.scd` → `feat(sound): launchpad drum patterns`.

---

## Task 2: SC launchpad pitched patterns (sub, acid, arp, lead, stab, pad)

**Files:** Modify `sound_algo/data_only/launchpad.scd`. Test: `/tmp/test_lp_pitched.scd`.

**Interfaces — Produces:** `Pdef`s `\lp_sub`, `\lp_acid`, `\lp_arp`, `\lp_lead`, `\lp_stab`, `\lp_pad` (armed by `~lpArm`/`/launch`), pitched from `~ccNote`.

- [ ] **Step 1: Write failing test** `/tmp/test_lp_pitched.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0; var n;
    // minimal ~ccNote/~ccHarmony so pitched patterns resolve without the concert
    ~ccScales=(minor:[0,2,3,5,7,8,10]); ~ccHarmony=(root:45,scale:\minor,pad:\dark,phrase:0,octave:0);
    ~ccNote={ |deg,oct=0| var sc=~ccScales[\minor]; 45 + ((oct+(deg div: sc.size))*12) + sc[deg % sc.size] };
    (base++"launchpad.scd").load; s.sync; 0.3.wait;
    [\lp_sub,\lp_acid,\lp_arp,\lp_lead,\lp_stab,\lp_pad].do { |d|
        if(SynthDescLib.global.at(d).isNil) { ("[FAIL] missing "++d).postln; fail=1 } };
    n = NetAddr("127.0.0.1", NetAddr.langPort);
    ["sub","acid","arp","lead","stab","pad"].do { |nm| n.sendMsg("/launch", nm, 1) };
    1.0.wait;   // run all pitched patterns concurrently, must not error
    ["acid","pad"].do { |nm| if(Pdef(("lp_"++nm).asSymbol).isPlaying.not) { ("[FAIL] "++nm++" not playing").postln; fail=1 } };
    n.sendMsg("/launch/clear"); 0.4.wait;
    if(~lp[\armed].size != 0) { "[FAIL] not cleared".postln; fail=1 };
    if(fail==0) { "[PASS] launchpad pitched patterns".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (pitched synthdefs/Pdefs missing).
- [ ] **Step 3: launchpad.scd** — add the pitched SynthDefs (before `s.sync;`) and the pitched Pdefs (after the drum Pdefs). SynthDefs:
```supercollider
SynthDef(\lp_sub, { |out=0, freq=55, amp=0.0, gate=1|
    var sig = SinOsc.ar(freq.clip(20, 120)) * 0.9 + (Saw.ar(freq.clip(20,120)) * 0.1);
    sig = sig * EnvGen.kr(Env.asr(0.05, 1, 0.3), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.1));
}).add;
SynthDef(\lp_acid, { |out=0, freq=110, amp=0.3, cutoff=800, res=0.3, pan=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.22), doneAction: 2);
    var sig = Saw.ar(freq.clip(30, 1200));
    sig = RLPF.ar(sig, (cutoff * (1 + (env*2))).clip(80, 6000), res.clip(0.05, 0.9));
    Out.ar(out, Pan2.ar(sig.tanh * env, pan.clip(-1,1)) * amp);
}).add;
SynthDef(\lp_pluck, { |out=0, freq=220, amp=0.3, cutoff=2500, pan=0|
    var env = EnvGen.kr(Env.perc(0.002, 0.25), doneAction: 2);
    var sig = RLPF.ar(Saw.ar(freq.clip(40,2000) * [1, 1.005]), cutoff.clip(200,8000), 0.4);
    Out.ar(out, Pan2.ar(Mix(sig) * env, pan.clip(-1,1)) * amp);
}).add;
SynthDef(\lp_pad, { |out=0, freq=220, amp=0.0, cutoff=1500, gate=1|
    var sig = Mix(Saw.ar(freq.clip(40,1000) * [0.99, 1.0, 1.008, 2.0]));
    sig = RLPF.ar(sig, cutoff.clip(200,6000), 0.4);
    sig = sig * EnvGen.kr(Env.asr(1.5, 1, 2.0), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig, 0) * amp.lag(0.5) * 0.25);
}).add;
```
Pitched Pdefs (use `Pfunc { ~ccNote.(...).midicps }` so they track `~ccHarmony`; guard with `(~ccNote ? { |d,o| 220 })`):
```supercollider
~lpNote = { |deg, oct=0| (~ccNote.notNil).if({ ~ccNote.(deg, oct) }, { 45 + (oct*12) + ([0,2,3,5,7,8,10][deg % 7]) }) };
Pdef(\lp_sub, Pbind(\instrument, \lp_sub, \dur, 4, \freq, Pfunc { ~lpNote.(0, -1).midicps }, \amp, 0.22, \legato, 1));
Pdef(\lp_acid, Pbind(\instrument, \lp_acid, \dur, 0.25,
    \degree, Pseq([0,0,7,0,3,0,5,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 0).midicps },
    \cutoff, Pseq([500,900,1400,700], inf), \res, 0.32, \amp, 0.26, \pan, Pwhite(-0.2,0.2)));
Pdef(\lp_arp, Pbind(\instrument, \lp_pluck, \dur, 0.25,
    \degree, Pseq([0,2,4,7,4,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps }, \cutoff, 3000, \amp, 0.2, \pan, Pwhite(-0.3,0.3)));
Pdef(\lp_lead, Pbind(\instrument, \lp_pluck, \dur, Pseq([1, 0.5, 0.5, 2], inf),
    \degree, Pseq([7,5,4,0,2,4], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps }, \cutoff, 4000, \amp, 0.24));
Pdef(\lp_stab, Pbind(\instrument, \lp_pluck, \dur, Pseq([Rest(0.5), 0.5], inf),
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } }, \cutoff, 2200, \amp, 0.2));
Pdef(\lp_pad, Pbind(\instrument, \lp_pad, \dur, 8,
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, Pfunc { ((~ccHarmony ? ()).at(\pad) == \bright).if({ 3200 }, { 1200 }) }, \amp, 0.3, \legato, 1));
```
(`\freq` as an array → SC multichannel-expands the synth into a chord. The pad/stab gate: arming plays the Pdef; disarming `.stop` stops new events and the gated synths release via their `Env.asr` when the Pdef stops scheduling — acceptable for the smoke; if a pad hangs, Task 2 self-review notes adding an explicit all-notes-off in `~lpArm` for `pad`.)
- [ ] **Step 4: Run, expect** `[PASS] launchpad pitched patterns`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `launchpad.scd` → `feat(sound): launchpad bass, melody, chord patterns`.

---

## Task 3: SC concert / harmony / FX control OSCdefs

**Files:** Modify `sound_algo/data_only/launchpad.scd` (add OSCdefs before the final `postln`). Test: `/tmp/test_lp_control.scd`.

**Interfaces — Produces (OSC):** `/control/harmony/root <delta>`, `/control/harmony/scale <name>`, `/control/harmony/octave <0|1>`, `/control/harmony/phrase <0-3>`, `/control/fx/filter <0-1>`, `/control/fx/stutter`, `/control/fx/crash`, `/control/fx/kick`, `/control/fx/swell`, `/control/fx/breakdown <0|1>`.

- [ ] **Step 1: Write failing test** `/tmp/test_lp_control.scd`:
```supercollider
(
s = Server.local; s.options.numInputBusChannels=0; s.options.numOutputBusChannels=2; s.options.memSize=65536;
s.waitForBoot({
    var base="/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/"; var fail=0; var n; var r0;
    var fxCalls=0;
    ~ccScales=(minor:[0,2,3,5,7,8,10], dorian:[0,2,3,5,7,9,10]); ~ccHarmony=(root:45,scale:\minor,pad:\dark,phrase:0,octave:0);
    ~ccNote={ |deg,oct=0| 45 };
    ~ccMaster=(filterTo:{ |c,t| fxCalls=fxCalls+1 }, stutterOn:{ |d| fxCalls=fxCalls+1 });
    ~ccFire={ |k| fxCalls=fxCalls+1 };
    (base++"launchpad.scd").load; s.sync; 0.3.wait;
    n = NetAddr("127.0.0.1", NetAddr.langPort); r0 = ~ccHarmony[\root];
    n.sendMsg("/control/harmony/root", 2); 0.2.wait;
    if(~ccHarmony[\root] != (r0+2)) { ("[FAIL] root="++~ccHarmony[\root]).postln; fail=1 };
    n.sendMsg("/control/harmony/scale", "dorian"); 0.2.wait;
    if(~ccHarmony[\scale] != \dorian) { "[FAIL] scale".postln; fail=1 };
    n.sendMsg("/control/harmony/octave", 1); 0.2.wait;
    if(~ccHarmony[\octave] != 1) { "[FAIL] octave".postln; fail=1 };
    n.sendMsg("/control/fx/filter", 0.5); n.sendMsg("/control/fx/stutter");
    n.sendMsg("/control/fx/crash"); n.sendMsg("/control/fx/breakdown", 1); 0.4.wait;
    if(fxCalls < 4) { ("[FAIL] fx calls="++fxCalls).postln; fail=1 };
    if(fail==0) { "[PASS] launchpad control OSC".postln };
    0.3.wait; s.quit;
});
)
```
- [ ] **Step 2: Run, expect FAIL** (control OSCdefs missing).
- [ ] **Step 3: launchpad.scd** — before the final `postln`, add:
```supercollider
OSCdef(\ctlHarmRoot, { |msg|
    ~ccHarmony !? { ~ccHarmony[\root] = (~ccHarmony[\root] + (msg[1] ? 0)).clip(33, 57) };
}, '/control/harmony/root');
OSCdef(\ctlHarmScale, { |msg|
    var nm = (msg[1] ? \minor).asSymbol;
    (~ccHarmony.notNil and: { (~ccScales ? ()).includesKey(nm) }).if({ ~ccHarmony[\scale] = nm });
}, '/control/harmony/scale');
OSCdef(\ctlHarmOct, { |msg| ~ccHarmony !? { ~ccHarmony[\octave] = (msg[1] ? 0).asInteger.clip(0, 2) } }, '/control/harmony/octave');
OSCdef(\ctlHarmPhrase, { |msg| ~ccHarmony !? { ~ccHarmony[\phrase] = (msg[1] ? 0).asInteger.clip(0, 3) } }, '/control/harmony/phrase');
OSCdef(\ctlFxFilter, { |msg|
    ~ccMaster !? { ~ccMaster[\filterTo].((msg[1] ? 1).clip(0,1).linexp(0, 1, 120, 20000), 0.2) };
}, '/control/fx/filter');
OSCdef(\ctlFxStutter, { |msg| ~ccMaster !? { ~ccMaster[\stutterOn].(0.9) } }, '/control/fx/stutter');
OSCdef(\ctlFxCrash, { |msg| ~ccFire !? { ~ccFire.(\crash) } }, '/control/fx/crash');
OSCdef(\ctlFxKick, { |msg| ~ccFire !? { ~ccFire.(\kick) } }, '/control/fx/kick');
OSCdef(\ctlFxSwell, { |msg| ~ccFire !? { ~ccFire.(\swell) } }, '/control/fx/swell');
OSCdef(\ctlFxBreak, { |msg|
    ~ccMaster !? { ((msg[1] ? 0) > 0).if({ ~ccMaster[\filterTo].(450, 1.0) }, { ~ccMaster[\filterTo].(20000, 1.5) }) };
}, '/control/fx/breakdown');
```
- [ ] **Step 4: Run, expect** `[PASS] launchpad control OSC`. Balance `P:0 B:0`.
- [ ] **Step 5: Commit** `launchpad.scd` → `feat(sound): harmony and fx control OSC`.

---

## Task 4: Node bridge — WebSocket → OSC out to SC

**Files:** Modify `web_realart/server.js`; create `web_realart/test/bridge.test.mjs`. 

**Interfaces — Consumes:** browser WS `{address, args:[...]}`. **Produces:** an OSC UDP packet to `AVLIVE_SC_HOST:AVLIVE_SC_PORT`.

- [ ] **Step 1: Write failing test** `web_realart/test/bridge.test.mjs` (node:test; spawns the server, opens a loopback OSC listener, sends a WS message, asserts the OSC arrives):
```javascript
import { test } from "node:test";
import assert from "node:assert";
import { spawn } from "node:child_process";
import { WebSocket } from "ws";
import osc from "osc";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HTTP_PORT = 4555, SC_PORT = 57599;

test("WS {address,args} is forwarded as OSC to the SC host", async () => {
  // loopback OSC listener standing in for SC
  const recv = new Promise((resolve) => {
    const udp = new osc.UDPPort({ localAddress: "127.0.0.1", localPort: SC_PORT, metadata: true });
    udp.on("message", (m) => { udp.close(); resolve(m); });
    udp.open();
  });
  const srv = spawn("node", [join(__dirname, "..", "server.js")], {
    env: { ...process.env, HTTP_PORT: String(HTTP_PORT), AVLIVE_SC_HOST: "127.0.0.1",
           AVLIVE_SC_PORT: String(SC_PORT), DATA_PORT_IN: "57598" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  await new Promise((res) => srv.stdout.on("data", (b) => { if (String(b).includes("listen") || String(b).includes("HTTP")) res(); }));
  await new Promise((r) => setTimeout(r, 300));
  const ws = new WebSocket(`ws://127.0.0.1:${HTTP_PORT}/ws`);
  await new Promise((res) => ws.on("open", res));
  ws.send(JSON.stringify({ address: "/launch", args: ["kick", 1] }));
  const msg = await recv;
  ws.close(); srv.kill("SIGKILL");
  assert.strictEqual(msg.address, "/launch");
  assert.strictEqual(String(msg.args[0]), "kick");
});
```
- [ ] **Step 2: Run, expect FAIL** — `cd web_realart && node --test test/bridge.test.mjs` fails (no WS-in handler / no SC port).
- [ ] **Step 3: server.js** — after the existing `osc` import / config, add the SC out config + port, and in `wss.on("connection")` add a message handler. Concretely:

Add near the `DATA_PORT_IN` const:
```javascript
const SC_HOST = process.env.AVLIVE_SC_HOST ?? "127.0.0.1";
const SC_PORT = parseInt(process.env.AVLIVE_SC_PORT ?? "57121", 10);
```
Add an outbound OSC port after `dataPort` is created (open it too):
```javascript
const scPort = new osc.UDPPort({ localAddress: "127.0.0.1", localPort: 0, metadata: true });
scPort.on("ready", () => console.log(`[sc] OSC out -> ${SC_HOST}:${SC_PORT}`));
scPort.open();
```
Inside `wss.on("connection", (ws) => { ... })`, add (alongside the existing hello send):
```javascript
    ws.on("message", (data) => {
        let m; try { m = JSON.parse(data.toString()); } catch (_e) { return; }
        if (!m || typeof m.address !== "string") return;
        const args = (Array.isArray(m.args) ? m.args : []).map((a) =>
            typeof a === "number"
                ? (Number.isInteger(a) ? { type: "i", value: a } : { type: "f", value: a })
                : { type: "s", value: String(a) });
        try { scPort.send({ address: m.address, args }, SC_HOST, SC_PORT); } catch (_e) { /* SC down */ }
    });
```
Add `scPort.close();` to the shutdown path next to `wss.close()`.
- [ ] **Step 4: Run, expect PASS** — `node --test test/bridge.test.mjs` → 1 pass. Also `node -c server.js` (syntax).
- [ ] **Step 5: Commit** `server.js` + `test/bridge.test.mjs` → `feat(web): bridge WebSocket to OSC out`.

---

## Task 5: Web UI — control surface page

**Files:** Create `web_realart/public/control/index.html`, `control.js`, `control.css`.

**Interfaces — Consumes:** the `/ws` WebSocket (sends `{address, args}`). Mirrors the OSC routes from Tasks 1–3.

- [ ] **Step 1: Write `control.js`** (WS sender + control wiring + armed-state):
```javascript
const ws = new WebSocket(`ws://${location.host}/ws`);
const dot = () => document.getElementById("status");
ws.addEventListener("open", () => dot().className = "on");
ws.addEventListener("close", () => dot().className = "off");
function send(address, ...args) {
  if (ws.readyState === 1) ws.send(JSON.stringify({ address, args }));
}
const armed = new Set();
function togglePad(el, name) {
  const on = !armed.has(name);
  on ? armed.add(name) : armed.delete(name);
  el.classList.toggle("armed", on);
  send("/launch", name, on ? 1 : 0);
}
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-pad]").forEach((el) =>
    el.addEventListener("click", () => togglePad(el, el.dataset.pad)));
  document.querySelectorAll("[data-osc]").forEach((el) =>
    el.addEventListener("click", () => {
      const a = el.dataset.arg;
      send(el.dataset.osc, ...(a === undefined ? [] : [isNaN(+a) ? a : +a]));
    }));
  const tempo = document.getElementById("tempo");
  tempo && tempo.addEventListener("input", () => send("/launch/tempo", +tempo.value));
  const filt = document.getElementById("filter");
  filt && filt.addEventListener("input", () => send("/control/fx/filter", +filt.value));
  document.getElementById("clear").addEventListener("click", () => {
    armed.clear(); document.querySelectorAll("[data-pad]").forEach((e) => e.classList.remove("armed"));
    send("/launch/clear");
  });
});
```
- [ ] **Step 2: Write `index.html`** (sections; pads carry `data-pad`, one-shots `data-osc`/`data-arg`):
```html
<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AV-Live — Control</title><link rel="stylesheet" href="control.css"></head>
<body>
<header><h1>AV-Live Control</h1><span id="status" class="off"></span></header>
<section><h2>Patterns</h2>
  <div class="grid">
    <button data-pad="kick">Kick</button><button data-pad="hats">Hats</button>
    <button data-pad="clap">Clap</button><button data-pad="perc">Perc</button>
    <button data-pad="sub">Sub</button><button data-pad="acid">Acid</button>
    <button data-pad="arp">Arp</button><button data-pad="lead">Lead</button>
    <button data-pad="stab">Stab</button><button data-pad="pad">Pad</button>
  </div>
  <button id="clear" class="wide">Tout couper</button>
  <label>Tempo <input id="tempo" type="range" min="60" max="180" value="126"></label>
</section>
<section><h2>Concert</h2>
  <div class="grid">
    <button data-osc="/control/concertNext" data-arg="1">Morceau suivant</button>
    <button data-osc="/control/doScene" data-arg="concert">Scène concert</button>
    <button data-osc="/control/doScene" data-arg="play">Body-play</button>
  </div>
</section>
<section><h2>Harmonie</h2>
  <div class="grid">
    <button data-osc="/control/harmony/root" data-arg="-2">Root −</button>
    <button data-osc="/control/harmony/root" data-arg="2">Root +</button>
    <button data-osc="/control/harmony/scale" data-arg="minor">Minor</button>
    <button data-osc="/control/harmony/scale" data-arg="dorian">Dorian</button>
    <button data-osc="/control/harmony/scale" data-arg="phrygian">Phrygian</button>
    <button data-osc="/control/harmony/scale" data-arg="penta">Penta</button>
    <button data-osc="/control/harmony/octave" data-arg="0">Oct 0</button>
    <button data-osc="/control/harmony/octave" data-arg="1">Oct +1</button>
    <button data-osc="/control/harmony/phrase" data-arg="0">Phr 0</button>
    <button data-osc="/control/harmony/phrase" data-arg="1">Phr 1</button>
    <button data-osc="/control/harmony/phrase" data-arg="2">Phr 2</button>
    <button data-osc="/control/harmony/phrase" data-arg="3">Phr 3</button>
  </div>
</section>
<section><h2>FX</h2>
  <label>Filtre <input id="filter" type="range" min="0" max="1" step="0.01" value="1"></label>
  <div class="grid">
    <button data-osc="/control/fx/stutter">Stutter</button>
    <button data-osc="/control/fx/crash">Crash</button>
    <button data-osc="/control/fx/kick">Kick</button>
    <button data-osc="/control/fx/swell">Swell</button>
    <button data-osc="/control/fx/breakdown" data-arg="1">Breakdown ↓</button>
    <button data-osc="/control/fx/breakdown" data-arg="0">Breakdown ↑</button>
  </div>
</section>
<script src="control.js"></script></body></html>
```
- [ ] **Step 3: Write `control.css`** (dark, big touch targets):
```css
* { box-sizing: border-box; } body { margin: 0; background: #111; color: #eee;
  font: 16px/1.3 -apple-system, system-ui, sans-serif; padding: 12px; }
header { display: flex; align-items: center; gap: 10px; }
h1 { font-size: 18px; margin: 4px 0; } h2 { font-size: 14px; color: #9af; margin: 16px 0 8px; text-transform: uppercase; letter-spacing: .06em; }
#status { width: 12px; height: 12px; border-radius: 50%; display: inline-block; }
#status.on { background: #4c8; } #status.off { background: #c44; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 8px; }
button { background: #222; color: #eee; border: 1px solid #333; border-radius: 10px;
  padding: 18px 10px; font-size: 16px; cursor: pointer; }
button:active { background: #2a2a2a; } button.armed { background: #2b6; color: #061; border-color: #4d9; font-weight: 700; }
button.wide { width: 100%; margin: 8px 0; background: #422; border-color: #633; }
label { display: block; margin: 10px 0; } input[type=range] { width: 100%; height: 36px; }
```
- [ ] **Step 4: Smoke** — `cd web_realart && AVLIVE_SC_PORT=57599 node server.js &` then `curl -s localhost:4400/control/ | grep -q "AV-Live Control" && echo PAGE_OK`; kill the server. Expected `PAGE_OK` (the page is served). (Full click-through is the live smoke, Task 6.)
- [ ] **Step 5: Commit** the 3 files → `feat(web): control surface page`.

---

## Task 6: Live smoke (manual, macm1)

- [ ] On macm1: `cd ~/Documents/Projets/AV-Live/web_realart && npm install` (first run) then `node server.js` (OSC out defaults to `127.0.0.1:57121`). With the concert running (the `.app`), from GrosMac open `http://supra-m1.local:4400/control/`. Verify: the status dot is green (WS connected); arming **kick/hats/acid/arp** pads makes them play (lit green), layered on the body-concert; **Tout couper** silences them; **Morceau suivant** advances; **Root +/−, scale, octave, phrase** change the pitched patterns + morceaux; **Filtre** fader sweeps the master; **Stutter/Crash/Swell/Breakdown** fire. Tune pattern levels/tempo and FX amounts by ear (constants in `launchpad.scd`). Manual — no automated assertion.

---

## Self-Review notes
- **Spec coverage:** launchpad drums (T1) · pitched bass/melody/chord patterns (T2) · harmony+FX control OSC (T3) · Node WS→OSC bridge to localhost SC (T4) · web UI patterns+concert+harmony+FX (T5) · live smoke (T6). All spec sections A–D + testing covered. Out-of-scope (per-pattern faders, step grid, MIDI clock, scene save) intentionally omitted.
- **Interface consistency:** `~lpArm.(nameString, onBool)` and `/launch <name> <0|1>` use the SAME bare names (`kick`…`pad`) as the UI `data-pad` attrs and the `Pdef(\lp_<name>)` keys. Control routes in T3 match the UI `data-osc` strings in T5 exactly (`/control/harmony/root`, `/control/fx/filter`, …). The bridge (T4) is generic `{address,args}` → OSC, so it needs no per-route knowledge. `~ccNote`/`~ccHarmony`/`~ccMaster`/`~ccFire` are reused (guarded), never redefined.
- **Placeholder scan:** every code step is complete (SC SynthDefs/Pdefs/OSCdefs, the Node handler, the full HTML/JS/CSS). No TBD.
- **SC traps:** lowercase `~vars`; no underscore-in-`{}`; `doneAction:2` one-shots; gated `Env.asr` for sub/pad; nil-guards on `~ccNote`/`~ccHarmony`/`~ccMaster`/`~ccFire`/`~lp`; freqs clipped; `launchpad.scd` one top-level block.
- **Known live-tune (T6):** all pattern levels, the acid/lead degree sequences, the pad gate-release on disarm (Pdef.stop lets gated synths ring their release — if a pad hangs audibly, add an explicit voice-off in `~lpArm` for `pad`/`sub`), and FX amounts are first-pass, tuned by ear at the smoke.
