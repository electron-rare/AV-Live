// synth/drums/kick_v4.scd  --  SynthDef \kick_v4  // variation kick basique
(
SynthDef(\kick_v4, {
    arg freq = 55, pitchAmt = 4.0, pitchTime = 0.055,
        decay = 0.4, drive = 1.8, click = 0.3,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.2;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
    body = SinOsc.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.25);
    clickSig = HPF.ar(WhiteNoise.ar, 2500) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.5) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
