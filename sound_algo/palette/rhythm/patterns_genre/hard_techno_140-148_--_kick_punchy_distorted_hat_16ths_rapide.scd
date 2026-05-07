// =========================================================
//  HARD TECHNO (140-148) -- kick punchy distorted + hat 16ths rapide -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=4.5;~kickDecay=0.28;~kickDrive=3.0;~kickClick=0.32;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.14;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
~percSteps  = (0!16);
~reload.value; "=== HARD TECHNO 140-148 BPM ===".postln;
)
