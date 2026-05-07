// =====================================================================
//  fx/bus/fx_phaser.scd  --  SynthDef \fxPhaser
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxPhaser, {
    arg in, out = 0, rate = 0.3, depth = 0.7, feedback = 0.4,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(200, 200 + (3000 * depth));
    var sig = AllpassN.ar(dry, 0.01, lfo.reciprocal, 0.05);
    sig = AllpassN.ar(sig, 0.01, (lfo * 1.3).reciprocal, 0.05);
    sig = AllpassN.ar(sig, 0.01, (lfo * 1.7).reciprocal, 0.05);
    sig = AllpassN.ar(sig + (LocalIn.ar(2) * feedback), 0.01, (lfo * 2.1).reciprocal, 0.05);
    LocalOut.ar(sig);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;
)
