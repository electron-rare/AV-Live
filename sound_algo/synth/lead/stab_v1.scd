// synth/lead/stab_v1.scd  --  SynthDef \stab_v1  // variation stab stab court
(
SynthDef(\stab_v1, {
    arg freq = 220, gate = 1,
        cutoff = 400, cutoffEnv = 2000, rq = 0.3,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 0.1,
        drive = 1.5, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, fEnv, fc, duck;
    sig = Mix([Saw.ar(freq), Saw.ar(freq * 1.005)]);
    fEnv = EnvGen.kr(Env.perc(0.001, 0.05), gate);
    fc = (cutoff + (fEnv * cutoffEnv)).clip(80, 14000);
    sig = RLPF.ar(sig, fc, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
