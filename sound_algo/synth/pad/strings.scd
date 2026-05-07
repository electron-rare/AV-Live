// =====================================================================
//  synth/pad/strings.scd  --  SynthDef \strings
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\strings, {
    arg freq = 440, gate = 1, detune = 0.008,
        cutoff = 3500, rq = 0.6,
        attack = 0.3, decay = 0.2, sustain = 0.85, release = 1.2,
        drive = 1.1, amp = 0.16, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices;
    voices = Mix.fill(5, { |i|
        var f = freq * (1 + (LFNoise2.kr(0.3 + (i * 0.1)) * detune));
        Saw.ar(f) + (Pulse.ar(f * 1.005, 0.4) * 0.3);
    }) * 0.15;
    voices = RLPF.ar(voices, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (voices * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
