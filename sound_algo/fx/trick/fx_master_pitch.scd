// =====================================================================
//  fx/trick/fx_master_pitch.scd  --  SynthDef \fxMasterPitch
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxMasterPitch, {
    arg dur = 2, pitch = 1.0, releaseTime = 0.05;
    var sig = In.ar(0, 2);
    var wet = PitchShift.ar(sig, 0.2, pitch, 0.01, 0.005);
    var env = EnvGen.kr(Env.linen(0.01, dur, releaseTime), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;
)
