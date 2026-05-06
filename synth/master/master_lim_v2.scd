// synth/master/master_lim_v2.scd  --  SynthDef \master_lim_v2  // variation master limiter
(
SynthDef(\master_lim_v2, {
    arg threshold = 0.8, lookAhead = 0.01, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
