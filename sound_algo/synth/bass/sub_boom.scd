// =====================================================================
//  synth/bass/sub_boom.scd  --  SynthDef \subBoom
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\subBoom, {
    arg freq = 50, gate = 1, glide = 0.04,
        attack = 0.005, decay = 0.4, sustain = 0.85, release = 0.6,
        drive = 1.4, amp = 0.4, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, duck, f;
    f = Lag.kr(freq, glide);
    // Sub fondamental + octave -1 + harmonique 2 leger
    sig = (SinOsc.ar(f) * 0.8) +
          (SinOsc.ar(f * 0.5) * 0.5) +
          (SinOsc.ar(f * 2) * 0.15);
    sig = (sig * drive).tanh;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
