// synth/master/master_comp_v10.scd  --  SynthDef \master_comp_v10  // variation master compressor
(
SynthDef(\master_comp_v10, {
    arg threshold = 0.6, ratio = 0.7, attack = 0.005, release = 0.1,
        makeup = 1.8;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
