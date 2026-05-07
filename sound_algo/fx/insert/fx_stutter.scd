// =====================================================================
//  fx/insert/fx_stutter.scd  --  SynthDef \fxStutter
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxStutter, {
    arg in, out = 0, rate = 8, dutyCycle = 0.5, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var gate = LFPulse.kr(rate, 0, dutyCycle);
    var wet = dry * gate;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
