// synth/master/master_sat_v11.scd  --  SynthDef \master_sat_v11  // variation master EQ
(
SynthDef(\master_sat_v11, {
    arg lowCut = 20, highShelfFreq = 8000,
        highShelfGain = 1.5, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
