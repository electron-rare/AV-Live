// synth/master/master_sat_v13.scd  --  SynthDef \master_sat_v13  // variation master saturation
(
SynthDef(\master_sat_v13, {
    arg drive = 2.0, mix = 0.3, makeup = 0.8;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
