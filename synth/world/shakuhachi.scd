// =====================================================================
//  synth/world/shakuhachi.scd  --  SynthDef \shakuhachi
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\shakuhachi, {
    arg freq = 440, gate = 1,
        breathAmt = 0.25, vibratoRate = 4.5, vibratoDepth = 0.018,
        cutoff = 3000, rq = 0.5,
        attack = 0.12, decay = 0.1, sustain = 0.7, release = 0.4,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, vibFreq, breath, body, bendEnv;
    bendEnv = EnvGen.kr(Env([0.97, 1.0], [0.08], -2));   // attack bend (style shakuhachi)
    vibFreq = freq * bendEnv * (1 + (SinOsc.kr(vibratoRate,
        EnvGen.kr(Env([0, 0, 1], [0.3, 0.4])) * pi) * vibratoDepth));
    body = SinOsc.ar(vibFreq) +
           (SinOsc.ar(vibFreq * 2) * 0.18) +
           (SinOsc.ar(vibFreq * 3) * 0.06);
    breath = HPF.ar(WhiteNoise.ar, 2000) * breathAmt *
             EnvGen.kr(Env([0.4, 1, 0.5], [0.05, 0.5]));
    sig = body + breath;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
