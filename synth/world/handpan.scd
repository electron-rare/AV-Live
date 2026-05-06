// =====================================================================
//  synth/world/handpan.scd  --  SynthDef \handpan
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\handpan, {
    arg freq = 220, gate = 1,
        cutoff = 5000, rq = 0.6,
        attack = 0.001, decay = 0.05, sustain = 0.0, release = 1.5,
        drive = 1.1, amp = 0.22, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, partials;
    // 4 partiels harmoniques (octaves + quintes)
    partials = [1, 2, 3, 4];
    sig = Mix.fill(partials.size, { |i|
        SinOsc.ar(freq * partials[i]) *
            (1 / ((i * 1.5) + 1)) *
            EnvGen.kr(Env.perc(0.001, release * (1 - (i * 0.15)), 1, -4));
    });
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
