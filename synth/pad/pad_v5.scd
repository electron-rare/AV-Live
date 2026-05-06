// synth/pad/pad_v5.scd  --  SynthDef \pad_v5  // variation pad string saws
(
SynthDef(\pad_v5, {
    arg freq = 220, gate = 1, detune = 0.022,
        cutoff = 3600, rq = 0.4,
        attack = 1.0, decay = 0.3, sustain = 0.7, release = 1.0,
        drive = 1.1, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    sig = Mix.fill(5, { |i|
        Saw.ar(freq * (1 + ((i - 2) * detune)))
    }) * 0.22;
    sig = RLPF.ar(sig, cutoff, rq);
    sig = sig + DelayC.ar(sig, 0.04,
        SinOsc.kr(0.2, 0).range(0.01, 0.03));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
