// synth/drums/kick808_v4.scd  --  SynthDef \kick808_v4  // variation kick 808 sub deep
(
SynthDef(\kick808_v4, {
    arg freq = 50, pitchAmt = 3.0, pitchTime = 0.07,
        decay = 0.8, drive = 1.6, click = 0.2,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.22;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 2500) *
               EnvGen.kr(Env.perc(0.0005, 0.003));
    sig = body + (sub * 0.7) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
