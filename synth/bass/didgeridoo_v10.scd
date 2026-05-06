// synth/bass/didgeridoo_v10.scd  --  SynthDef \didgeridoo_v10  // variation didgeridoo wobble
(
SynthDef(\didgeridoo_v10, {
    arg freq = 70, gate = 1, lfoRate = 5, lfoDepth = 0.5,
        cutoff = 800, rq = 0.4,
        attack = 0.05, decay = 0.3, sustain = 0.7, release = 0.5,
        drive = 1.5, amp = 0.3, pan = 0,
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
