// =========================================================
//  DRONE DOOM (60) -- kick massif espace + crash long -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq=40;~kickPitchAmt=2.0;~kickDecay=0.8;~kickDrive=2.0;~kickClick=0.04;
~hatSteps   = (0!16);
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 50;
~percSteps  = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.4;
~reload.value; "=== DRONE DOOM 60 BPM ===".postln;
)
