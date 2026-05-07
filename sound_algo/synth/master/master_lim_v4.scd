// synth/master/master_lim_v4.scd  --  SynthDef \master_lim_v4  // variation master limiter
(
SynthDef(\master_lim_v4, {
    arg threshold = 0.95, lookAhead = 0.005, makeup = 1.4;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
