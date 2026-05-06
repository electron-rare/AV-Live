// =========================================================
//  KIT BREAKBEAT -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.3; ~kickDrive = 1.3; ~kickClick = 0.25;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.45;
~snareFreq = 200; ~snareNoiseAmt = 0.6;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.10;
~percInst = \openHat; ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.22;
~clapSteps  = (0 ! 16);
~reload.value; "=== KIT BREAKBEAT ===".postln;
)
