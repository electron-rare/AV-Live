// =====================================================================
//  fx/trick/fx_master_gran.scd  --  SynthDef \fxMasterGran
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxMasterGran, {
    arg dur = 2, grainDur = 0.1, pitch = 1.0;
    var sig = In.ar(0, 2);
    var wet = PitchShift.ar(sig, grainDur, pitch, 0.05, 0.05);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;
)
