// synth/master/master_sat_v10.scd  --  SynthDef \master_sat_v10  // variation master saturation
(
SynthDef(\master_sat_v10, {
    arg drive = 4.0, mix = 0.5, makeup = 0.8;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).softclip / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
