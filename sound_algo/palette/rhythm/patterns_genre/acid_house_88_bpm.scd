// =========================================================
//  ACID HOUSE 88 BPM -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 88; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=50;~kickPitchAmt=2.8;~kickDecay=0.38;~kickDrive=1.2;~kickClick=0.10;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.12;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.34;
~percSteps  = (0!16);
~reload.value; "=== ACID HOUSE 88 BPM ===".postln;
)
