// =========================================================
//  FOOTWORK 160 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 160; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0]; ~kickAmp = 0.55;
~kickFreq=42;~kickPitchAmt=2.4;~kickDecay=0.50;~kickDrive=1.3;~kickClick=0.10;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~percAmp = 0.22;
~reload.value; "=== FOOTWORK 160 BPM ===".postln;
)
