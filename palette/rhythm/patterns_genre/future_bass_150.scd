// =========================================================
//  FUTURE BASS 150 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 150; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.55;
~kickFreq=48;~kickPitchAmt=3.0;~kickDecay=0.45;~kickDrive=1.4;~kickClick=0.15;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~snareFreq=210;~snareNoiseAmt=0.6;~snareDecay=0.20;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,1]; ~percAmp = 0.18;
~reload.value; "=== FUTURE BASS 150 BPM ===".postln;
)
