// =========================================================
//  KIT FUTURE GARAGE -- kick rolling + snare ghost + 16th hat -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickDrive = 1.2; ~kickClick = 0.10;
~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.30;
~snareFreq = 210; ~snareNoiseAmt = 0.5; ~snareDecay = 0.15;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT FUTURE GARAGE ===".postln;
)
