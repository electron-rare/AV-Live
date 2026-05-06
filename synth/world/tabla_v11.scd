// synth/world/tabla_v11.scd  --  SynthDef \tabla_v11  // variation tabla drum pitched
(
SynthDef(\tabla_v11, {
    arg freq = 180, gate = 1,
        decayTime = 0.3, noiseAmt = 0.4,
        attack = 0.001, decay = 0.4, sustain = 0, release = 0.05,
        drive = 1.3, amp = 0.32, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, n, pEnv;
    pEnv = EnvGen.kr(Env([freq * 4.0, freq], [0.07], -3));
    body = SinOsc.ar(pEnv.clip(30, 2000));
    n = HPF.ar(WhiteNoise.ar, 800) *
        EnvGen.kr(Env.perc(0.0005, 0.04));
    sig = body + (n * noiseAmt);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh;
    sig = LeakDC.ar(sig * env);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * amp * duck, pan));
}).add;
)
