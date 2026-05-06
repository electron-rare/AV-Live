// =====================================================================
//  synth/drums/rim.scd  --  SynthDef \rim
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\rim, {
        arg freq = 1500, decay = 0.04, amp = 0.3, pan = 0;
        var sig, env;
        sig = SinOsc.ar(freq) + (HPF.ar(WhiteNoise.ar, 4000) * 0.5);
        sig = BPF.ar(sig, freq * 1.5, 0.3);
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -5), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
