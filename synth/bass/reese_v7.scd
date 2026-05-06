// synth/bass/reese_v7.scd  --  SynthDef \reese_v7  // variation reese 3 saws detunees
(
SynthDef(\reese_v7, {
    arg freq = 80, gate = 1, detune = 0.005,
        cutoff = 600, rq = 0.7,
        attack = 0.01, decay = 0.2, sustain = 0.6, release = 0.3,
        drive = 1.5, amp = 0.3, pan = 0,
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
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
