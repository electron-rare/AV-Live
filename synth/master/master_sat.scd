// =====================================================================
//  synth/master/master_sat.scd  --  SynthDef \masterSat
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\masterSat, {
    arg amount = 1.5, mode = 0, mix = 1.0;
    var sig = In.ar(0, 2);
    var wet = Select.ar(mode.clip(0, 2), [
        (sig * amount).tanh / amount.sqrt,
        (sig * amount).softclip,
        (sig * amount).fold(-0.95, 0.95)
    ]);
    ReplaceOut.ar(0, (sig * (1 - mix)) + (wet * mix));
}).add;
)
