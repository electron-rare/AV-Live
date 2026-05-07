// =====================================================================
//  synth/drums/kick_gabber.scd  --  SynthDef \kickGabber
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\kickGabber, {
    arg freq = 50, decay = 0.32, drive = 6.0, click = 0.4,
        amp = 0.55, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 4, freq], [0.04], -3));
    body = SinOsc.ar(pEnv) + (Saw.ar(pEnv) * 0.3);
    sub = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 4000) *
               EnvGen.kr(Env.perc(0.0005, 0.005));
    sig = body + (sub * 0.4) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).clip(-1, 1);                   // hard clip gabber
    sig = (sig * 1.4).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
