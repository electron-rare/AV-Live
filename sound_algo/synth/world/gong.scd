// =====================================================================
//  synth/world/gong.scd  --  SynthDef \gong
//  Extracted from asia.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\gong, {
    arg freq = 80, decay = 4, amp = 0.5, pan = 0;
    var sig, env, partials, pitchEnv;
    // Pitch drop expo (caracteristique gong)
    pitchEnv = EnvGen.kr(Env([freq * 1.3, freq], [0.15], \exp));
    // Plusieurs partiels inharmoniques (gong : ratios non-entiers)
    partials = [1, 1.41, 1.93, 2.71, 3.42, 4.83];
    sig = Mix.fill(partials.size, { |i|
        SinOsc.ar(pitchEnv * partials[i]) *
            (1 / (i + 1)) *
            EnvGen.kr(Env.perc(0.005, decay * (1 - (i * 0.12)), 1, -3 - i));
    });
    sig = sig + (HPF.ar(WhiteNoise.ar, 4000) *
                 EnvGen.kr(Env.perc(0.001, 0.05)) * 0.3);
    env = EnvGen.kr(Env.linen(0.001, decay, 0.05), doneAction: 2);
    sig = (sig * 1.3).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
