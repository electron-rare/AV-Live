// =====================================================================
//  fx/trick/fx_master_freq_shift.scd  --  SynthDef \fxMasterFreqShift
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxMasterFreqShift, {
    arg dur = 1, shift = 100;
    var sig = In.ar(0, 2);
    var wet = FreqShift.ar(sig, shift);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;
)
