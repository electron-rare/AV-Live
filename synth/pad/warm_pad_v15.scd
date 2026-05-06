// synth/pad/warm_pad_v15.scd  --  SynthDef \warm_pad_v15  // variation warm_pad string saws
(
SynthDef(\warm_pad_v15, {
    arg freq = 220, gate = 1, detune = 0.022,
        cutoff = 3600, rq = 0.6,
        attack = 1.0, decay = 0.4, sustain = 0.8, release = 2.0,
        drive = 1.2, amp = 0.15, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    sig = Mix.fill(7, { |i|
        Saw.ar(freq * (1 + ((i - 3) * detune)))
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
