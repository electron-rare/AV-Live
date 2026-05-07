// =====================================================================
//  fx/insert/fx_gran.scd  --  SynthDef \fxGran
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxGran, {
    arg in, out = 0, grainDur = 0.1, density = 30, pitch = 1.0,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = PitchShift.ar(dry, grainDur, pitch, 0.05, 0.05);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
