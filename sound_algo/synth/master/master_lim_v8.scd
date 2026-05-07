// synth/master/master_lim_v8.scd  --  SynthDef \master_lim_v8  // variation master limiter
(
SynthDef(\master_lim_v8, {
    arg threshold = 0.9, lookAhead = 0.01, makeup = 1.4;
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
