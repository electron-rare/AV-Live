// synth/drums/kick_v3.scd  --  SynthDef \kick_v3  // variation kick basique
(
SynthDef(\kick_v3, {
    arg freq = 50, pitchAmt = 3.5, pitchTime = 0.045,
        decay = 0.35, drive = 1.5, click = 0.25,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.22;
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -4));
    body = LFTri.ar(pEnv);
    sub  = SinOsc.ar(freq * 0.5);
    clickSig = HPF.ar(WhiteNoise.ar, 4000) *
               EnvGen.kr(Env.perc(0.0005, 0.004));
    sig = body + (sub * 0.4) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
