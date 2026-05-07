// synth/master/master_lim_v10.scd  --  SynthDef \master_lim_v10  // variation master limiter
(
SynthDef(\master_lim_v10, {
    arg threshold = 0.99, lookAhead = 0.005, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
