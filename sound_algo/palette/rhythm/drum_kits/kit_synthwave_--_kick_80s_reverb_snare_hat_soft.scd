// =========================================================
//  KIT SYNTHWAVE -- kick 80s + reverb snare + hat soft -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.30; ~kickDrive = 1.2; ~kickClick = 0.18;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~snareFreq = 180; ~snareNoiseAmt = 0.55; ~snareDecay = 0.22;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT SYNTHWAVE ===".postln;
)
