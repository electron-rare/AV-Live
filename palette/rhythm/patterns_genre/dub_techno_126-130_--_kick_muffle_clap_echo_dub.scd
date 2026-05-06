// =========================================================
//  DUB TECHNO (126-130) -- kick muffle + clap echo dub -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=48;~kickPitchAmt=2.3;~kickDecay=0.45;~kickDrive=1.0;~kickClick=0.06;  // muffled
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 0,1,0,0, 0,0,0,0, 0,1,0,0]; ~clapAmp = 0.25;  // delay
~percSteps  = (0!16);
~reload.value; "=== DUB TECHNO 126 BPM ===".postln;
)
