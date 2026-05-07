// =========================================================
//  IDM -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 130; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = ~genKickPattern.(0.35);
~snareSteps = ~genKickPattern.(0.25);
~hatSteps   = ~genKickPattern.(0.65);
~clapSteps  = ~genKickPattern.(0.18);
~percSteps  = ~genKickPattern.(0.40);
~kickFreq=55;~kickPitchAmt=3.2;~kickDecay=0.22;~kickDrive=1.8;~kickClick=0.28;
~kickAmp = 0.5; ~hatAmp = 0.12; ~snareAmp = 0.45; ~clapAmp = 0.28; ~percAmp = 0.30;
~reload.value; "=== IDM (random) ===".postln;
)
