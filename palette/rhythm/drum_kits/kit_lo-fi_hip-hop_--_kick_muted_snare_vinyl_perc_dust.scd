// =========================================================
//  KIT LO-FI HIP-HOP -- kick muted + snare vinyl + perc dust -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~kickAmp = 0.45;
~kickFreq = 45; ~kickPitchAmt = 2.0; ~kickDecay = 0.55; ~kickDrive = 1.0; ~kickClick = 0.04;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.40;
~snareFreq = 190; ~snareNoiseAmt = 0.45; ~snareDecay = 0.15;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.08;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.14;
~reload.value; "=== KIT LO-FI HIP-HOP ===".postln;
)
