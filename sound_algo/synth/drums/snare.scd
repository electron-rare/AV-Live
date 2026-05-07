// =====================================================================
//  synth/drums/snare.scd  --  SynthDef \snare
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\snare, {
        arg freq = 200, decay = 0.13, noiseAmt = 0.6, drive = 1.5,
            amp = 0.5, pan = 0;
        var tone, noise, env, sig, pitchEnv;
        pitchEnv = EnvGen.kr(Env([freq * 2, freq], [0.02], -2));
        tone = SinOsc.ar(pitchEnv) * EnvGen.kr(Env.perc(0.001, 0.05));
        noise = HPF.ar(WhiteNoise.ar, 1500);
        noise = BPF.ar(noise, 3000, 0.5);
        noise = noise * EnvGen.kr(Env.perc(0.001, decay));
        sig = (tone * (1 - noiseAmt)) + (noise * noiseAmt);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
        sig = (sig * drive).tanh;
        sig = LeakDC.ar(sig) * amp * env;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
