// =====================================================================
//  fx/trick/fx_master_ring.scd  --  SynthDef \fxMasterRing
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxMasterRing, {
    arg dur = 1, freq = 200, mix = 0.7;
    var sig = In.ar(0, 2);
    var wet = sig * SinOsc.ar(freq);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, ((sig * (1 - mix)) + (wet * mix)) * env
                     + (sig * (1 - env)));
}).add;
)
