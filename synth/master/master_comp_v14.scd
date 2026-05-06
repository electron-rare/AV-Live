// synth/master/master_comp_v14.scd  --  SynthDef \master_comp_v14  // variation master compressor
(
SynthDef(\master_comp_v14, {
    arg threshold = 0.5, ratio = 0.6, attack = 0.01, release = 0.1,
        makeup = 1.6;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
