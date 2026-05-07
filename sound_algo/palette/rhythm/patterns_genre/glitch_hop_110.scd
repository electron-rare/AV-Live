// =========================================================
//  GLITCH HOP 110 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 110; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=45;~kickPitchAmt=2.5;~kickDecay=0.45;~kickDrive=1.3;~kickClick=0.15;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.50;
~snareFreq=220;~snareNoiseAmt=0.6;~snareDecay=0.12;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = ~genKickPattern.(0.5); ~percAmp = 0.25;
~reload.value; "=== GLITCH HOP 110 BPM ===".postln;
)
