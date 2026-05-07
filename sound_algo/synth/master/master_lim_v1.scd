// synth/master/master_lim_v1.scd  --  SynthDef \master_lim_v1  // variation master limiter
(
SynthDef(\master_lim_v1, {
    arg threshold = 0.7, lookAhead = 0.005, makeup = 1.0;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
