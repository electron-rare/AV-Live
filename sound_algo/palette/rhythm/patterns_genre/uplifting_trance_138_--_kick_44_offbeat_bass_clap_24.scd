// =========================================================
//  UPLIFTING TRANCE (138) -- kick 4/4 + offbeat bass + clap 2&4 -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=55;~kickPitchAmt=3.2;~kickDecay=0.28;~kickDrive=1.5;~kickClick=0.20;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~percSteps  = (0!16);
~reload.value; "=== UPLIFTING TRANCE 138 BPM ===".postln;
)
