// synth/pad/strings_v7.scd  --  SynthDef \strings_v7  // variation strings string saws
(
SynthDef(\strings_v7, {
    arg freq = 330, gate = 1, detune = 0.01,
        cutoff = 1800, rq = 0.6,
        attack = 0.4, decay = 0.2, sustain = 0.6, release = 2.0,
        drive = 1.0, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    sig = Mix.fill(3, { |i|
        Saw.ar(freq * (1 + ((i - 1) * detune)))
    }) * 0.22;
    sig = RLPF.ar(sig, cutoff, rq);
    sig = sig + DelayC.ar(sig, 0.04,
        SinOsc.kr(0.4, 0).range(0.01, 0.03));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
