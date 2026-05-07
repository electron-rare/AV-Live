// =========================================================
//  TRIBAL TECHNO 130 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 130; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=50;~kickPitchAmt=2.6;~kickDecay=0.34;~kickDrive=1.2;~kickClick=0.12;
~hatSteps   = [0,0,1,0, 0,1,0,1, 0,0,1,0, 0,1,0,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 95;
~percSteps  = [1,0,0,1, 0,1,1,0, 1,0,0,1, 0,1,1,0]; ~percAmp = 0.40;
~reload.value; "=== TRIBAL TECHNO 130 BPM ===".postln;
)
