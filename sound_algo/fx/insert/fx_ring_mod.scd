// =====================================================================
//  fx/insert/fx_ring_mod.scd  --  SynthDef \fxRingMod
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxRingMod, {
    arg in, out = 0, freq = 200, modAmt = 1.0, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = dry * SinOsc.ar(freq) * modAmt;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
