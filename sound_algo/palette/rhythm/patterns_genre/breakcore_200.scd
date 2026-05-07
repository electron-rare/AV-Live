// =========================================================
//  BREAKCORE 200+ -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 200; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,1,0,1]; ~kickAmp = 0.55;
~kickFreq=80;~kickPitchAmt=4.0;~kickDecay=0.10;~kickDrive=2.5;~kickClick=0.6;
~hatSteps   = [1,1,1,1, 1,0,1,1, 1,1,0,1, 1,1,1,1]; ~hatAmp = 0.12;
~snareSteps = [0,1,0,1, 0,0,1,1, 1,0,0,1, 0,1,1,0]; ~snareAmp = 0.55;
~snareFreq=290;~snareNoiseAmt=0.85;~snareDecay=0.06;
~clapSteps  = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0]; ~clapAmp = 0.30;
~percSteps  = (0!16);
~reload.value; "=== BREAKCORE 200 BPM ===".postln;
)
