// synth/drums/kick808_v5.scd  --  SynthDef \kick808_v5  // variation kick 808 sub deep
(
SynthDef(\kick808_v5, {
    arg freq = 55, pitchAmt = 1.5, pitchTime = 0.08,
        decay = 1.0, drive = 1.0, click = 0.05,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.22;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 3000) *
               EnvGen.kr(Env.perc(0.0005, 0.003));
    sig = body + (sub * 0.5) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
