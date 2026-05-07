// synth/lead/fm_lead_v13.scd  --  SynthDef \fm_lead_v13  // variation fm_lead FM 2-op
(
SynthDef(\fm_lead_v13, {
    arg freq = 220, gate = 1, ratio = 2.5, modIndex = 700,
        attack = 0.005, decay = 0.1, sustain = 0.4, release = 0.2,
        drive = 1.0, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, mod, duck, f;
    f = freq.clip(20, 8000);
    mod = SinOsc.ar(f * ratio) * f * modIndex *
          EnvGen.kr(Env.perc(0.001, 0.2));
    sig = SinOsc.ar(f + mod);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
