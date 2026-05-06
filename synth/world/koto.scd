// =====================================================================
//  synth/world/koto.scd  --  SynthDef \koto
//  Extracted from asia.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\koto, {
    arg freq = 220, gate = 1, cutoff = 6000, rq = 0.5,
        attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.6,
        drive = 1.2, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, harm;
    exciter = WhiteNoise.ar(0.6) * EnvGen.kr(Env.perc(0.0005, 0.003));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, freq.reciprocal, 3.0));
    // Harmonique 2 (octave) ajoute pour brillance koto
    harm = LeakDC.ar(CombC.ar(exciter * 0.3, 0.05, (freq * 2).reciprocal, 1.5));
    sig = LPF.ar(ks + harm, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
