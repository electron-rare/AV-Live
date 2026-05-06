// synth/drums/kick_v5.scd  --  SynthDef \kick_v5  // variation kick basique
(
SynthDef(\kick_v5, {
    arg freq = 60, pitchAmt = 5.0, pitchTime = 0.02,
        decay = 0.5, drive = 2.0, click = 0.1,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.16;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -2));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 5000) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.2) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
