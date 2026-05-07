// =========================================================
//  GOA TRANCE 145 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=56;~kickPitchAmt=3.5;~kickDecay=0.25;~kickDrive=1.5;~kickClick=0.22;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 100;
~percSteps  = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.30;
~reload.value; "=== GOA TRANCE 145 BPM ===".postln;
)
