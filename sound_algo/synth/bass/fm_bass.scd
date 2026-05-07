// =====================================================================
//  synth/bass/fm_bass.scd  --  SynthDef \fmBass
//  Extracted from extra.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fmBass, {
    arg freq = 55, gate = 1, modRatio = 2, modIndex = 5,
        cutoff = 1800, rq = 0.5,
        attack = 0.003, decay = 0.15, sustain = 0.6, release = 0.2,
        drive = 1.6, amp = 0.32, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, duck, mod, idxEnv;
    idxEnv = EnvGen.kr(Env([modIndex, 0], [0.2], -3));
    mod = SinOsc.ar(freq * modRatio) * freq * idxEnv * 0.001;
    sig = SinOsc.ar(freq + (mod * freq * 0.8)) +
          (Saw.ar(freq) * 0.3);
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = LeakDC.ar(sig);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
