// =====================================================================
//  fx/trick/sweep.scd  --  SynthDef \sweep
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\sweep, {
        arg dur = 4, startCutoff = 8000, endCutoff = 200,
            amp = 0.25, pan = 0;
        var noise, cutoff, env, sig;
        cutoff = Line.kr(startCutoff, endCutoff, dur);
        noise = WhiteNoise.ar + (PinkNoise.ar * 0.5);
        sig = LPF.ar(noise, cutoff);
        sig = BPF.ar(sig, cutoff * 1.2, 0.5);
        env = EnvGen.kr(Env.linen(0.05, dur - 0.1, 0.05), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
