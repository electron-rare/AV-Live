// =====================================================================
//  synth/drums/kick808.scd  --  SynthDef \kick808
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\kick808, {
    arg freq = 50, glide = 0.04, decay = 0.7,
        drive = 1.4, amp = 0.6, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, click, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 5, freq], [0.025], \exp));
    body = SinOsc.ar(pEnv);
    click = HPF.ar(WhiteNoise.ar, 1500) *
            EnvGen.kr(Env.perc(0.0005, 0.003));
    ampEnv = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
    sig = body + (click * 0.15);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
