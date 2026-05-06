// synth/drums/tom_v14.scd  --  SynthDef \tom_v14  // variation tom pitched
(
SynthDef(\tom_v14, {
    arg freq = 140, decay = 0.3, drive = 1.3,
        amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, pEnv, ampEnv;
    pEnv = EnvGen.kr(Env([freq * 3.5, freq], [0.04], -3));
    sig = LFTri.ar(pEnv.clip(30, 1500));
    ampEnv = EnvGen.kr(Env.perc(0.005, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
