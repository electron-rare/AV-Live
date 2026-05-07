// synth/drums/rim_v5.scd  --  SynthDef \rim_v5  // variation rim shot metallique
(
SynthDef(\rim_v5, {
    arg freq = 2000, decay = 0.06, ratio = 0.3,
        amp = 0.25, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, m;
    m = Mix.fill(4, { |i|
        SinOsc.ar(freq * (1 + (i * ratio))) * (1 / (i + 1))
    });
    env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
    sig = LeakDC.ar(m * env) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
