// synth/master/master_lim_v19.scd  --  SynthDef \master_lim_v19  // variation master limiter
(
SynthDef(\master_lim_v19, {
    arg threshold = 0.95, lookAhead = 0.005, makeup = 1.2;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
