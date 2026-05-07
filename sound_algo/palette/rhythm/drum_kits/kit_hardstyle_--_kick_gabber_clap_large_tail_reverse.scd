// =========================================================
//  KIT HARDSTYLE -- kick gabber + clap large + tail "reverse" -- extrait de drum_kits.scd
// =========================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0]; ~kickAmp = 0.65;
~kickFreq = 62; ~kickPitchAmt = 5.5; ~kickDecay = 0.30; ~kickDrive = 4.0; ~kickClick = 0.45;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~snareFreq = 230; ~snareNoiseAmt = 0.7; ~snareDecay = 0.18;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.12;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.45;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~percAmp = 0.22;
~reload.value; "=== KIT HARDSTYLE ===".postln;
)
