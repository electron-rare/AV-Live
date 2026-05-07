// synth/master/master_lim_v17.scd  --  SynthDef \master_lim_v17  // variation master limiter
(
SynthDef(\master_lim_v17, {
    arg threshold = 0.8, lookAhead = 0.01, makeup = 1.0;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
