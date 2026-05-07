// synth/master/master_sat_v8.scd  --  SynthDef \master_sat_v8  // variation master EQ
(
SynthDef(\master_sat_v8, {
    arg lowCut = 40, highShelfFreq = 10000,
        highShelfGain = 2.0, makeup = 1.1;
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
