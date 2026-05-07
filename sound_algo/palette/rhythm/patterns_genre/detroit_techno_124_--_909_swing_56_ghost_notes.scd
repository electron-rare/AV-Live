// =========================================================
//  DETROIT TECHNO (124) -- 909 swing 56% + ghost notes -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0]; ~kickAmp = 0.5;  // ghost
~kickFreq=52;~kickPitchAmt=2.8;~kickDecay=0.32;~kickDrive=1.3;~kickClick=0.16;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.13;  // shuffle
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.32;  // ghost claps
~percSteps  = (0!16);
~reload.value; "=== DETROIT TECHNO 124 BPM swing ===".postln;
)
