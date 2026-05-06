// =====================================================================
//  fx/insert/vcf_ladder.scd  --  SynthDef \vcfLadder
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfLadder, {
    arg busIn = 0, freq = 1500, q = 1.0, mix = 1.0, drive = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = LPF.ar(LPF.ar(sig * drive, freq), freq);
    wet = wet + (RHPF.ar(wet, freq, q.reciprocal.clip(0.1, 2)) * (q * 0.3));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
