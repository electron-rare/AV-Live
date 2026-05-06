// =====================================================================
//  fx/bus/fx_bitcrush.scd  --  SynthDef \fxBitcrush
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxBitcrush, {
    arg in, out = 0, bits = 8, sampleRate = 8000,
        mix = 0.6, amp = 1.0;
    var dry = In.ar(in, 2);
    // Bit reduction native (sans Decimator de sc3-plugins)
    var step = 2.pow(bits - 1);
    var crushed = (dry * step).round / step;
    var sig = Latch.ar(crushed, Impulse.ar(sampleRate));
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;
)
