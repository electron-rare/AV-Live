// synth/master/vinyl_v18.scd  --  SynthDef \vinyl_v18  // variation vinyl tone shape
(
SynthDef(\vinyl_v18, {
    arg lowCut = 100, highShelfFreq = 5000,
        highShelfGain = -1.0, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
