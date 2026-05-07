// synth/drums/kick_v12.scd  --  SynthDef \kick_v12  // variation kick FM 2-op
(
SynthDef(\kick_v12, {
    arg freq = 65, ratio = 2.5, modIndex = 600,
        decay = 0.25, drive = 1.2, click = 0.1,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, mod, car, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 3.5, freq], [0.06], -3));
    mod = SinOsc.ar(pEnv * ratio) * pEnv * modIndex;
    car = SinOsc.ar(pEnv + mod);
    clickSig = HPF.ar(WhiteNoise.ar, 2500) *
               EnvGen.kr(Env.perc(0.0005, 0.005));
    sig = car + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
