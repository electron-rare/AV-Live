// =========================================================
//  KIT DRUM'N'BASS PUNCHY (alt) -- kick punchy + amen + hat fast -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 58; ~kickPitchAmt = 4.5; ~kickDecay = 0.16; ~kickDrive = 1.8; ~kickClick = 0.4;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1]; ~snareAmp = 0.55;
~snareFreq = 250; ~snareNoiseAmt = 0.75; ~snareDecay = 0.09;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.13;
~clapSteps  = (0 ! 16);
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT DRUM'N'BASS PUNCHY ===".postln;
)
