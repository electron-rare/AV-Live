// =========================================================
//  NEUROFUNK DNB 174 (alt) -- snare reese + breakbeat hard -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 174; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,1, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=4.8;~kickDecay=0.14;~kickDrive=2.2;~kickClick=0.42;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,0,1, 1,1,1,0]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,1, 1,0,0,0, 0,1,0,0, 1,0,1,1]; ~snareAmp = 0.6;
~snareFreq=270;~snareNoiseAmt=0.8;~snareDecay=0.07;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== NEUROFUNK DNB 174 BPM (V2) ===".postln;
)
