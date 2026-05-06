// synth/master/master_lim_v7.scd  --  SynthDef \master_lim_v7  // variation master limiter
(
SynthDef(\master_lim_v7, {
    arg threshold = 0.8, lookAhead = 0.005, makeup = 1.2;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
