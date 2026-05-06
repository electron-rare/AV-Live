// synth/master/master_lim_v14.scd  --  SynthDef \master_lim_v14  // variation master limiter
(
SynthDef(\master_lim_v14, {
    arg threshold = 0.95, lookAhead = 0.01, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
