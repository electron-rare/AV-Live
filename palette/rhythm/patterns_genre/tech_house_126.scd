// =========================================================
//  TECH HOUSE 126 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 126; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=52;~kickPitchAmt=2.8;~kickDecay=0.32;~kickDrive=1.3;~kickClick=0.18;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.15;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.34;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,1]; ~percAmp = 0.22;
~reload.value; "=== TECH HOUSE 126 BPM ===".postln;
)
