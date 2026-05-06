// synth/drums/kick808_v6.scd  --  SynthDef \kick808_v6  // variation kick 808 sub deep
(
SynthDef(\kick808_v6, {
    arg freq = 60, pitchAmt = 2.0, pitchTime = 0.04,
        decay = 0.7, drive = 1.2, click = 0.1,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.22;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 3500) *
               EnvGen.kr(Env.perc(0.0005, 0.003));
    sig = body + (sub * 0.6) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
