// =====================================================================
//  fx/insert/vcf_bpf.scd  --  SynthDef \vcfBpf
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfBpf, {
    arg busIn = 0, freq = 1000, q = 0.3, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = BPF.ar(sig, freq.clip(40, 18000), q.clip(0.05, 2)) * 1.5;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
