// synth/bass/reese_v11.scd  --  SynthDef \reese_v11  // variation reese 3 saws detunees
(
SynthDef(\reese_v11, {
    arg freq = 80, gate = 1, detune = 0.025,
        cutoff = 1500, rq = 0.7,
        attack = 0.01, decay = 0.3, sustain = 0.7, release = 0.5,
        drive = 2.0, amp = 0.3, pan = 0,
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
