// =====================================================================
//  fx/bus/fx_dist.scd  --  SynthDef \fxDist
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxDist, {
    arg in, out = 0, drive = 3.0, tone = 0.5,
        mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var sig = (dry * drive).tanh;
    sig = (sig * 1.5).tanh;
    sig = MoogFF.ar(sig, tone.linexp(0, 1, 500, 12000), 1.5);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;
)
