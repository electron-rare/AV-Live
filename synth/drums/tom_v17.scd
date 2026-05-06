// synth/drums/tom_v17.scd  --  SynthDef \tom_v17  // variation tom pitched
(
SynthDef(\tom_v17, {
    arg freq = 200, decay = 0.2, drive = 1.0,
        amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, pEnv, ampEnv;
    pEnv = EnvGen.kr(Env([freq * 2.5, freq], [0.03], -3));
    sig = SinOsc.ar(pEnv.clip(30, 1500));
    ampEnv = EnvGen.kr(Env.perc(0.005, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
