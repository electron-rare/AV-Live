// =====================================================================
//  synth/world/taiko.scd  --  SynthDef \taiko
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\taiko, {
    arg freq = 70, decay = 0.6, drive = 1.4, amp = 0.5, pan = 0;
    var pEnv, body, skin, env, sig;
    pEnv = EnvGen.kr(Env([freq * 1.5, freq], [0.04], -3));
    body = SinOsc.ar(pEnv) + (Saw.ar(pEnv) * 0.15);
    skin = HPF.ar(WhiteNoise.ar, 800) *
           EnvGen.kr(Env.perc(0.001, 0.04));
    sig = body + (skin * 0.4);
    env = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig) * env * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
