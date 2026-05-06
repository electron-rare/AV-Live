// synth/lead/fm_bell_v11.scd  --  SynthDef \fm_bell_v11  // variation fm_bell bell-like modal
(
SynthDef(\fm_bell_v11, {
    arg freq = 440, gate = 1,
        attack = 0.005, decay = 0.3, sustain = 0.0, release = 1.0,
        drive = 1.0, amp = 0.2, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, parts, duck, f;
    f = freq.clip(40, 6000);
    parts = Mix.fill(3, { |i|
        var ratio = [1, 2.01, 2.97, 4.03, 5.21, 6.43, 7.58][i];
        var amp = 1 / (i + 1);
        SinOsc.ar(f * ratio) * amp *
        EnvGen.kr(Env.perc(0.005, 0.5 * (1 / (i * 0.3 + 1))))
    });
    sig = parts * 0.25;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
