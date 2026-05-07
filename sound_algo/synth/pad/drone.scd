// =====================================================================
//  synth/pad/drone.scd  --  SynthDef \drone
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\drone, {
    arg freq = 110, gate = 1, detune = 0.01,
        cutoff = 1800, rq = 0.4, modRate = 0.15, modDepth = 600,
        attack = 1.5, decay = 0.5, sustain = 0.85, release = 3.0,
        drive = 1.1, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, fc, voices;
    fc = (cutoff + (LFNoise2.kr(modRate) * modDepth)).clip(60, 8000);
    voices = (Saw.ar(freq * (1 - detune)) * 0.4) +
             (Saw.ar(freq * (1 + detune)) * 0.4) +
             (SinOsc.ar(freq * 0.5) * 0.3);   // sub
    sig = RLPF.ar(voices, fc, rq);
    sig = sig + (DelayC.ar(sig, 0.05,
        SinOsc.kr(0.2, 0).range(0.01, 0.04)) * 0.3);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
