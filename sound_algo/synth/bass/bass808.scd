// =====================================================================
//  synth/bass/bass808.scd  --  SynthDef \bass808
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\bass808, {
        arg freq = 55, gate = 1, glide = 0.05,
            attack = 0.003, decay = 0.4, sustain = 0.8, release = 0.6,
            drive = 1.4, amp = 0.45, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck, f;
        f = Lag.kr(freq, glide);
        sig = SinOsc.ar(f) + (SinOsc.ar(f * 0.5) * 0.5);
        sig = (sig * drive).tanh;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = LeakDC.ar(sig) * env * amp * duck;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;
)
