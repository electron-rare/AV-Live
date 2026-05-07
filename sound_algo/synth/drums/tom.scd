// =====================================================================
//  synth/drums/tom.scd  --  SynthDef \tom
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\tom, {
        arg freq = 110, decay = 0.3, drive = 1.4, amp = 0.5, pan = 0;
        var pitchEnv, body, noise, sig, env;
        pitchEnv = EnvGen.kr(Env([freq * 1.8, freq], [0.04], -3));
        body = SinOsc.ar(pitchEnv) + (Saw.ar(pitchEnv) * 0.2);
        noise = HPF.ar(WhiteNoise.ar, 2000) * EnvGen.kr(Env.perc(0.001, 0.01));
        sig = body + (noise * 0.3);
        env = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
        sig = (sig * drive).tanh;
        sig = LeakDC.ar(sig) * env * amp;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
