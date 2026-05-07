// =========================================================
//  KIT TRIBAL WORLD -- perc layered + kick small + shaker -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
~kickFreq = 48; ~kickPitchAmt = 2.2; ~kickDecay = 0.4; ~kickDrive = 1.0; ~kickClick = 0.06;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,0,1,1]; ~hatAmp = 0.08;
~clapSteps  = (0 ! 16);
~percInst = \tom; ~tomFreq = 95;
~percSteps  = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
~reload.value; "=== KIT TRIBAL WORLD ===".postln;
)
