// =====================================================================
//  synth/pad/choir.scd  --  SynthDef \choir
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\choir, {
    arg freq = 220, gate = 1,
        formant1 = 800, formant2 = 1150, formant3 = 2900,
        attack = 0.4, decay = 0.3, sustain = 0.7, release = 1.5,
        drive = 1.0, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, src, vib;
    // Vibrato lent humain
    vib = freq * (1 + (SinOsc.kr(5, 0,
        EnvGen.kr(Env([0, 0, 0.015], [0.5, 0.5]))).abs));
    // Source : saw filtree + sub
    src = Saw.ar(vib) + (SinOsc.ar(vib * 0.5) * 0.4);
    // 3 formants vocaux (a, e, o)
    sig = (BPF.ar(src, formant1, 0.15) * 1.0) +
          (BPF.ar(src, formant2, 0.20) * 0.5) +
          (BPF.ar(src, formant3, 0.30) * 0.25);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
