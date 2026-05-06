// synth/bass/reese_dn_b_v12.scd  --  SynthDef \reese_dn_b_v12  // variation reese DnB neuro
(
SynthDef(\reese_dn_b_v12, {
    arg freq = 60, gate = 1, detune = 0.03,
        cutoff = 500, rq = 0.6,
        attack = 0.005, decay = 0.25, sustain = 0.9, release = 0.3,
        drive = 3.5, amp = 0.32, pan = 0,
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
