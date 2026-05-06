// synth/bass/hooverbass_v3.scd  --  SynthDef \hooverbass_v3  // variation hoover bass
(
SynthDef(\hooverbass_v3, {
    arg freq = 100, gate = 1, detune = 0.025,
        cutoff = 1600, rq = 0.7,
        attack = 0.005, decay = 0.4, sustain = 0.9, release = 0.3,
        drive = 2.5, amp = 0.28, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, voices, duck;
    voices = [
        Saw.ar(freq * (1 - detune)),
        Saw.ar(freq * (1 + detune)),
        Saw.ar(freq * (1 + (detune * 2.5)))
    ];
    sig = Mix(voices) * 0.33;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
