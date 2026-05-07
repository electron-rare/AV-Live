// synth/drums/kick_v6.scd  --  SynthDef \kick_v6  // variation kick basique
(
SynthDef(\kick_v6, {
    arg freq = 65, pitchAmt = 2.0, pitchTime = 0.04,
        decay = 0.6, drive = 1.2, click = 0.4,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.25;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -5));
    body = LFTri.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 2000) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.3) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
