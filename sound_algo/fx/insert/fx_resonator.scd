// =====================================================================
//  fx/insert/fx_resonator.scd  --  SynthDef \fxResonator
//  Extracted from live.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxResonator, {
    arg in, out = 0, freq = 220, decay = 2.0, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var ratios = [1, 1.5, 2.01, 2.5, 3.01];
    var amps = [1, 0.6, 0.4, 0.3, 0.2];
    var ringL = Klank.ar(`[ratios * freq, amps, ratios.collect { decay }],
                        dry[0] * 0.1);
    var ringR = Klank.ar(`[ratios * freq, amps, ratios.collect { decay }],
                        dry[1] * 0.1);
    var wet = [ringL, ringR];
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;
)
