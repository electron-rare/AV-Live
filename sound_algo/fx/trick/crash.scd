// =====================================================================
//  fx/trick/crash.scd  --  SynthDef \crash
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\crash, {
        arg hpf = 4000, decay = 1.5, amp = 0.3, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar + (PinkNoise.ar * 0.5), hpf);
        sig = BPF.ar(sig, 7000, 0.4) + (sig * 0.3);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
