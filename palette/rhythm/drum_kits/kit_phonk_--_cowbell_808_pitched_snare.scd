// =========================================================
//  KIT PHONK -- cowbell + 808 + pitched snare -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.6;
~kickFreq = 40; ~kickPitchAmt = 2.0; ~kickDecay = 0.7; ~kickDrive = 1.2; ~kickClick = 0.08;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.45;
~snareFreq = 280; ~snareNoiseAmt = 0.65; ~snareDecay = 0.14;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percInst = \cowbell; ~cowbellFreq = 800;
~percSteps = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.32;
~reload.value; "=== KIT PHONK ===".postln;
)
