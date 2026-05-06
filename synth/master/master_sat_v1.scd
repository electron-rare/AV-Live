// synth/master/master_sat_v1.scd  --  SynthDef \master_sat_v1  // variation master saturation
(
SynthDef(\master_sat_v1, {
    arg drive = 1.2, mix = 0.3, makeup = 0.8;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
