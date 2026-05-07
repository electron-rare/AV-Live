// =====================================================================
//  fx/insert/fx_spring_rev.scd  --  SynthDef \fxSpringRev
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxSpringRev, {
    arg in, out = 0, decay = 1.5, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = dry;
    // chaine d'allpass typique d'un spring tank
    [0.013, 0.029, 0.041, 0.067, 0.089].do { |t|
        wet = AllpassN.ar(wet, 0.1, t, decay);
    };
    wet = HPF.ar(wet, 200);    // pas de basses dans un spring
    wet = LPF.ar(wet, 4500);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
