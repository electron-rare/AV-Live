// =========================================================
//  SYNTHWAVE 80s (100) -- kick + LinnDrum gated snare + hat 8ths -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=55;~kickPitchAmt=3.0;~kickDecay=0.3;~kickDrive=1.2;~kickClick=0.18;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;  // gated
~snareFreq=180;~snareNoiseAmt=0.55;~snareDecay=0.20;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;  // doubl
~percSteps  = (0!16);
~reload.value; "=== SYNTHWAVE 100 BPM ===".postln;
)
