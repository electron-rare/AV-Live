// =====================================================================
//  fx/bus/fx_reverb.scd  --  SynthDef \fxReverb
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxReverb, {
    arg in, out = 0, mix = 0.4, room = 0.85, damp = 0.4,
        freeze = 0, amp = 1.0;
    var sig = In.ar(in, 2);
    sig = FreeVerb2.ar(sig[0], sig[1],
        Select.kr(freeze, [mix, 1.0]),
        Select.kr(freeze, [room, 0.999]),
        Select.kr(freeze, [damp, 0.001]));
    Out.ar(out, sig * amp);
}).add;
)
