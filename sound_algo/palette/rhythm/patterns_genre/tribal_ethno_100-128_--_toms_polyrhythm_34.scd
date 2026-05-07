// =========================================================
//  TRIBAL ETHNO (100-128) -- toms polyrhythm 3:4 -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.45;
~kickFreq=48;~kickPitchAmt=2.2;~kickDecay=0.4;~kickDrive=1.1;~kickClick=0.08;
~hatSteps   = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~hatAmp = 0.08;  // organique
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 90;
~percSteps  = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
~reload.value; "=== TRIBAL ETHNO 100 BPM ===".postln;
)
