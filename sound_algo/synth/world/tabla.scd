// =====================================================================
//  synth/world/tabla.scd  --  SynthDef \tabla
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\tabla, {
    arg freq = 220, decay = 0.18, drive = 1.3, amp = 0.4, pan = 0;
    var pEnv, body, slap, env, sig;
    pEnv = EnvGen.kr(Env([freq * 3, freq], [0.02], -4));
    body = SinOsc.ar(pEnv) + (SinOsc.ar(pEnv * 1.5) * 0.2);
    slap = HPF.ar(WhiteNoise.ar, 2500) *
           EnvGen.kr(Env.perc(0.001, 0.012));
    sig = body + (slap * 0.5);
    env = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
