// =====================================================================
//  fx/insert/fx_formant.scd  --  SynthDef \fxFormant
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxFormant, {
    arg in, out = 0, vowel = 0, q = 0.15, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var f1 = Select.kr(vowel, [800, 400, 350, 450, 325]);
    var f2 = Select.kr(vowel, [1150, 1700, 1900, 800, 700]);
    var f3 = Select.kr(vowel, [2900, 2600, 2500, 2830, 2530]);
    var wet = BPF.ar(dry, f1, q)
            + BPF.ar(dry, f2, q) * 0.7
            + BPF.ar(dry, f3, q) * 0.4;
    wet = wet * 1.5;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
