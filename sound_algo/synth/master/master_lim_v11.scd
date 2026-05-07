// synth/master/master_lim_v11.scd  --  SynthDef \master_lim_v11  // variation master limiter
(
SynthDef(\master_lim_v11, {
    arg threshold = 0.7, lookAhead = 0.01, makeup = 1.2;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
