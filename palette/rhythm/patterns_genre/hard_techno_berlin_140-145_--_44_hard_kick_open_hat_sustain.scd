// =========================================================
//  HARD TECHNO BERLIN (140-145) -- 4/4 hard kick + open hat sustain -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 142; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.62;
~kickFreq=62;~kickPitchAmt=4.8;~kickDecay=0.26;~kickDrive=3.2;~kickClick=0.36;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.40;
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.20;
~reload.value; "=== HARD TECHNO BERLIN 142 BPM ===".postln;
)
