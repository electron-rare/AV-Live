// =========================================================
//  TRANCE 138 UPLIFTING -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 138; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.58;
~kickFreq=55;~kickPitchAmt=3.5;~kickDecay=0.30;~kickDrive=1.6;~kickClick=0.22;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.42;
~percSteps  = [0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,1]; ~percAmp = 0.18;
~percInst = \rim;
~reload.value; "=== TRANCE 138 UPLIFTING (V2) ===".postln;
)
