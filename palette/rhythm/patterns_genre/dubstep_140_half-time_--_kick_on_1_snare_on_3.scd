// =========================================================
//  DUBSTEP (140 half-time) -- kick on 1, snare on 3 -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq=48;~kickPitchAmt=3.5;~kickDecay=0.5;~kickDrive=1.5;~kickClick=0.15;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.10;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~snareFreq=220;~snareNoiseAmt=0.7;~snareDecay=0.18;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== DUBSTEP 140 BPM half-time ===".postln;
)
