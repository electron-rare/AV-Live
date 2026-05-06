// =====================================================================
//  fx/insert/vcf_comb.scd  --  SynthDef \vcfComb
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfComb, {
    arg busIn = 0, freq = 220, decay = 1.0, mix = 0.6;
    var sig = In.ar(busIn, 2);
    var wet = CombC.ar(sig, 0.05, freq.reciprocal.clip(0.0001, 0.05), decay);
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
