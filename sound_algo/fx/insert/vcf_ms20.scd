// =====================================================================
//  fx/insert/vcf_ms20.scd  --  SynthDef \vcfMs20
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfMs20, {
    arg busIn = 0, freq = 1500, q = 1.5, mix = 1.0, drive = 1.2;
    var sig = In.ar(busIn, 2);
    var wet = (sig * drive).tanh;
    wet = RLPF.ar(wet, freq.clip(40, 18000), q.reciprocal.clip(0.05, 1.5));
    wet = (wet * 1.3).tanh;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
