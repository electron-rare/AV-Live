// =========================================================
//  KIT GARAGE 2-STEP -- clap shuffled + snare pad -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickDrive = 1.2; ~kickClick = 0.15;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.4;
~snareFreq = 200; ~snareNoiseAmt = 0.55; ~snareDecay = 0.20;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.11;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = (0 ! 16);
~reload.value; "=== KIT GARAGE 2-STEP ===".postln;
)
