// =====================================================================
//  synth/lead/rhodes.scd  --  SynthDef \rhodes
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\rhodes, {
    arg freq = 440, gate = 1,
        modRatio = 14, modIndex = 0.4,        // Rhodes : 14:1 ratio
        cutoff = 4000, rq = 0.6,
        attack = 0.002, decay = 0.2, sustain = 0.0, release = 0.8,
        drive = 1.1, amp = 0.20, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, mod, idxEnv, chorus;
    idxEnv = EnvGen.kr(Env([modIndex * 2, 0], [0.4], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv;
    sig = SinOsc.ar(freq + (mod * 0.5));
    sig = LPF.ar(sig, cutoff);
    chorus = DelayC.ar(sig, 0.02, SinOsc.kr(0.7).range(0.002, 0.012));
    sig = sig + (chorus * 0.4);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -4),
                    gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
