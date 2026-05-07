// synth/master/master_lim_v5.scd  --  SynthDef \master_lim_v5  // variation master limiter
(
SynthDef(\master_lim_v5, {
    arg threshold = 0.99, lookAhead = 0.01, makeup = 1.0;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
