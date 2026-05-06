// =========================================================
//  CHIPTUNE 8-BIT (150) -- kick triangle sharp, noise burst -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=80;~kickPitchAmt=4.5;~kickDecay=0.12;~kickDrive=1.4;~kickClick=0.5;  // chip kick
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.12;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.40;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== CHIPTUNE 8-BIT 150 BPM ===".postln;
)
