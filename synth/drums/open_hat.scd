// =====================================================================
//  synth/drums/open_hat.scd  --  SynthDef \openHat
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\openHat, {
        arg hpf = 7000, decay = 0.4, amp = 0.18, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar, hpf);
        sig = BPF.ar(sig, 9000, 0.6);
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
