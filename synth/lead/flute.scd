// =====================================================================
//  synth/lead/flute.scd  --  SynthDef \flute
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\flute, {
    arg freq = 440, gate = 1,
        breathAmt = 0.15, vibratoRate = 5, vibratoDepth = 0.012,
        cutoff = 3500, rq = 0.6,
        attack = 0.08, decay = 0.1, sustain = 0.7, release = 0.3,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq, breath, body;
    vibFreq = freq * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.15, 0.4])) * pi) * vibratoDepth));
    body = SinOsc.ar(vibFreq) +
           (SinOsc.ar(vibFreq * 2) * 0.15) +
           (SinOsc.ar(vibFreq * 3) * 0.05);
    breath = HPF.ar(WhiteNoise.ar, 2000) * breathAmt *
             EnvGen.kr(Env([0, 1, 0.6], [0.05, 0.5]));
    sig = body + breath;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
