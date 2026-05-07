// =====================================================================
//  synth/lead/pluck.scd  --  SynthDef \pluck
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\pluck, {
        arg freq = 220, gate = 1,
            cutoff = 5000, rq = 0.5,
            attack = 0.001, decay = 0.05, sustain = 0.0, release = 0.5,
            drive = 1.0, amp = 0.22, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck, exciter, ks;
        exciter = WhiteNoise.ar(0.5) * EnvGen.kr(Env.perc(0.0005, 0.005));
        ks = LeakDC.ar(CombC.ar(exciter, 0.05, freq.reciprocal, 2.5));
        sig = LPF.ar(ks, cutoff);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;
)
