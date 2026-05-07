// =====================================================================
//  synth/bass/didgeridoo.scd  --  SynthDef \didgeridoo
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\didgeridoo, {
    arg freq = 60, gate = 1,
        growlRate = 4, growlDepth = 0.15,
        attack = 0.5, decay = 0.3, sustain = 0.85, release = 1.0,
        drive = 1.5, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, growl, harmonics;
    growl = SinOsc.kr(growlRate * (1 + LFNoise2.kr(0.5).range(-0.15, 0.15)))
            .range(1 - growlDepth, 1 + growlDepth);
    harmonics = (Saw.ar(freq * growl) * 0.4) +
                (Pulse.ar(freq * 2 * growl, 0.3) * 0.2) +
                (Pulse.ar(freq * 3 * growl, 0.4) * 0.15) +
                (SinOsc.ar(freq * 0.5) * 0.5);
    sig = LPF.ar(harmonics, 1200);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig) * env * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}).add;
)
