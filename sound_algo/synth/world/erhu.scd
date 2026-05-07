// =====================================================================
//  synth/world/erhu.scd  --  SynthDef \erhu
//  Extracted from asia.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\erhu, {
    arg freq = 440, gate = 1,
        cutoff = 2500, rq = 0.4,
        vibratoRate = 5.5, vibratoDepth = 0.015,
        attack = 0.05, decay = 0.1, sustain = 0.6, release = 0.3,
        drive = 1.3, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq;
    // Vibrato sinusoidal (apres petit delay pour entrer doucement)
    vibFreq = freq * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.1, 0.3])) * pi) * vibratoDepth));
    sig = (Saw.ar(vibFreq) * 0.6) + (Pulse.ar(vibFreq * 1.005, 0.4) * 0.4);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
