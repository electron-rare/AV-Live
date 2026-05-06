// =========================================================
//  DRUM & BASS JUMP-UP 174 -- extrait de patterns_genre.scd
// =========================================================
(
~bpm = 174; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,1,1,0, 0,0,1,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=58;~kickPitchAmt=4.2;~kickDecay=0.18;~kickDrive=1.8;~kickClick=0.35;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~snareFreq=240;~snareNoiseAmt=0.7;~snareDecay=0.10;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== DNB JUMP-UP 174 BPM ===".postln;
)
