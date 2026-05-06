// =========================================================
//  KIT LIQUID DnB -- subtle kick + breakbeat + smooth hat -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq = 50; ~kickPitchAmt = 3.0; ~kickDecay = 0.28; ~kickDrive = 1.2; ~kickClick = 0.18;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.42;
~snareFreq = 220; ~snareNoiseAmt = 0.55; ~snareDecay = 0.14;
~hatSteps   = [1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.09;
~clapSteps  = (0 ! 16);
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT LIQUID DnB ===".postln;
)
