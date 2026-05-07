// =====================================================================
//  synth/master/master_lim.scd  --  SynthDef \masterLim
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\masterLim, {
        var sig = In.ar(0, 2);
        sig = LeakDC.ar(sig);
        sig = Limiter.ar(sig, 0.95, 0.005);
        ReplaceOut.ar(0, sig);
    }).add;
)
