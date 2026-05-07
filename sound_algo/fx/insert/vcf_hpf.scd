// =====================================================================
//  fx/insert/vcf_hpf.scd  --  SynthDef \vcfHpf
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfHpf, {
    arg busIn = 0, freq = 200, q = 0.5, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = RHPF.ar(sig, freq.clip(20, 18000), q.clip(0.05, 2));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
