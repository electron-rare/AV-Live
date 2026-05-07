// =========================================================
//  KIT DETROIT DEEP -- kick 909 + clap warm + perc minimal -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.32; ~kickDrive = 1.3; ~kickClick = 0.16;
~snareSteps = (0 ! 16);
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.13;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT DETROIT DEEP ===".postln;
)
