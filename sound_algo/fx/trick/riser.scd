// =====================================================================
//  fx/trick/riser.scd  --  SynthDef \riser
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\riser, {
        arg dur = 4, startCutoff = 300, endCutoff = 8000,
            amp = 0.3, pan = 0;
        var noise, cutoff, env, sig;
        cutoff = Line.kr(startCutoff, endCutoff, dur).clip(20, 18000);
        noise = (WhiteNoise.ar * 0.5) + (PinkNoise.ar * 0.3);
        sig = HPF.ar(noise, cutoff);
        sig = BPF.ar(sig, cutoff.min(15000), 0.4);
        env = EnvGen.kr(
            Env.new([0, 0.3, 1, 0], [dur * 0.5, dur * 0.45, dur * 0.05], \sin),
            doneAction: 2
        );
        sig = LeakDC.ar(sig * env * amp);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
