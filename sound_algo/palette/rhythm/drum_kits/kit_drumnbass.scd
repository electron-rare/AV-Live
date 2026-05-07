// =========================================================
//  KIT DRUM'N'BASS -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickDrive = 1.5; ~kickClick = 0.3;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
~clapSteps  = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT DnB ===".postln;
)
