// synth/master/master_sat_v4.scd  --  SynthDef \master_sat_v4  // variation master saturation
(
SynthDef(\master_sat_v4, {
    arg drive = 3.0, mix = 0.9, makeup = 0.8;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).softclip / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
