// =========================================================
//  KIT HOUSE -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickDrive = 1.2; ~kickClick = 0.12;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~snareSteps = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT HOUSE ===".postln;
)
