// synth/lead/stab_v10.scd  --  SynthDef \stab_v10  // variation stab stab court
(
SynthDef(\stab_v10, {
    arg freq = 220, gate = 1,
        cutoff = 600, cutoffEnv = 3000, rq = 0.3,
        attack = 0.001, decay = 0.05, sustain = 0.1, release = 0.2,
        drive = 2.0, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, fEnv, fc, duck;
    sig = Mix([Pulse.ar(freq), Pulse.ar(freq * 1.005)]);
    fEnv = EnvGen.kr(Env.perc(0.001, 0.1), gate);
    fc = (cutoff + (fEnv * cutoffEnv)).clip(80, 14000);
    sig = RLPF.ar(sig, fc, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
