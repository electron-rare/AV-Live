// synth/world/gong_v10.scd  --  SynthDef \gong_v10  // variation gong gong modal
(
SynthDef(\gong_v10, {
    arg freq = 80, gate = 1,
        attack = 0.005, decay = 0.5, sustain = 0.3, release = 2.0,
        drive = 1.0, amp = 0.25, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, parts, f;
    f = freq.clip(40, 2000);
    parts = Mix.fill(8, { |i|
        var r = [1.0, 1.34, 1.81, 2.13, 2.65, 3.17, 3.91, 4.43][i];
        SinOsc.ar(f * r) * (1 / (i + 1)) *
        EnvGen.kr(Env.perc(0.005, 3.0 * (1 + (i * 0.4))))
    });
    sig = parts * 0.22;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
