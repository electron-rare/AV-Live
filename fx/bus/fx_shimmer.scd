// =====================================================================
//  fx/bus/fx_shimmer.scd  --  SynthDef \fxShimmer
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxShimmer, {
    arg in, out = 0, mix = 0.5, room = 0.92, shimmer = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var pitched = PitchShift.ar(dry, 0.2, 2, 0.01, 0.005) * shimmer;
    var sig = FreeVerb2.ar(dry[0] + pitched[0], dry[1] + pitched[1],
        1.0, room, 0.3);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;
)
