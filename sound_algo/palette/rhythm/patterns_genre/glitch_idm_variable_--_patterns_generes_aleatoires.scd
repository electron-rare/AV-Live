// =========================================================
//  GLITCH IDM (variable) -- patterns generes aleatoires -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = ~genKickPattern.(0.4);
~snareSteps = ~genKickPattern.(0.3);
~hatSteps   = ~genKickPattern.(0.7);
~clapSteps  = ~genKickPattern.(0.2);
~percSteps  = ~genKickPattern.(0.4);
~kickFreq=55;~kickPitchAmt=3.5;~kickDecay=0.18;~kickDrive=2.0;~kickClick=0.3;
~kickAmp = 0.5; ~hatAmp = 0.12; ~snareAmp = 0.45; ~clapAmp = 0.3; ~percAmp = 0.3;
~reload.value; "=== GLITCH IDM random ===".postln;
)
