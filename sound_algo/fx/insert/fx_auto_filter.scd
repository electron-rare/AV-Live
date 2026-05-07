// =====================================================================
//  fx/insert/fx_auto_filter.scd  --  SynthDef \fxAutoFilter
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxAutoFilter, {
    arg in, out = 0, rate = 0.5, lo = 200, hi = 4000, q = 0.4,
        mix = 0.7, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(lo, hi);
    var wet = RLPF.ar(dry, lfo, q.clip(0.05, 1.5));
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
