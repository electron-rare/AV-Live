// synth/master/vinyl_v11.scd  --  SynthDef \vinyl_v11  // variation vinyl warmth saturation
(
SynthDef(\vinyl_v11, {
    arg drive = 2.0, mix = 0.6, makeup = 0.9;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
