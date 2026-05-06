// =========================================================
//  DEEP HOUSE 122 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 122; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=48;~kickPitchAmt=2.5;~kickDecay=0.40;~kickDrive=1.1;~kickClick=0.10;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.16;
~reload.value; "=== DEEP HOUSE 122 BPM ===".postln;
)
