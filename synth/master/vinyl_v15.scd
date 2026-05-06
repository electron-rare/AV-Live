// synth/master/vinyl_v15.scd  --  SynthDef \vinyl_v15  // variation vinyl warmth saturation
(
SynthDef(\vinyl_v15, {
    arg drive = 3.0, mix = 0.8, makeup = 0.95;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
