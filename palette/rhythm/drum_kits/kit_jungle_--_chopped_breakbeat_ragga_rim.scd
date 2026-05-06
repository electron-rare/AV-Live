// =========================================================
//  KIT JUNGLE -- chopped breakbeat + ragga rim -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickDrive = 1.6; ~kickClick = 0.32;
~snareSteps = [0,0,0,0, 1,0,1,0, 0,0,0,1, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq = 220; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
~hatSteps   = [1,1,0,1, 1,0,1,1, 1,1,0,1, 1,0,1,1]; ~hatAmp = 0.12;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.30;
~reload.value; "=== KIT JUNGLE ===".postln;
)
