// synth/master/master_sat_v5.scd  --  SynthDef \master_sat_v5  // variation master EQ
(
SynthDef(\master_sat_v5, {
    arg lowCut = 60, highShelfFreq = 4000,
        highShelfGain = 0.5, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
