// =====================================================================
//  synth/drums/cowbell.scd  --  SynthDef \cowbell
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\cowbell, {
        arg freq = 800, decay = 0.2, amp = 0.3, pan = 0;
        var sig, env;
        sig = (Pulse.ar(freq, 0.5) * 0.5) + (Pulse.ar(freq * 1.501, 0.5) * 0.5);
        sig = BPF.ar(sig, freq * 1.3, 0.3) * 2;
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;
)
