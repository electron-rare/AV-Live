// =====================================================================
//  fx/insert/fx_plate.scd  --  SynthDef \fxPlate
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxPlate, {
    arg in, out = 0, decay = 2.5, damp = 0.3, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = FreeVerb2.ar(dry[0], dry[1], 1.0,
        decay.linlin(0.5, 5.0, 0.7, 0.95), damp);
    wet = HPF.ar(wet, 80);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
