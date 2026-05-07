// =========================================================
//  KIT FOOTWORK -- rapid hat + 808 + clap stutter -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0]; ~kickAmp = 0.55;
~kickFreq = 42; ~kickPitchAmt = 2.4; ~kickDecay = 0.5; ~kickDrive = 1.3; ~kickClick = 0.10;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~percAmp = 0.22;
~reload.value; "=== KIT FOOTWORK ===".postln;
)
