// =====================================================================
//  fx/bus/fx_chorus.scd  --  SynthDef \fxChorus
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxChorus, {
    arg in, out = 0, rate = 0.4, depth = 0.005,
        mix = 0.5, amp = 1.0;
    var sig = In.ar(in, 2);
    var l = DelayC.ar(sig[0], 0.05, SinOsc.kr(rate, 0).range(0.005, 0.005 + depth));
    var r = DelayC.ar(sig[1], 0.05, SinOsc.kr(rate, pi).range(0.005, 0.005 + depth));
    var wet = [l, r];
    Out.ar(out, ((sig * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
