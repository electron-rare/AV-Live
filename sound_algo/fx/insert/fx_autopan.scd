// =====================================================================
//  fx/insert/fx_autopan.scd  --  SynthDef \fxAutopan
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxAutopan, {
    arg in, out = 0, rate = 0.3, depth = 1.0, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var p = SinOsc.kr(rate) * depth;
    var wet = Balance2.ar(dry[0], dry[1], p);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
