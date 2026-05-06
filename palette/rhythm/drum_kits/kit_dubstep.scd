// =========================================================
//  KIT DUBSTEP -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 48; ~kickPitchAmt = 3.5; ~kickDecay = 0.5; ~kickDrive = 1.5; ~kickClick = 0.15;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~snareFreq = 220; ~snareNoiseAmt = 0.65; ~snareDecay = 0.16;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps  = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT DUBSTEP ===".postln;
)
