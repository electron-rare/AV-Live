// =========================================================
//  KIT TRAP808 -- 808 boom + clap + hi-hat trap rolls -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.6;
~kickFreq = 38; ~kickPitchAmt = 1.8; ~kickDecay = 0.85; ~kickDrive = 1.0; ~kickClick = 0.05;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,1,0, 1,1,1,1, 1,1,1,0, 1,1,1,1]; ~hatAmp = 0.09;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,0,0, 1,0,1,0, 0,1,1,0]; ~percAmp = 0.18;
~reload.value; "=== KIT TRAP808 ===".postln;
)
