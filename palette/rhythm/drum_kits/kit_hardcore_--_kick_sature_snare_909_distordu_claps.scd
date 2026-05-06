// =========================================================
//  KIT HARDCORE -- kick sature + snare 909 distordu + claps -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.65;
~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.20; ~kickDrive = 4.0; ~kickClick = 0.35;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq = 240; ~snareNoiseAmt = 0.85; ~snareDecay = 0.10;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.12;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.42;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT HARDCORE ===".postln;
)
