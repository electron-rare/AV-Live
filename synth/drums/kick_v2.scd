// synth/drums/kick_v2.scd  --  SynthDef \kick_v2  // variation kick basique
(
SynthDef(\kick_v2, {
    arg freq = 45, pitchAmt = 3.0, pitchTime = 0.035,
        decay = 0.3, drive = 1.3, click = 0.2,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 3500) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.3) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
