// synth/master/master_lim_v18.scd  --  SynthDef \master_lim_v18  // variation master limiter
(
SynthDef(\master_lim_v18, {
    arg threshold = 0.9, lookAhead = 0.02, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
