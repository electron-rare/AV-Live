// =====================================================================
//  data_only/synthdefs_play.scd -- palette \bp_* pour scene_pose_play.
//  Corps-joue : lead (main D), arp (main G), pad (mode), bass, kick, hat.
//  Toutes stereo, doneAction:2 sur les envs one-shot.
// =====================================================================
(
SynthDef(\bp_lead, { |out=0, freq=440, amp=0.3, dur=0.5, cutoff=2000, pan=0, rev=0.3|
    var env = EnvGen.kr(Env.perc(0.005, dur, 1, -4), doneAction: 2);
    var sig = Saw.ar(freq.clip(40, 8000) * [1, 1.003]).sum * 0.5;
    sig = RLPF.ar(sig, (cutoff * (1 + env)).clip(80, 9000), 0.3);
    sig = (sig * env * amp).tanh;
    Out.ar(out, Pan2.ar(sig, pan) * (1 - rev));
    Out.ar(out, Pan2.ar(sig, pan) * rev * 0.5);
}).add;

SynthDef(\bp_arp, { |out=0, freq=440, amp=0.22, dur=0.25, pan=0, rev=0.3|
    var env = EnvGen.kr(Env.perc(0.003, dur, 1, -6), doneAction: 2);
    var sig = (SinOsc.ar(freq.clip(40, 8000)) + (LFTri.ar(freq * 2) * 0.2));
    sig = (sig * env * amp).tanh;
    Out.ar(out, Pan2.ar(sig, pan) * (1 - rev));
    Out.ar(out, Pan2.ar(sig, pan) * rev * 0.5);
}).add;

SynthDef(\bp_pad, { |out=0, freq=110, amp=0.0, cutoff=1200, gate=1, pan=0, rev=0.4|
    var env = EnvGen.kr(Env.asr(2, 1, 3), gate, doneAction: 2);
    var detune = [1, 1.004, 0.997, 2.002];
    var sig = Saw.ar(freq.clip(30, 4000) * detune).sum * 0.25;
    sig = LeakDC.ar(sig);
    sig = RLPF.ar(sig, (cutoff * SinOsc.kr(0.07).range(0.6, 1.0)).clip(80, 6000), 0.4);
    sig = sig * env * amp.lag(1.5);
    Out.ar(out, Pan2.ar(sig, pan) * (1 - rev));
    Out.ar(out, Pan2.ar(sig, pan) * rev);
}).add;

SynthDef(\bp_bass, { |out=0, freq=55, amp=0.4, dur=0.5, pan=0, rev=0.2|
    var env = EnvGen.kr(Env.perc(0.005, dur, 1, -3), doneAction: 2);
    var sub = SinOsc.ar(freq.clip(25, 400));
    var saw = LPF.ar(Saw.ar(freq.clip(25, 400)), freq * 4);
    var sig = ((sub + (saw * 0.4)) * env * amp).tanh;
    Out.ar(out, Pan2.ar(sig, pan) * (1 - rev));
}).add;

SynthDef(\bp_kick, { |out=0, amp=0.55, dur=0.3|
    var env = EnvGen.kr(Env.perc(0.001, dur, 1, -5), doneAction: 2);
    var fenv = EnvGen.kr(Env([180, 50, 40], [0.03, dur], \exp));
    var sig = (SinOsc.ar(fenv) * env * amp).tanh;
    Out.ar(out, sig ! 2);
}).add;

SynthDef(\bp_hat, { |out=0, amp=0.3, pan=0, dur=0.05|
    var env = EnvGen.kr(Env.perc(0.001, dur, 1, -8), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar, 7000) * env * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

"[data-only/synthdefs_play] 6 SynthDefs added (\\bp_*)".postln;
)
