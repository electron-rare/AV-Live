// synth/lead/rhodes_v15.scd  --  SynthDef \rhodes_v15  // variation rhodes bell-like modal
(
SynthDef(\rhodes_v15, {
    arg freq = 330, gate = 1,
        attack = 0.005, decay = 0.5, sustain = 0.0, release = 1.5,
        drive = 1.0, amp = 0.2, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, parts, duck, f;
    f = freq.clip(40, 6000);
    parts = Mix.fill(7, { |i|
        var ratio = [1, 2.01, 2.97, 4.03, 5.21, 6.43, 7.58][i];
        var amp = 1 / (i + 1);
        SinOsc.ar(f * ratio) * amp *
        EnvGen.kr(Env.perc(0.005, 2.5 * (1 / (i * 0.3 + 1))))
    });
    sig = parts * 0.25;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
