// =====================================================================
//  synth/drums/hat.scd  --  SynthDef \hat
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\hat, {
        arg hpf = 9000, decay = 0.04, amp = 0.18, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar, hpf);
        sig = BPF.ar(sig, 10000, 0.4);
        env = EnvGen.kr(Env.perc(0.001, decay), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
