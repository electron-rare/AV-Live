// =========================================================
//  FUTURE GARAGE (130-140) -- 2-step syncope, kick irregulier -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=48;~kickPitchAmt=2.5;~kickDecay=0.5;~kickDrive=1.2;~kickClick=0.10;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;  // skippy
~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.3;  // sparse
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
~percSteps  = (0!16);
~reload.value; "=== FUTURE GARAGE 2-STEP ===".postln;
)
