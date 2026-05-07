// synth/lead/fm_lead_v8.scd  --  SynthDef \fm_lead_v8  // variation fm_lead FM 2-op
(
SynthDef(\fm_lead_v8, {
    arg freq = 220, gate = 1, ratio = 0.25, modIndex = 50,
        attack = 0.01, decay = 0.2, sustain = 0.5, release = 0.3,
        drive = 1.2, amp = 0.18, pan = 0,
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
