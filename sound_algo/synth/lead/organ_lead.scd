// =====================================================================
//  synth/lead/organ_lead.scd  --  SynthDef \organLead
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\organLead, {
    arg freq = 440, gate = 1,
        cutoff = 4500, rq = 0.5,
        attack = 0.005, decay = 0.05, sustain = 0.85, release = 0.15,
        drive = 1.3, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, drawbars;
    // 6 drawbars : sub, fund, octave, 12th, 15th, 17th
    drawbars = [0.5, 1, 2, 3, 4, 5];
    sig = Mix.fill(drawbars.size, { |i|
        SinOsc.ar(freq * drawbars[i]) * (1 / (i + 1));
    }) * 0.6;
    sig = LPF.ar(sig, cutoff);
    sig = sig + (sig * SinOsc.kr(6.5, 0).range(0.7, 1));   // leslie tremolo leger
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
