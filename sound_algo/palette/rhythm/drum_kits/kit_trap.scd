// =========================================================
//  KIT TRAP -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq = 42; ~kickPitchAmt = 2.5; ~kickDecay = 0.6; ~kickDrive = 1.2; ~kickClick = 0.08;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,1,0,0, 1,0,1,0, 0,1,0,1]; ~percAmp = 0.2;
~snareSteps = (0 ! 16);
~reload.value; "=== KIT TRAP ===".postln;
)
