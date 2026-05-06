// synth/bass/didgeridoo_v5.scd  --  SynthDef \didgeridoo_v5  // variation didgeridoo wobble
(
SynthDef(\didgeridoo_v5, {
    arg freq = 75, gate = 1, lfoRate = 8, lfoDepth = 0.4,
        cutoff = 600, rq = 0.5,
        attack = 0.05, decay = 0.5, sustain = 0.8, release = 0.8,
        drive = 2.0, amp = 0.3, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, lfo, fc, duck;
    sig = Saw.ar(freq.clip(20, 4000));
    lfo = SinOsc.kr(lfoRate).range(1 - lfoDepth, 1);
    fc = (cutoff * lfo).clip(60, 12000);
    sig = RLPF.ar(sig, fc, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).softclip / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
