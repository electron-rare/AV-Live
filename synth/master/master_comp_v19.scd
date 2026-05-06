// synth/master/master_comp_v19.scd  --  SynthDef \master_comp_v19  // variation master compressor
(
SynthDef(\master_comp_v19, {
    arg threshold = 0.5, ratio = 0.6, attack = 0.005, release = 0.2,
        makeup = 1.6;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
