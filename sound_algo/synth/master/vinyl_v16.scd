// synth/master/vinyl_v16.scd  --  SynthDef \vinyl_v16  // variation vinyl tone shape
(
SynthDef(\vinyl_v16, {
    arg lowCut = 60, highShelfFreq = 3000,
        highShelfGain = 0.5, makeup = 1.0;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
