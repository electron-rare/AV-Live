// synth/master/vinyl_v8.scd  --  SynthDef \vinyl_v8  // variation vinyl tone shape
(
SynthDef(\vinyl_v8, {
    arg lowCut = 80, highShelfFreq = 4000,
        highShelfGain = 0.5, makeup = 1.05;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
