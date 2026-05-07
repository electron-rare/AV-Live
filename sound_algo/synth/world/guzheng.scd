// =====================================================================
//  synth/world/guzheng.scd  --  SynthDef \guzheng
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\guzheng, {
    arg freq = 220, gate = 1,
        bendAmt = 0.025, bendTime = 0.3,
        cutoff = 5500, rq = 0.4,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 1.5,
        drive = 1.1, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, harm, bentFreq;
    // Bend caracteristique guzheng (slide vers la note finale)
    bentFreq = freq * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -2)));
    exciter = WhiteNoise.ar(0.6) * EnvGen.kr(Env.perc(0.0005, 0.003));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, 4.0));
    // Harmonique octave + 5te (caractere chinois)
    harm = LeakDC.ar(CombC.ar(exciter * 0.25, 0.05, (bentFreq * 1.5).reciprocal, 2.0));
    sig = LPF.ar(ks + harm, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
