// =====================================================================
//  fx/insert/vcf_formant.scd  --  SynthDef \vcfFormant
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vcfFormant, {
    arg busIn = 0, vowel = 0, q = 0.15, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var f1 = Select.kr(vowel, [800, 400, 350, 450, 325]);
    var f2 = Select.kr(vowel, [1150, 1700, 1900, 800, 700]);
    var f3 = Select.kr(vowel, [2900, 2600, 2500, 2830, 2530]);
    var wet = BPF.ar(sig, f1, q) * 1.0
            + BPF.ar(sig, f2, q) * 0.7
            + BPF.ar(sig, f3, q) * 0.4;
    wet = wet * 1.5;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;
)
