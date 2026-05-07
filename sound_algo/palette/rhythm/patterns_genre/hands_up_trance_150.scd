// =========================================================
//  HANDS UP TRANCE 150 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 150; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=58;~kickPitchAmt=3.8;~kickDecay=0.26;~kickDrive=1.6;~kickClick=0.25;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.20;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.45;
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.22;
~reload.value; "=== HANDS UP TRANCE 150 BPM ===".postln;
)
