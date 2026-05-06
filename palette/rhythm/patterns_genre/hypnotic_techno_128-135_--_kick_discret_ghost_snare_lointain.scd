// =========================================================
//  HYPNOTIC TECHNO (128-135) -- kick discret + ghost snare lointain -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=50;~kickPitchAmt=2.5;~kickDecay=0.35;~kickDrive=1.0;~kickClick=0.08;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;  // tres discret
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percSteps  = [0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.15;  // ghost
~reload.value; "=== HYPNOTIC TECHNO 128-135 BPM ===".postln;
)
