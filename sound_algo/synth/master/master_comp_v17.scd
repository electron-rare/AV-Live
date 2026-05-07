// synth/master/master_comp_v17.scd  --  SynthDef \master_comp_v17  // variation master compressor
(
SynthDef(\master_comp_v17, {
    arg threshold = 0.3, ratio = 0.4, attack = 0.01, release = 0.05,
        makeup = 1.2;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
