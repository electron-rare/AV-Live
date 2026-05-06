// =====================================================================
//  synth/pad/vocal_pad.scd  --  SynthDef \vocalPad
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vocalPad, {
    arg freq = 220, gate = 1,
        // Formants pour voyelle "ah" : 700/1220/2600
        f1 = 700, f2 = 1220, f3 = 2600,
        attack = 0.4, decay = 0.3, sustain = 0.7, release = 1.5,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, src, vib;
    vib = freq * (1 + (SinOsc.kr(4.5).range(-1, 1) *
        EnvGen.kr(Env([0, 0, 0.012], [0.3, 0.5]))));
    src = (Saw.ar(vib) * 0.5) + (SinOsc.ar(vib * 0.5) * 0.4);
    sig = (BPF.ar(src, f1, 0.12) * 1.0) +
          (BPF.ar(src, f2, 0.18) * 0.6) +
          (BPF.ar(src, f3, 0.30) * 0.3);
    // Faux chorus stereo
    sig = [DelayC.ar(sig, 0.04, SinOsc.kr(0.5, 0).range(0.008, 0.025)),
           DelayC.ar(sig, 0.04, SinOsc.kr(0.55, pi).range(0.008, 0.025))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}).add;
)
