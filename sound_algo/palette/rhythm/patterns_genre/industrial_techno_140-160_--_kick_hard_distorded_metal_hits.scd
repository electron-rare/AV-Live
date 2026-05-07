// =========================================================
//  INDUSTRIAL TECHNO (140-160) -- kick hard distorded + metal hits -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=5.0;~kickDecay=0.28;~kickDrive=3.5;~kickClick=0.4;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;  // breakbeat
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.4;
~reload.value; "=== INDUSTRIAL TECHNO ===".postln;
)
