// =========================================================
//  HARDSTYLE 150 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 150; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0]; ~kickAmp = 0.65;
~kickFreq=62;~kickPitchAmt=5.5;~kickDecay=0.30;~kickDrive=4.0;~kickClick=0.45;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.45;
~percSteps  = (0!16);
~reload.value; "=== HARDSTYLE 150 BPM ===".postln;
)
