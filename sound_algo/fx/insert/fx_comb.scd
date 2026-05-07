// =====================================================================
//  fx/insert/fx_comb.scd  --  SynthDef \fxComb
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxComb, {
    arg in, out = 0, freq = 220, decay = 1.0, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = CombC.ar(dry, 0.05, freq.reciprocal.clip(0.0001, 0.05), decay);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
