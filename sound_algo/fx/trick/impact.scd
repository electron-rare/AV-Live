// =====================================================================
//  fx/trick/impact.scd  --  SynthDef \impact
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\impact, {
        arg freq = 45, decay = 1.5, amp = 0.7, pan = 0;
        var pitchEnv, body, noise, env, sig;
        pitchEnv = EnvGen.kr(Env([freq * 5, freq * 0.5], [0.12], \exp));
        body = SinOsc.ar(pitchEnv);
        noise = LPF.ar(WhiteNoise.ar, 800) *
                EnvGen.kr(Env.perc(0.001, 0.4));
        sig = body + (noise * 0.5);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
        sig = sig * env;
        sig = (sig * 1.5).tanh;
        sig = LeakDC.ar(sig) * amp;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
