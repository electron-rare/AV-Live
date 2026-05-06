// synth/master/master_lim_v9.scd  --  SynthDef \master_lim_v9  // variation master limiter
(
SynthDef(\master_lim_v9, {
    arg threshold = 0.95, lookAhead = 0.02, makeup = 1.0;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
