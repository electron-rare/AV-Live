// Launchpad: OSC-armable Pdef bank for the web control surface + the concert
// control OSC routes. Loaded LAST by boot (after concert_fx + scene_concert +
// morceaux + gestures), so ~ccNote/~ccHarmony/~ccMaster/~ccFire exist; all are
// nil-guarded so this file still loads alone in tests. Patterns play on
// ~lpClock.value (concert clock when running, else ~lp[\clock]) and route
// Out.ar(0) through the FX rack.
(
// All voices take \pan and \rev (reverb send to ~doReverbBus) so the matrix
// capture-modulation can drive them. \rev defaults to 0 (no extra send; the
// master FX rack still applies its own reverb on bus 0). The send is only wired
// when ~doReverbBus exists (engine loaded first; nil-safe for standalone tests).
SynthDef(\lp_kick, { |out=0, amp=0.9, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.32), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 45], [0.06], \exp));
    var sig = Pan2.ar((SinOsc.ar(fenv) * env * 2).tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_hat, { |out=0, amp=0.3, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.045), doneAction: 2);
    var sig = Pan2.ar(HPF.ar(WhiteNoise.ar, 8000) * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_clap, { |out=0, amp=0.5, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.004, 0.18), doneAction: 2);
    var sig = Pan2.ar(BPF.ar(WhiteNoise.ar, 1500, 0.6) * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// \cutoff=0 keeps the original freq-tracking timbre; >0 (mod) sets it directly.
SynthDef(\lp_perc, { |out=0, amp=0.4, freq=420, cutoff=0, pan=0.3, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction: 2);
    var cut = Select.kr(cutoff > 0, [(freq * 3), cutoff]).clip(200, 8000);
    var sig = Pan2.ar(RLPF.ar(Saw.ar(freq.clip(80,2000)), cut, 0.3) * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

SynthDef(\lp_sub, { |out=0, freq=55, amp=0.0, gate=1, pan=0, rev=0|
    var sig = SinOsc.ar(freq.clip(20, 120)) * 0.9 + (Saw.ar(freq.clip(20,120)) * 0.1);
    sig = sig * EnvGen.kr(Env.asr(0.05, 1, 0.3), gate, doneAction: 2);
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp.lag(0.1);
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_acid, { |out=0, freq=110, amp=0.3, cutoff=800, res=0.3, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.005, 0.22), doneAction: 2);
    var sig = Saw.ar(freq.clip(30, 1200));
    sig = RLPF.ar(sig, (cutoff * (1 + (env*2))).clip(80, 6000), res.clip(0.05, 0.9));
    sig = Pan2.ar(sig.tanh * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_pluck, { |out=0, freq=220, amp=0.3, cutoff=2500, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.002, 0.25), doneAction: 2);
    var sig = RLPF.ar(Saw.ar(freq.clip(40,2000) * [1, 1.005]), cutoff.clip(200,8000), 0.4);
    sig = Pan2.ar(Mix(sig) * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// sustained lead: gated ASR so notes hold for their full \dur (needs \legato).
SynthDef(\lp_lead, { |out=0, freq=220, amp=0.3, cutoff=3000, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 2);
    var sig = Mix(Saw.ar(freq.clip(40, 3000) * [0.997, 1.0, 1.005]));
    sig = RLPF.ar(sig, (cutoff.clip(300, 9000) * (1 + (env * 0.4))).clip(300, 12000), 0.28);
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.45;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_pad, { |out=0, freq=220, amp=0.0, cutoff=1500, gate=1, pan=0, rev=0|
    var sig = Mix(Saw.ar(freq.clip(40,1000) * [0.99, 1.0, 1.008, 2.0]));
    sig = RLPF.ar(sig, cutoff.clip(200,6000), 0.4);
    sig = sig * EnvGen.kr(Env.asr(1.5, 1, 2.0), gate, doneAction: 2);
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp.lag(0.5) * 0.25;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

// --- new drums ---
SynthDef(\lp_ride, { |out=0, amp=0.25, pan=0, rev=0|
    var env   = EnvGen.kr(Env.perc(0.001, 0.42), doneAction: 2);
    var noise = HPF.ar(WhiteNoise.ar, 7000) * env;
    var ring  = Ringz.ar(Impulse.ar(0), 3100, 0.08) * 0.35;
    var sig = Pan2.ar((noise + ring) * amp, pan.clip(-1,1));
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_rim, { |out=0, amp=0.35, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.055), doneAction: 2);
    var sig = (BPF.ar(WhiteNoise.ar, 2000, 0.8) + (SinOsc.ar(400) * 0.4)).tanh;
    sig = Pan2.ar(sig * env * amp, pan.clip(-1,1));
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_tom, { |out=0, amp=0.4, freq=160, pan=0, rev=0|
    var fenv = EnvGen.kr(Env([freq, freq * 0.5], [0.07], \exp));
    var env  = EnvGen.kr(Env.perc(0.003, 0.26), doneAction: 2);
    var sig = Pan2.ar(SinOsc.ar(fenv.clip(30, 600)) * env * amp, pan.clip(-1,1));
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

// --- new pitched / textural ---
// \cutoff=0 keeps the original freq-tracking filter; >0 (mod) sets it directly.
SynthDef(\lp_reese, { |out=0, freq=55, amp=0.0, gate=1, cutoff=0, pan=0, rev=0|
    var move = LFNoise2.kr(0.4).range(0.88, 1.12);
    var cut  = Select.kr(cutoff > 0, [(freq.clip(20, 200) * 5), cutoff]) * move;
    var sig  = Mix(Saw.ar(freq.clip(20, 200) * [0.999, 1.0, 1.013]));
    sig = RLPF.ar(sig, cut.clip(80, 3000), 0.35);
    sig = sig * EnvGen.kr(Env.asr(0.05, 1, 0.2), gate, doneAction: 2);
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp.lag(0.1);
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_bells, { |out=0, freq=440, amp=0.3, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 1.8, curve: -4), doneAction: 2);
    var f   = freq.clip(200, 4000);
    var sig = (SinOsc.ar(f)       * 0.55) +
              (SinOsc.ar(f * 2.0) * 0.28) +
              (SinOsc.ar(f * 3.0) * 0.12) +
              (SinOsc.ar(f * 4.1) * 0.05);
    sig = Pan2.ar(sig * env * amp, pan.clip(-1,1));
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_sweep, { |out=0, amp=0.0, gate=1, pan=0, rev=0|
    var env    = EnvGen.kr(Env.asr(3.0, 1, 2.0), gate, doneAction: 2);
    var fcut   = EnvGen.kr(Env([200, 6000], [10.0], \exp));
    var sig    = RLPF.ar(WhiteNoise.ar, fcut.clip(80, 14000), 0.12);
    sig = Pan2.ar(sig * env * amp.lag(0.5) * 0.6, pan.clip(-1,1));
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

// ===================================================================
//  Classic-machine emulations — extra matrix instrument choices.
//  All note-terminating (perc env + doneAction, or gated ASR) so they
//  are Pbind-safe; all take \pan + \rev like the lp_ voices. Standard
//  UGens only (no sc3-plugins). Tune by ear at the live gate.
// ===================================================================
// --- Roland TR-909 ---
SynthDef(\tr909_kick, { |out=0, amp=0.9, pan=0, rev=0|
    var fenv  = EnvGen.kr(Env([300, 54], [0.045], \exp));
    var aenv  = EnvGen.kr(Env.perc(0.001, 0.42, 1, -4), doneAction: 2);
    var click = HPF.ar(WhiteNoise.ar, 700) * EnvGen.kr(Env.perc(0.0003, 0.008)) * 0.5;
    var body  = SinOsc.ar(fenv) * aenv;
    var sig   = Pan2.ar(((body * 1.3) + click).tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr909_clap, { |out=0, amp=0.5, pan=0, rev=0|
    var env = EnvGen.ar(Env([0, 1, 0.4, 1, 0.3, 1, 0, 0.7, 0],
        [0.001, 0.009, 0.001, 0.009, 0.001, 0.009, 0.001, 0.16]), doneAction: 2);
    var sig = BPF.ar(WhiteNoise.ar, 1050, 0.75) * env * 2.2;
    sig = Pan2.ar(sig.tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr909_hat, { |out=0, amp=0.3, pan=0, rev=0, dur=0.06|
    var env = EnvGen.kr(Env.perc(0.001, dur, 1, -8), doneAction: 2);
    var osc = Mix(Pulse.ar([2003, 3079, 4111, 5519, 6883, 8087] * 0.5)) * 0.15;
    var sig = HPF.ar(osc, 7000) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr909_ride, { |out=0, amp=0.3, pan=0, rev=0|
    var env  = EnvGen.kr(Env.perc(0.001, 0.7, 1, -5), doneAction: 2);
    var osc  = Mix(Pulse.ar([1047, 1571, 2003, 3079, 4111])) * 0.1;
    var ring = Ringz.ar(Impulse.ar(0), 4200, 0.1) * 0.3;
    var sig  = (HPF.ar(osc, 3000) + ring) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland TR-808 ---
SynthDef(\tr808_kick, { |out=0, amp=0.9, freq=52, pan=0, rev=0|
    var fenv  = EnvGen.kr(Env([freq * 2.6, freq], [0.06], \exp));
    var aenv  = EnvGen.kr(Env.perc(0.001, 0.95, 1, -5), doneAction: 2);
    var click = SinOsc.ar(1800) * EnvGen.kr(Env.perc(0.0003, 0.006)) * 0.25;
    var body  = SinOsc.ar(fenv.clip(20, 400)) * aenv;
    var sig   = Pan2.ar((body + click).tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr808_clap, { |out=0, amp=0.5, pan=0, rev=0|
    var env = EnvGen.ar(Env([0, 1, 0.3, 1, 0.2, 1, 0, 0.5, 0],
        [0.001, 0.011, 0.001, 0.011, 0.001, 0.011, 0.001, 0.22]), doneAction: 2);
    var sig = BPF.ar(WhiteNoise.ar, 980, 0.9) * env * 2;
    sig = Pan2.ar(sig.tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr808_hat, { |out=0, amp=0.3, pan=0, rev=0, dur=0.05|
    var env = EnvGen.kr(Env.perc(0.001, dur, 1, -8), doneAction: 2);
    var osc = Mix(Pulse.ar([2063, 3013, 4759, 5503, 6817, 8243] * 0.5)) * 0.14;
    var sig = HPF.ar(osc, 8000) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\tr808_cowbell, { |out=0, amp=0.4, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.32, 1, -4), doneAction: 2);
    var osc = (Pulse.ar(540, 0.5) + Pulse.ar(800, 0.5)) * 0.5;
    var sig = BPF.ar(osc, 2640, 0.6) * env * 3;
    sig = Pan2.ar(sig.tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland TB-303 (acid) : saw -> env-swept resonant LPF + drive ---
SynthDef(\tb303, { |out=0, freq=110, amp=0.32, cutoff=500, res=0.82, fenvamt=2.6, pan=0, rev=0|
    var aenv = EnvGen.kr(Env.perc(0.004, 0.45, 1, -3), doneAction: 2);
    var fenv = EnvGen.kr(Env.perc(0.004, 0.32, 1, -4)) * fenvamt;
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.04);
    var cut  = (cutoff * (1 + fenv)).clip(60, 6500);
    var sig  = RLPF.ar(Saw.ar(freq.clip(20, 2000)), cut, rq);
    sig = (sig * 1.6).tanh * aenv;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Korg MS-20 (screaming resonant, gated lead/bass) ---
SynthDef(\ms20, { |out=0, freq=110, amp=0.3, cutoff=1200, res=0.8, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.005, 1, 0.14), gate, doneAction: 2);
    var osc = Saw.ar(freq.clip(20, 3000)) + Pulse.ar(freq.clip(20, 3000) * 1.004, 0.35);
    var rq  = res.clip(0, 1).linexp(0, 1, 1.0, 0.05);
    var sig = RLPF.ar(osc, cutoff.clip(60, 8000), rq);
    sig = (sig * 2.2).tanh;
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland SH-101 (mono saw+pulse+sub bass/lead, gated) ---
SynthDef(\sh101, { |out=0, freq=55, amp=0.3, cutoff=1500, res=0.3, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.006, 1, 0.2), gate, doneAction: 2);
    var sub = Pulse.ar((freq * 0.5).clip(10, 1000), 0.5) * 0.5;
    var osc = Saw.ar(freq.clip(20, 2000)) + (Pulse.ar(freq.clip(20, 2000), 0.45) * 0.5) + sub;
    var rq  = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig = RLPF.ar(osc, cutoff.clip(60, 7000), rq);
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.4;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Minimoog : 3-osc fat bass/lead, Moog ladder LPF (gated) ---
SynthDef(\minimoog, { |out=0, freq=55, amp=0.3, cutoff=1200, res=0.5, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.005, 1, 0.22), gate, doneAction: 2);
    var osc = Mix([Saw.ar(freq.clip(20,3000)), Saw.ar(freq.clip(20,3000) * 1.005),
        Pulse.ar((freq * 0.5).clip(10, 1500), 0.5)]) * 0.4;
    var sig = MoogFF.ar(osc, cutoff.clip(60, 8000), res.clip(0, 1) * 3.8);
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland JP-8000 supersaw : 7 detuned saws (trance/progressive lead) ---
SynthDef(\supersaw, { |out=0, freq=220, amp=0.3, cutoff=6000, res=0.2, detune=0.05, gate=1, pan=0, rev=0|
    var env  = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 2);
    var dets = [-3, -2, -1, 0, 1, 2, 3] * (detune / 3);
    var osc  = Mix(Saw.ar((freq.clip(20, 4000)) * (1 + dets))) * (1/7) * 2;
    var sig  = RLPF.ar(osc, cutoff.clip(200, 12000), (1 - res).clip(0.2, 1));
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.7;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland Juno-106 : saw+pulse+sub -> LPF + signature chorus (gated pad) ---
SynthDef(\juno, { |out=0, freq=110, amp=0.3, cutoff=2500, res=0.2, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.02, 1, 0.4), gate, doneAction: 2);
    var osc = Saw.ar(freq.clip(20, 3000))
        + (Pulse.ar(freq.clip(20, 3000), SinOsc.kr(0.3).range(0.3, 0.7)) * 0.6)
        + (Pulse.ar((freq * 0.5).clip(10, 1500), 0.5) * 0.4);
    var flt = RLPF.ar(osc * 0.3, cutoff.clip(200, 9000), (1 - res).clip(0.2, 1));
    var ch  = flt
        + DelayC.ar(flt, 0.03, SinOsc.kr(0.6, 0, 0.003, 0.008))
        + DelayC.ar(flt, 0.03, SinOsc.kr(0.5, pi, 0.003, 0.008));
    var sig = Pan2.ar(ch * 0.5 * env, pan.clip(-1, 1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Yamaha DX7 : 2-operator FM (bass / bell / e-piano) ---
SynthDef(\dx7, { |out=0, freq=110, amp=0.3, ratio=2.0, index=3, pan=0, rev=0|
    var env  = EnvGen.kr(Env.perc(0.004, 0.6, 1, -4), doneAction: 2);
    var menv = EnvGen.kr(Env.perc(0.001, 0.3, 1, -3));
    var mod  = SinOsc.ar(freq.clip(20, 4000) * ratio) * freq.clip(20, 4000) * ratio * index * menv;
    var sig  = SinOsc.ar(freq.clip(20, 4000) + mod) * env;
    sig = Pan2.ar(sig, pan.clip(-1, 1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- E-mu SP-1200 : 12-bit / ~26 kHz crunchy drum character ---
SynthDef(\sp1200, { |out=0, freq=120, amp=0.5, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 0.3, 1, -4), doneAction: 2);
    var src = (SinOsc.ar(freq.clip(30, 400)) + (WhiteNoise.ar * 0.5)) * env;
    var crushed = (Latch.ar(src, Impulse.ar(26040)) * 2048).round / 2048;
    var sig = Pan2.ar(crushed.tanh, pan.clip(-1, 1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Akai sampler (S950/S1100-ish) : 12-bit / 22 kHz lo-fi tonal grit ---
SynthDef(\akai_s, { |out=0, freq=220, amp=0.3, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.002, 0.5, 1, -3), doneAction: 2);
    var src = (Saw.ar(freq.clip(20, 3000)) + (Pulse.ar(freq.clip(20, 3000) * 1.5, 0.4) * 0.5)) * 0.4;
    var crushed = (Latch.ar(src, Impulse.ar(22050)) * 4096).round / 4096;
    var sig = RLPF.ar(crushed, 6000, 0.6) * env;
    sig = Pan2.ar(sig, pan.clip(-1, 1)) * amp * 0.6;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Roland System-100 : semi-modular saw/pulse + Moog-ish LPF (bass/lead) ---
SynthDef(\system100, { |out=0, freq=110, amp=0.3, cutoff=1500, res=0.4, gate=1, pan=0, rev=0|
    var env = EnvGen.kr(Env.asr(0.006, 1, 0.2), gate, doneAction: 2);
    var osc = (Saw.ar(freq.clip(20, 3000)) + Pulse.ar(freq.clip(20, 3000) * 0.999, 0.45)
        + (Pulse.ar((freq * 0.5).clip(10, 1500), 0.5) * 0.4)) * 0.3;
    var sig = MoogFF.ar(osc, cutoff.clip(60, 8000), res.clip(0, 1) * 3.6);
    sig = Pan2.ar(sig * env, pan.clip(-1, 1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- voices for the new matrix tracks (snare / crash / shaker / fx) ---
SynthDef(\lp_snare, { |out=0, amp=0.5, pan=0, rev=0|
    var env   = EnvGen.kr(Env.perc(0.001, 0.18, 1, -3), doneAction: 2);
    var tone  = (SinOsc.ar(180) + SinOsc.ar(330)) * 0.3;
    var noise = HPF.ar(WhiteNoise.ar, 1500) * 0.7;
    var sig   = Pan2.ar(((tone + noise) * env).tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_crash, { |out=0, amp=0.4, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.001, 1.5, 1, -4), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 5000) + (Mix(Pulse.ar([3001, 4211, 5503, 7019])) * 0.05);
    sig = HPF.ar(sig, 4000) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
SynthDef(\lp_shaker, { |out=0, amp=0.3, pan=0, rev=0|
    var env = EnvGen.kr(Env.perc(0.004, 0.06, 1, -2), doneAction: 2);
    var sig = HPF.ar(BPF.ar(WhiteNoise.ar, 6000, 0.5), 4000) * env * 3;
    sig = Pan2.ar(sig.tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// fx one-shot: slow-attack noise riser sweeping the filter up (len = seconds)
SynthDef(\lp_fx, { |out=0, amp=0.4, pan=0, rev=0, len=1.5|
    var env = EnvGen.kr(Env.perc(0.3, len, 1, 2), doneAction: 2);
    var cut = EnvGen.kr(Env([300, 9000], [len], \exp));
    var sig = RLPF.ar(WhiteNoise.ar, cut.clip(100, 15000), 0.2) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp * 0.6;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

// ===================================================================
//  Vintage 90s/2000s additions — 10 new classic-machine emulations.
//  All note-terminating; cutoff+res args where matrix ~matResVoices
//  targets exist for the assigned voice(s). Standard UGens only.
// ===================================================================
// --- Roland TR-909 Snare (2 sines + HPF noise, percussive) ---
SynthDef(\tr909_snare, { |out=0, amp=0.5, snappy=0.6, pan=0, rev=0|
    var tenv  = EnvGen.kr(Env.perc(0.001, 0.09, 1, -4));
    var nenv  = EnvGen.kr(Env.perc(0.001, 0.22, 1, -3), doneAction: 2);
    var tone  = (SinOsc.ar(180) + SinOsc.ar(330)) * tenv * 0.35;
    var noise = HPF.ar(WhiteNoise.ar, 1500) * nenv * snappy;
    var sig   = Pan2.ar(((tone + noise) * 2.0).tanh, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Alpha Juno-2 Hoover / Mentasm (PWM saw + pitch-drop + BBD chorus, gated) ---
SynthDef(\hoover, { |out=0, freq=110, amp=0.4, cutoff=8000, res=0.2, gate=1, pan=0, rev=0|
    var env  = EnvGen.kr(Env.asr(0.01, 1, 0.3), gate, doneAction: 2);
    var penv = EnvGen.kr(Env([1.5, 1.5, 1.0, 1.0], [0.01, 0.28, 0.5], [\lin, \exp, \lin]));
    var f    = freq.clip(40, 2000) * penv;
    var osc  = Saw.ar(f * (1 + SinOsc.kr(8, 0, 0.04)));
    var sub  = LFPulse.ar(f * 0.5, 0, 0.5) * 0.18;
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var flt  = RLPF.ar(osc + sub, cutoff.clip(200, 14000), rq);
    var ch   = flt
        + DelayC.ar(flt, 0.02, SinOsc.kr(0.5, 0, 0.004, 0.007))
        + DelayC.ar(flt, 0.02, SinOsc.kr(0.6, pi, 0.004, 0.007));
    var sig  = Pan2.ar(ch * 0.33 * env, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Korg M1 House Piano (additive + key-click, percussive) ---
SynthDef(\m1_piano, { |out=0, freq=440, amp=0.5, cutoff=8000, res=0.5, pan=0, rev=0|
    var f     = freq.clip(80, 4000);
    var click = SinOsc.ar(f * 8) * EnvGen.kr(Env.perc(0.0005, 0.008)) * 0.3;
    var env   = EnvGen.kr(Env.perc(0.001, 0.38, 1, -5), doneAction: 2);
    var osc   = Mix(SinOsc.ar(f * [1.0, 2.0, 3.0, 4.1, 5.2, 6.3, 7.5, 8.8], 0,
                    [1.0, 0.32, 0.12, 0.06, 0.03, 0.015, 0.008, 0.004]));
    var rq    = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig   = RLPF.ar((osc + click) * env, cutoff.clip(200, 14000), rq).tanh * 0.5;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Korg M1 Organ (drawbar additive harmonics, gated) ---
SynthDef(\m1_organ, { |out=0, freq=55, amp=0.3, cutoff=4000, res=0.3, gate=1, pan=0, rev=0|
    var f   = freq.clip(20, 1000);
    var osc = Mix(SinOsc.ar(f * [1, 2, 3, 4, 5, 6, 8], 0,
                  [0.8, 0.8, 0.6, 0.4, 0.2, 0.1, 0.1]));
    var env = EnvGen.kr(Env.asr(0.008, 1, 0.06), gate, doneAction: 2);
    var rq  = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig = RLPF.ar(osc * 0.12, cutoff.clip(200, 12000), rq).tanh;
    sig = Pan2.ar(sig * env, pan.clip(-1,1)) * amp * 0.55;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Yamaha DX7 Electric Piano (high-ratio FM tine click + body, percussive) ---
SynthDef(\dx7_epiano, { |out=0, freq=220, amp=0.4, cutoff=8000, res=0.5, modidx=0.3, pan=0, rev=0|
    var f    = freq.clip(40, 4000);
    var menv = EnvGen.kr(Env.perc(0.0003, 0.012, 1, -3));
    var mod  = SinOsc.ar(f * 14) * f * 14 * modidx * menv;
    var env  = EnvGen.kr(Env.perc(0.001, 0.5, 1, -3), doneAction: 2);
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig  = RLPF.ar(SinOsc.ar(f + mod) * env, cutoff.clip(200, 14000), rq) * 0.5;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- JP-8000 / Jupiter-8 Brass Stab (filter-env stab on dual saws, gated) ---
SynthDef(\brass_stab, { |out=0, freq=220, amp=0.4, cutoff=800, res=0.3, gate=1, pan=0, rev=0|
    var fenv = EnvGen.kr(Env.perc(0.003, 0.12, 1, -4));
    var aenv = EnvGen.kr(Env.asr(0.003, 1, 0.15), gate, doneAction: 2);
    var f    = freq.clip(30, 3000);
    var osc  = Mix(Saw.ar([f, f * 1.006])) + (Pulse.ar((f * 0.5).clip(10, 1500), 0.5) * 0.3);
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig  = RLPF.ar(osc, (cutoff + (fenv * 2000)).clip(100, 12000), rq);
    sig = Pan2.ar(sig * aenv, pan.clip(-1,1)) * amp * 0.45;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Nord Lead 2 VA Lead (2 detuned saws + delayed vibrato + filter, gated) ---
SynthDef(\nord_lead, { |out=0, freq=220, amp=0.3, cutoff=4000, res=0.3, gate=1, pan=0, rev=0|
    var env  = EnvGen.kr(Env.asr(0.005, 1, 0.2), gate, doneAction: 2);
    var f    = freq.clip(40, 5000);
    var vib  = SinOsc.kr(5) * 0.004 * EnvGen.kr(Env([0, 0, 1, 1], [0.2, 0.05, 0.5]));
    var f2   = f * (1 + vib);
    var osc  = Mix(Saw.ar([f2, f2 * 1.007]));
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig  = RLPF.ar(osc, (cutoff * (1 + (env * 0.3))).clip(200, 14000), rq);
    sig = Pan2.ar(sig * env, pan.clip(-1,1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Access Virus Hypersaw (9 detuned saws + soft saturation, gated) ---
SynthDef(\virus_saw, { |out=0, freq=220, amp=0.3, cutoff=6000, res=0.25, detune=0.08, gate=1, pan=0, rev=0|
    var env  = EnvGen.kr(Env.asr(0.002, 1, 0.2), gate, doneAction: 2);
    var f    = freq.clip(20, 5000);
    var dets = [-0.7, -0.5, -0.33, -0.17, 0, 0.17, 0.33, 0.5, 0.7] * detune;
    var osc  = HPF.ar((Mix(Saw.ar(f * (1 + dets))) * (1/9) * 3).tanh, 60);
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig  = RLPF.ar(osc, cutoff.clip(100, 18000), rq);
    sig = Pan2.ar(sig * env, pan.clip(-1,1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Rave Piano Stab (M1/S950 inharmonic additive, percussive) ---
SynthDef(\rave_stab, { |out=0, freq=440, amp=0.5, cutoff=8000, res=0.5, pan=0, rev=0|
    var f   = freq.clip(80, 4000);
    var osc = Mix(SinOsc.ar(f * [1.0, 2.002, 3.005, 4.007, 5.009, 6.012, 7.014, 8.016], 0,
                  [1.0, 0.4, 0.15, 0.08, 0.04, 0.02, 0.01, 0.005]));
    var env = EnvGen.kr(Env.perc(0.001, 0.3, 1, -4), doneAction: 2);
    var rq  = res.clip(0, 1).linexp(0, 1, 1.0, 0.1);
    var sig = RLPF.ar(osc * env, cutoff.clip(200, 14000), rq).tanh * 0.8;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp * 0.5;
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;
// --- Juno-106 Reese Bass (PWM pulse + BBD chorus, distinct from lp_reese multi-saw, gated) ---
SynthDef(\reese_juno, { |out=0, freq=55, amp=0.0, cutoff=0, res=0.3, gate=1, pan=0, rev=0|
    var env  = EnvGen.kr(Env.asr(0.02, 1, 0.12), gate, doneAction: 2);
    var f    = freq.clip(20, 200);
    var lfo  = SinOsc.kr(0.5);
    var pw   = lfo.range(0.3, 0.7);
    var osc  = Pulse.ar(f, pw) + (Pulse.ar(f * 1.007, 1.0 - pw) * 0.85);
    var ch   = osc
        + DelayC.ar(osc, 0.02, SinOsc.kr(0.6, 0, 0.003, 0.007))
        + DelayC.ar(osc, 0.02, SinOsc.kr(0.5, pi, 0.003, 0.007));
    var cut  = Select.kr(cutoff > 0, [(f * 5), cutoff]).clip(80, 3000);
    var rq   = res.clip(0, 1).linexp(0, 1, 1.0, 0.15);
    var sig  = LeakDC.ar(RLPF.ar(ch * 0.35, cut, rq)) * env;
    sig = Pan2.ar(sig, pan.clip(-1,1)) * amp.lag(0.1);
    Out.ar(out, sig);
    ~doReverbBus.notNil.if({ Out.ar(~doReverbBus, sig * rev) });
}).add;

s.sync;

~lp = ~lp ? ();
~lp[\clock] = TempoClock.default;   // horloge unique (Lot C)
~lp[\armed] = ~lp[\armed] ? Set.new;
~lp[\vol]       = ~lp[\vol]       ? IdentityDictionary.new;
~lp[\quant]     = ~lp[\quant]     ? 4;
~lp[\clipState] = ~lp[\clipState] ? IdentityDictionary.new;
~lp[\clipGen]   = ~lp[\clipGen]   ? IdentityDictionary.new;

// melody sequences: 8 varied riffs/arps/phrases, minor/phrygian feel
// wrapAt allows different lengths to loop cleanly over 16 16th-note steps
~lp[\melodies] = ~lp[\melodies] ? [
    [0, 2, 3, 5, 7, 5, 3, 2],
    [0, 3, 7, 3, 0, -2],
    [0, 0, 7, 0, 3, 5, 2, 0, 3, 5, 7, 3],
    [7, 5, 3, 2, 0, -2, 0, 2],
    [0, 2, 3, 5, 7, 10, 7, 5, 3, 0, 2, 3, 5, 3, 2, 0],
    [0, 3, 7],
    [0, 7, 5, 3, 7, 0],
    [2, 0, -2, 0, 3, 2, 0, -2, 5, 3, 2, 0],
];
~lp[\melSel]  = ~lp[\melSel]  ? 0;

// rhythm patterns: 16-step strings (1=hit, 0=rest) for kick / snare / hat
~lp[\rhythms] = ~lp[\rhythms] ? [
    (name: "4floor",     k: "1000100010001000", s: "0000100000001000", h: "0010101010101010"),
    (name: "breakbeat",  k: "1000101010001000", s: "0000100100001001", h: "0101010101010101"),
    (name: "halftime",   k: "1000000010000000", s: "0000000000001000", h: "0010001001000010"),
    (name: "psyroll",    k: "1001100110011001", s: "0000100000001000", h: "1111111111111111"),
    (name: "garage",     k: "1000001010000010", s: "0000100000001000", h: "0101101001011010"),
    (name: "tribal",     k: "1010100010101000", s: "0000101000001010", h: "1010101010101010"),
    (name: "industrial", k: "1100110011001100", s: "0011001100110011", h: "0101010101010101"),
    (name: "jungle",     k: "1000100110001001", s: "0000100100001001", h: "1011101110111011"),
];
~lp[\rhySel]  = ~lp[\rhySel]  ? 0;

// clock-sync helper: use concert clock when concert is running
~lpClock = {
    (~concert.notNil and: {
        (~concert[\running] == true) and: { ~concert[\clock].notNil }
    }).if({ ~concert[\clock] }, { ~lp[\clock] })
};

// per-pattern volume (default 0.8, max 1.5)
~lpVol = { |nm| (~lp[\vol][nm] ? 0.8).clip(0, 1.5) };

// note helper (nil-guards ~ccNote)
~lpNote = { |deg, oct=0|
    ~ccNote.notNil.if({ ~ccNote.(deg, oct) }, { ~noteFor.(deg, \minor, 45, oct) })
};

// --- 10 original Pdefs (all \amp wrapped with ~lpVol) ---
Pdef(\lp_kick, Pbind(\instrument, \lp_kick, \dur, 1,
    \amp, Pfunc { 0.9 * ~lpVol.(\kick) }));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat, \dur, Pseq([Rest(0.5), 0.5], inf),
    \amp, Pfunc { 0.28 * ~lpVol.(\hats) }));
Pdef(\lp_clap, Pbind(\instrument, \lp_clap, \dur, Pseq([Rest(1), 1], inf),
    \amp, Pfunc { 0.5 * ~lpVol.(\clap) }));
Pdef(\lp_perc, Pbind(\instrument, \lp_perc,
    \dur, Pseq([0.75, 0.25, 0.5, 0.5], inf),
    \freq, Pseq([420, 640, 520], inf),
    \amp, Pfunc { 0.32 * ~lpVol.(\perc) }));

Pdef(\lp_sub, Pbind(\instrument, \lp_sub, \dur, 4,
    \freq, Pfunc { ~lpNote.(0, -1).midicps },
    \amp, Pfunc { 0.22 * ~lpVol.(\sub) }, \legato, 1));
Pdef(\lp_acid, Pbind(\instrument, \lp_acid, \dur, 0.25,
    \degree, Pseq([0,0,7,0,3,0,5,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 0).midicps },
    \cutoff, Pseq([500,900,1400,700], inf), \res, 0.32,
    \amp, Pfunc { 0.26 * ~lpVol.(\acid) }, \pan, Pwhite(-0.2,0.2)));
Pdef(\lp_arp, Pbind(\instrument, \lp_pluck, \dur, 0.25,
    \degree, Pseq([0,2,4,7,4,2], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \cutoff, 3000, \amp, Pfunc { 0.2 * ~lpVol.(\arp) }, \pan, Pwhite(-0.3,0.3)));
Pdef(\lp_lead, Pbind(\instrument, \lp_lead, \dur, Pseq([1, 0.5, 0.5, 2], inf),
    \degree, Pseq([7,5,4,0,2,4], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \cutoff, 4000, \amp, Pfunc { 0.24 * ~lpVol.(\lead) }, \legato, 1));
Pdef(\lp_stab, Pbind(\instrument, \lp_pluck, \dur, Pseq([Rest(0.5), 0.5], inf),
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, 2200, \amp, Pfunc { 0.2 * ~lpVol.(\stab) }));
Pdef(\lp_pad, Pbind(\instrument, \lp_pad, \dur, 8,
    \freq, Pfunc { [0,2,4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, Pfunc { ((~ccHarmony ? ()).at(\pad) == \bright).if({ 3200 }, { 1200 }) },
    \amp, Pfunc { 0.3 * ~lpVol.(\pad) }, \legato, 1));

// --- 6 new Pdefs ---
Pdef(\lp_ride, Pbind(\instrument, \lp_ride,
    \dur, Pseq([0.5, 0.5, 0.5, Rest(0.5)], inf),
    \amp, Pfunc { 0.25 * ~lpVol.(\ride) }));
Pdef(\lp_rim, Pbind(\instrument, \lp_rim,
    \dur, Pseq([Rest(1), 0.5, Rest(0.5), Rest(1), 0.5, Rest(0.5)], inf),
    \amp, Pfunc { 0.35 * ~lpVol.(\rim) }));
Pdef(\lp_tom, Pbind(\instrument, \lp_tom,
    \dur, Pseq([Rest(1.5), 0.5, Rest(1), 1], inf),
    \freq, Pseq([180, 120, 160], inf),
    \amp, Pfunc { 0.4 * ~lpVol.(\tom) }));
Pdef(\lp_reese, Pbind(\instrument, \lp_reese, \dur, 8,
    \freq, Pfunc { ~lpNote.(0, -1).midicps },
    \amp, Pfunc { 0.3 * ~lpVol.(\reese) }, \legato, 1));
Pdef(\lp_bells, Pbind(\instrument, \lp_bells,
    \dur, Pseq([2, 1.5, 2.5, 2], inf),
    \degree, Pseq([0, 2, 4, 7], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 2).midicps },
    \amp, Pfunc { 0.22 * ~lpVol.(\bells) }));
Pdef(\lp_sweep, Pbind(\instrument, \lp_sweep, \dur, 8,
    \amp, Pfunc { 0.25 * ~lpVol.(\sweep) }, \legato, 1));

// --- new matrix tracks: melody / chord / fx / snare / crash / shaker ---
Pdef(\lp_melody, Pbind(\instrument, \lp_pluck,
    \dur, Pseq([0.5, 0.5, 1, 0.5, 1.5], inf),
    \degree, Pseq([0, 3, 5, 7, 5, 3, 2, 0], inf),
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \cutoff, 3500, \amp, Pfunc { 0.22 * ~lpVol.(\melody) }, \pan, Pwhite(-0.2, 0.2)));
Pdef(\lp_chord, Pbind(\instrument, \lp_pad, \dur, 4,
    \freq, Pfunc { [0, 2, 4].collect { |d| ~lpNote.(d, 0).midicps } },
    \cutoff, 2000, \amp, Pfunc { 0.3 * ~lpVol.(\chord) }, \legato, 1));
Pdef(\lp_fx, Pbind(\instrument, \lp_fx, \dur, 8,
    \amp, Pfunc { 0.3 * ~lpVol.(\fx) }));
Pdef(\lp_snare, Pbind(\instrument, \lp_snare,
    \dur, Pseq([Rest(1), 1], inf),
    \amp, Pfunc { 0.5 * ~lpVol.(\snare) }));
Pdef(\lp_crash, Pbind(\instrument, \lp_crash, \dur, 8,
    \amp, Pfunc { 0.4 * ~lpVol.(\crash) }));
Pdef(\lp_shaker, Pbind(\instrument, \lp_shaker,
    \dur, Pseq([0.25, 0.25, 0.25, 0.25], inf),
    \amp, Pfunc { 0.28 * ~lpVol.(\shaker) }));

// --- melody sequencer: single Pdef, armed via normal /launch path ---
// reuses \lp_pluck; selects from ~lp[\melodies][~lp[\melSel]] via wrapAt
Pdef(\lp_melseq, Pbind(
    \instrument, \lp_pluck,
    \stepIdx, Pseq((0..15), inf),
    \degree, Pfunc { |e|
        var mel = ~lp[\melodies];
        var sel = ~lp[\melSel] ? 0;
        (mel.notNil and: { mel.size > 0 }).if({
            mel[sel.clip(0, mel.size - 1)].wrapAt(e[\stepIdx])
        }, { 0 })
    },
    \freq, Pfunc { |e| ~lpNote.(e[\degree], 1).midicps },
    \dur, 0.25,
    \cutoff, 3500,
    \amp, Pfunc { 0.22 * ~lpVol.(\melseq) },
    \pan, Pwhite(-0.25, 0.25)
));

// --- rhythm sub-Pdefs: 3 voices armed together via rhythmseq special-case in ~lpArm ---
// \type \rest = true rest (no synth), \type \note = hit
Pdef(\lp_rsk, Pbind(
    \instrument, \lp_kick,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\k);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.9 * ~lpVol.(\rhythmseq) }
));
Pdef(\lp_rss, Pbind(
    \instrument, \lp_clap,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\s);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.5 * ~lpVol.(\rhythmseq) }
));
Pdef(\lp_rsh, Pbind(
    \instrument, \lp_hat,
    \stepIdx, Pseq((0..15), inf),
    \dur, 0.25,
    \type, Pfunc { |e|
        var pat = ~lp[\rhythms];
        var sel = ~lp[\rhySel] ? 0;
        var row;
        (pat.notNil and: { pat.size > 0 }).if({
            row = pat[sel.clip(0, pat.size - 1)].at(\h);
            (row.notNil and: { row.at(e[\stepIdx]) == $1 }).if({ \note }, { \rest })
        }, { \rest })
    },
    \amp, Pfunc { 0.28 * ~lpVol.(\rhythmseq) }
));

// arm / disarm a pattern by bare name (e.g. "kick" -> Pdef(\lp_kick))
// "rhythmseq" special-cases: arms/disarms \lp_rsk, \lp_rss, \lp_rsh together
// 4-state machine per clip: 0=off, 1=playing, 2=queued-launch, 3=queued-stop
// Launch and stop are quantized to ~lp[\quant] beats on the TempoClock.
// A generation counter per clip cancels superseded pending callbacks.
~lpArm = { |name, on|
    var nm, keys, clock, q, s, gen, isRhythm;
    nm       = name.asSymbol;
    isRhythm = (name.asString == "rhythmseq");
    keys     = isRhythm.if(
        { [\lp_rsk, \lp_rss, \lp_rsh] },
        { [("lp_" ++ name.asString).asSymbol] }
    );
    (isRhythm or: { Pdef.all.includesKey(keys[0]) }).if({
        clock = ~lp[\clock] ? (~lpClock.value ? TempoClock.default);
        q     = ~lp[\quant] ? 4;
        s     = ~lp[\clipState][nm] ? 0;
        on.if({
            // launch tap
            (s == 0).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                ~lp[\clipState][nm] = 2;
                ~lp[\armed].add(nm);
                keys.do { |k| Pdef(k).play(clock, quant: q) };
                clock.schedAbs(clock.nextTimeOnGrid(q), {
                    (~lp[\clipGen][nm] == gen).if({ ~lp[\clipState][nm] = 1 });
                    nil
                });
            });
            (s == 3).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                // queued-stop cancelled: clip still playing, revert to 1
                ~lp[\clipState][nm] = 1;
                ~lp[\armed].add(nm);
            });
            // s == 1 or s == 2: no-op (pending closure preserved)
        }, {
            // stop tap
            (s == 1).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                ~lp[\clipState][nm] = 3;
                ~lp[\armed].remove(nm);
                clock.schedAbs(clock.nextTimeOnGrid(q), {
                    (~lp[\clipGen][nm] == gen).if({
                        keys.do { |k| Pdef(k).stop };
                        ~lp[\clipState][nm] = 0;
                    });
                    nil
                });
            });
            (s == 2).if({
                gen = (~lp[\clipGen][nm] ? 0) + 1; ~lp[\clipGen][nm] = gen;
                // queued-launch cancelled: stop before it fires
                keys.do { |k| Pdef(k).stop };
                ~lp[\clipState][nm] = 0;
                ~lp[\armed].remove(nm);
            });
            // s == 0 or s == 3: no-op (pending closure preserved)
        });
    });
};

OSCdef(\lpLaunch, { |msg|
    ~lpArm.((msg[1] ? \nil).asString, (msg[2] ? 0) > 0);
}, '/launch');
OSCdef(\lpTempo, { |msg|
    ~setTempo.((msg[1] ? 126).clip(60, 200));
}, '/launch/tempo');
OSCdef(\lpClear, { |msg|
    ~lp[\armed].copy.do { |nm| ~lpArm.(nm, false) };
}, '/launch/clear');
OSCdef(\lpVol, { |msg|
    ~lp[\vol][(msg[1] ? \nil).asSymbol] = (msg[2] ? 0.8).clip(0, 1.5);
}, '/launch/vol');
OSCdef(\lpQuant, { |msg|
    ~lp[\quant] = (msg[1] ? 4).asFloat.clip(0.125, 64);
}, '/launch/quant');

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

OSCdef(\seqMelody, { |msg|
    ~lp.notNil.if({
        var n = (msg[1] ? 0).asInteger;
        ~lp[\melSel] = n.clip(0, ~lp[\melodies].notNil.if({ ~lp[\melodies].size - 1 }, { 0 }));
    });
}, '/seq/melody');
OSCdef(\seqRhythm, { |msg|
    ~lp.notNil.if({
        var n = (msg[1] ? 0).asInteger;
        ~lp[\rhySel] = n.clip(0, ~lp[\rhythms].notNil.if({ ~lp[\rhythms].size - 1 }, { 0 }));
    });
}, '/seq/rhythm');

OSCdef(\seqRhythmSet, { |msg|
    var sel;
    ~lp.notNil.if({
        sel = (~lp[\rhySel] ? 0).clip(0, (~lp[\rhythms].notNil.if({ ~lp[\rhythms].size - 1 }, { 0 })));
        ~lp[\rhythms][sel] = (
            name: (~lp[\rhythms][sel][\name] ? "edit"),
            k: msg[1].asString,
            s: msg[2].asString,
            h: msg[3].asString
        );
    });
}, '/seq/rhythm/set');

OSCdef(\seqMelodySet, { |msg|
    var sel, degs;
    ~lp.notNil.if({
        sel = (~lp[\melSel] ? 0).clip(0, (~lp[\melodies].notNil.if({ ~lp[\melodies].size - 1 }, { 0 })));
        (msg.size > 1).if({
            degs = (1..(msg.size - 1)).collect { |i| msg[i].asInteger };
            ~lp[\melodies][sel] = degs;
        });
    });
}, '/seq/melody/set');

"[data-only/launchpad] 16 patterns + 2 sequencers (melseq+rhythmseq) + clock-sync + vol faders ready".postln;
)
