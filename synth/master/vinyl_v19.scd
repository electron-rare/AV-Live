// synth/master/vinyl_v19.scd  --  SynthDef \vinyl_v19  // variation vinyl warmth saturation
(
SynthDef(\vinyl_v19, {
    arg drive = 1.5, mix = 0.4, makeup = 0.85;
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).tanh / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
