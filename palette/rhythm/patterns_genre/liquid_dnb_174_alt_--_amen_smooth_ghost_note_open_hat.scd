// =========================================================
//  LIQUID DNB 174 (alt) -- amen smooth + ghost note + open hat -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 174; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=52;~kickPitchAmt=3.5;~kickDecay=0.20;~kickDrive=1.3;~kickClick=0.25;
~hatSteps   = [1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.11;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.45;
~snareFreq=220;~snareNoiseAmt=0.55;~snareDecay=0.13;
~clapSteps  = (0!16);
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== LIQUID DNB 174 BPM (V2) ===".postln;
)
