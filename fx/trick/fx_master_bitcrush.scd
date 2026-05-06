// =====================================================================
//  fx/trick/fx_master_bitcrush.scd  --  SynthDef \fxMasterBitcrush
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxMasterBitcrush, {
    arg dur = 1, bits = 6, sr = 6000, mix = 0.7;
    var sig = In.ar(0, 2);
    // Bit + SR reduction native (sans Decimator de sc3-plugins)
    var step = 2.pow(bits - 1);
    var crushed = (sig * step).round / step;
    var wet = Latch.ar(crushed, Impulse.ar(sr));
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, ((sig * (1 - mix)) + (wet * mix)) * env
                     + (sig * (1 - env)));
}).add;
)
