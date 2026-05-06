// synth/drums/clap_v12.scd  --  SynthDef \clap_v12  // variation clap multi-transient
(
SynthDef(\clap_v12, {
    arg decay = 0.15, hpf = 1000, drive = 2.0,
        amp = 0.3, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = HPF.ar(WhiteNoise.ar, hpf);
    env = EnvGen.kr(
        Env([0, 1, 0, 1, 0, 1, 0, 1, 0],
            [0.001, 0.012, 0.001, 0.012, 0.001, 0.012, 0.002, decay],
            [0, -2, 0, -2, 0, -2, 0, -6]),
        doneAction: 2);
    sig = (n * env * drive).softclip;
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
