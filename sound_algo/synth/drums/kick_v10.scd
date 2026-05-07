// synth/drums/kick_v10.scd  --  SynthDef \kick_v10  // variation kick FM 2-op
(
SynthDef(\kick_v10, {
    arg freq = 50, ratio = 1.5, modIndex = 800,
        decay = 0.35, drive = 2.0, click = 0.15,
        amp = 0.5, pan = 0,
        scBus = 0, scShape = 0.18;
    var pEnv, mod, car, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 2.5, freq], [0.03], -3));
    mod = SinOsc.ar(pEnv * ratio) * pEnv * modIndex;
    car = SinOsc.ar(pEnv + mod);
    clickSig = HPF.ar(WhiteNoise.ar, 2500) *
               EnvGen.kr(Env.perc(0.0005, 0.005));
    sig = car + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
