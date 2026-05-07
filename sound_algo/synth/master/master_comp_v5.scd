// synth/master/master_comp_v5.scd  --  SynthDef \master_comp_v5  // variation master compressor
(
SynthDef(\master_comp_v5, {
    arg threshold = 0.6, ratio = 0.7, attack = 0.01, release = 0.05,
        makeup = 1.8;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
