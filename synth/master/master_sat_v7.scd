// synth/master/master_sat_v7.scd  --  SynthDef \master_sat_v7  // variation master saturation
(
SynthDef(\master_sat_v7, {
    arg drive = 1.5, mix = 0.7, makeup = 0.8;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
