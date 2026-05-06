// =====================================================================
//  fx/insert/fx_tremolo.scd  --  SynthDef \fxTremolo
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxTremolo, {
    arg in, out = 0, rate = 5, depth = 0.7, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(1 - depth, 1);
    var wet = dry * lfo;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
