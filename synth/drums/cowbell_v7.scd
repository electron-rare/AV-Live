// synth/drums/cowbell_v7.scd  --  SynthDef \cowbell_v7  // variation cowbell partials
(
SynthDef(\cowbell_v7, {
    arg freq = 660, decay = 0.15, ratio = 0.5,
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
