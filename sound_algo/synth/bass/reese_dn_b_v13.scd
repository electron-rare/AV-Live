// synth/bass/reese_dn_b_v13.scd  --  SynthDef \reese_dn_b_v13  // variation reese DnB neuro
(
SynthDef(\reese_dn_b_v13, {
    arg freq = 65, gate = 1, detune = 0.015,
        cutoff = 600, rq = 0.4,
        attack = 0.005, decay = 0.15, sustain = 0.7, release = 0.2,
        drive = 2.0, amp = 0.32, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, voices, duck;
    voices = [
        Saw.ar(freq * (1 - detune)),
        Saw.ar(freq * (1 + detune)),
        Saw.ar(freq * (1 + (detune * 2.0)))
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
