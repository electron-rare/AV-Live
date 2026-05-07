// =========================================================
//  LIQUID DNB (174) -- amen feel + ghost notes -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=55;~kickPitchAmt=4.0;~kickDecay=0.18;~kickDrive=1.5;~kickClick=0.30;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq=240;~snareNoiseAmt=0.7;~snareDecay=0.10;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== LIQUID DNB 174 BPM amen ===".postln;
)
