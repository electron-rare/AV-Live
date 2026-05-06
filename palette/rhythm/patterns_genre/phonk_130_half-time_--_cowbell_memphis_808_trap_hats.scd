// =========================================================
//  PHONK (130 half-time) -- cowbell Memphis + 808 + trap hats -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=42;~kickPitchAmt=2.5;~kickDecay=0.6;~kickDrive=1.3;~kickClick=0.10;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;  // trap triplets
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
~percInst = \cowbell; ~cowbellFreq = 800;
~percSteps  = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.32;
~reload.value; "=== PHONK 130 BPM ===".postln;
)
