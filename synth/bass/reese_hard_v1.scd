// synth/bass/reese_hard_v1.scd  --  SynthDef \reese_hard_v1  // variation reese hard distordu
(
SynthDef(\reese_hard_v1, {
    arg freq = 50, gate = 1, detune = 0.02,
        cutoff = 350, rq = 0.3,
        attack = 0.003, decay = 0.1, sustain = 0.8, release = 0.15,
        drive = 3.0, amp = 0.35, pan = 0,
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
