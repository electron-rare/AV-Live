// =========================================================
//  PSY TRANCE 145 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=58;~kickPitchAmt=4.0;~kickDecay=0.22;~kickDrive=1.8;~kickClick=0.28;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.16;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.25;
~reload.value; "=== PSY TRANCE 145 BPM ===".postln;
)
