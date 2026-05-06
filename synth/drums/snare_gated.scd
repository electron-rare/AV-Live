// =====================================================================
//  synth/drums/snare_gated.scd  --  SynthDef \snareGated
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\snareGated, {
    arg freq = 200, decay = 0.2, gateTime = 0.15,
        amp = 0.5, pan = 0;
    var tone, noise, env, gate, sig;
    tone = SinOsc.ar(freq) * EnvGen.kr(Env.perc(0.001, 0.04));
    noise = HPF.ar(WhiteNoise.ar, 1200) *
            EnvGen.kr(Env.perc(0.001, decay));
    sig = (tone * 0.4) + (noise * 0.6);
    // Gated reverb : signal + reverb tronque par envelope gate
    sig = sig + (CombC.ar(sig, 0.05, 0.04, 0.3) *
                 EnvGen.kr(Env([0, 1, 1, 0], [0.001, gateTime, 0.005])));
    env = EnvGen.kr(Env.linen(0.001, gateTime, 0.005), doneAction: 2);
    sig = (sig * 1.4).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
