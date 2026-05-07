// =========================================================
//  ACID TECHNO (135-150) -- 4-on-floor + hihat shuffle 16ths -- extrait de patterns_genre.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=55;~kickPitchAmt=3.0;~kickDecay=0.32;~kickDrive=1.4;~kickClick=0.22;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.13;  // shuffle
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.35; // discret
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percSteps  = (0!16);
~reload.value; "=== ACID TECHNO 135-150 BPM ===".postln;
)
