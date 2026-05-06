// =====================================================================
//  fx/bus/fx_flanger.scd  --  SynthDef \fxFlanger
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxFlanger, {
    arg in, out = 0, rate = 0.2, depth = 0.003, feedback = 0.6,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(0.0005, 0.0005 + depth);
    var fb = LocalIn.ar(2) * feedback;
    var sig = DelayC.ar(dry + fb, 0.02, lfo);
    LocalOut.ar(sig);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;
)
