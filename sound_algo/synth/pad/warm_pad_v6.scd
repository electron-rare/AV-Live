// synth/pad/warm_pad_v6.scd  --  SynthDef \warm_pad_v6  // variation warm_pad string saws
(
SynthDef(\warm_pad_v6, {
    arg freq = 220, gate = 1, detune = 0.006,
        cutoff = 1200, rq = 0.5,
        attack = 0.2, decay = 0.4, sustain = 0.8, release = 1.5,
        drive = 1.2, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    sig = Mix.fill(7, { |i|
        Saw.ar(freq * (1 + ((i - 3) * detune)))
    }) * 0.22;
    sig = RLPF.ar(sig, cutoff, rq);
    sig = sig + DelayC.ar(sig, 0.04,
        SinOsc.kr(0.3, 0).range(0.01, 0.03));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
