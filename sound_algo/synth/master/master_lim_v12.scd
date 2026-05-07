// synth/master/master_lim_v12.scd  --  SynthDef \master_lim_v12  // variation master limiter
(
SynthDef(\master_lim_v12, {
    arg threshold = 0.8, lookAhead = 0.02, makeup = 1.4;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
