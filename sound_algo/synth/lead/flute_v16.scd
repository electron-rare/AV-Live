// synth/lead/flute_v16.scd  --  SynthDef \flute_v16  // variation flute_lead pluck Karplus-Strong
(
SynthDef(\flute_v16, {
    arg freq = 440, gate = 1, decayTime = 2.0,
        cutoff = 6000,
        attack = 0.001, decay = 0.1, sustain = 0.1, release = 0.3,
        drive = 2.0, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, exciter, ks, duck, f;
    f = freq.clip(30, 6000);
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, 0.01));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, f.reciprocal, decayTime));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
