// =====================================================================
//  fx/insert/vcf_moog.scd  --  SynthDef \vcfMoog
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfMoog, {
    arg busIn = 0, freq = 1500, gain = 2.0, mix = 1.0, drive = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = MoogFF.ar(sig * drive, freq.clip(40, 18000), gain.clip(0, 4));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
