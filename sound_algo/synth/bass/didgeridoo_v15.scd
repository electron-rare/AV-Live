// synth/bass/didgeridoo_v15.scd  --  SynthDef \didgeridoo_v15  // variation didgeridoo wobble
(
SynthDef(\didgeridoo_v15, {
    arg freq = 65, gate = 1, lfoRate = 3, lfoDepth = 0.6,
        cutoff = 1000, rq = 0.6,
        attack = 0.05, decay = 0.8, sustain = 0.9, release = 1.2,
        drive = 2.5, amp = 0.3, pan = 0,
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
