// =========================================================
//  INDUSTRIAL 145 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,1,0, 1,0,0,0, 1,0,1,0]; ~kickAmp = 0.62;
~kickFreq=62;~kickPitchAmt=5.2;~kickDecay=0.28;~kickDrive=3.8;~kickClick=0.42;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~snareFreq=270;~snareNoiseAmt=0.85;~snareDecay=0.08;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [1,0,0,1, 1,0,1,0, 1,0,0,1, 1,0,1,1]; ~percAmp = 0.45;
~reload.value; "=== INDUSTRIAL 145 BPM (V2) ===".postln;
)
