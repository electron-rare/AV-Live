// synth/world/guzheng_v5.scd  --  SynthDef \guzheng_v5  // variation guzheng pluck Karplus
(
SynthDef(\guzheng_v5, {
    arg freq = 330, gate = 1, bendAmt = 0.06, bendTime = 0.05,
        cutoff = 3000, rq = 0.4,
        attack = 0.001, decay = 0.08, sustain = 0.0, release = 0.5,
        drive = 1.0, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, bentFreq, f;
    f = freq.clip(40, 6000);
    bentFreq = f * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -3)));
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, 0.005));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, 3.0));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).softclip;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
