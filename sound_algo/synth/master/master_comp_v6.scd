// synth/master/master_comp_v6.scd  --  SynthDef \master_comp_v6  // variation master compressor
(
SynthDef(\master_comp_v6, {
    arg threshold = 0.2, ratio = 0.3, attack = 0.02, release = 0.1,
        makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
