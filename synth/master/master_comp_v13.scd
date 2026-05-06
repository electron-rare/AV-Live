// synth/master/master_comp_v13.scd  --  SynthDef \master_comp_v13  // variation master compressor
(
SynthDef(\master_comp_v13, {
    arg threshold = 0.4, ratio = 0.5, attack = 0.005, release = 0.05,
        makeup = 1.4;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
