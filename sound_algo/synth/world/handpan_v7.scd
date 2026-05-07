// synth/world/handpan_v7.scd  --  SynthDef \handpan_v7  // variation handpan pluck Karplus
(
SynthDef(\handpan_v7, {
    arg freq = 220, gate = 1, bendAmt = 0.03, bendTime = 0.1,
        cutoff = 5000, rq = 0.3,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 0.3,
        drive = 1.6, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, bentFreq, f;
    f = freq.clip(40, 6000);
    bentFreq = f * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -3)));
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, 0.003));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, 1.8));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).softclip;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
