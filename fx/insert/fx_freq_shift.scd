// =====================================================================
//  fx/insert/fx_freq_shift.scd  --  SynthDef \fxFreqShift
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxFreqShift, {
    arg in, out = 0, shift = 100, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = FreqShift.ar(dry, shift);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
