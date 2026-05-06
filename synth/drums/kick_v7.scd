// synth/drums/kick_v7.scd  --  SynthDef \kick_v7  // variation kick basique
(
SynthDef(\kick_v7, {
    arg freq = 70, pitchAmt = 6.0, pitchTime = 0.06,
        decay = 0.28, drive = 1.6, click = 0.18,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.33);
    clickSig = HPF.ar(WhiteNoise.ar, 3000) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.35) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
