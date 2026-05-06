// =========================================================
//  PROGRESSIVE HOUSE 124 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 124; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.52;
~kickFreq=50;~kickPitchAmt=2.6;~kickDecay=0.36;~kickDrive=1.2;~kickClick=0.12;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.20;
~reload.value; "=== PROGRESSIVE HOUSE 124 BPM ===".postln;
)
