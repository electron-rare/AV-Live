// =========================================================
//  KIT INDUSTRIAL -- kick metal + snare reverse + perc clang -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28; ~kickDrive = 3.5; ~kickClick = 0.4;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~snareFreq = 260; ~snareNoiseAmt = 0.8; ~snareDecay = 0.10;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,1]; ~percAmp = 0.4;
~reload.value; "=== KIT INDUSTRIAL ===".postln;
)
