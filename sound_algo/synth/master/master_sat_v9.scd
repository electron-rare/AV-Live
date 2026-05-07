// synth/master/master_sat_v9.scd  --  SynthDef \master_sat_v9  // variation master stereo widener
(
SynthDef(\master_sat_v9, {
    arg width = 1.5, delay = 0.001, makeup = 1.05;
    var sig, l, r, mid, side;
    sig = In.ar(0, 2);
    mid = (sig[0] + sig[1]) * 0.5;
    side = (sig[0] - sig[1]) * 0.5 * width;
    side = DelayC.ar(side, 0.01, delay);
    l = mid + side;
    r = mid - side;
    sig = [l, r] * makeup;
    ReplaceOut.ar(0, sig);
}).add;
)
