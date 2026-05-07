// synth/master/master_comp_v11.scd  --  SynthDef \master_comp_v11  // variation master compressor
(
SynthDef(\master_comp_v11, {
    arg threshold = 0.2, ratio = 0.3, attack = 0.01, release = 0.2,
        makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
