// =====================================================================
//  synth/master/vinyl.scd  --  SynthDef \vinyl
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\vinyl, {
        arg amp = 0.05, pan = 0;
        var sig, crackles;
        sig = PinkNoise.ar(0.3);
        crackles = Dust.ar(50, 0.4) + Dust.ar(20, 0.5);
        sig = sig + crackles;
        sig = HPF.ar(sig, 80);
        Out.ar(0, Pan2.ar(sig * amp, pan));
    }).add;
)
