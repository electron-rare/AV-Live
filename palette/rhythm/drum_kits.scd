// =====================================================================
//  drum_kits.scd
//  21 drum kits complets :
//    Originaux : TECHNO / DUBSTEP / DnB / TRAP / HOUSE / BREAKBEAT
//    Nouveaux  : HARDSTYLE / DRUM'N'BASS / JUNGLE / GARAGE 2-STEP /
//                TRAP808 / PHONK / FOOTWORK / LIQUID DnB / SYNTHWAVE /
//                INDUSTRIAL / TRIBAL WORLD / HARDCORE / LO-FI HIP-HOP /
//                FUTURE GARAGE / DETROIT DEEP
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
// =====================================================================



// =====================================================================
//  KITS ORIGINAUX (conserves)
// =====================================================================

// --- KIT TECHNO -----------------------------------------------------
(
~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickDrive = 1.3; ~kickClick = 0.2;
~hatSteps  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~snareSteps = (0 ! 16); ~clapSteps = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT TECHNO ===".postln;
)

// --- KIT DUBSTEP ----------------------------------------------------
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 48; ~kickPitchAmt = 3.5; ~kickDecay = 0.5; ~kickDrive = 1.5; ~kickClick = 0.15;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~snareFreq = 220; ~snareNoiseAmt = 0.65; ~snareDecay = 0.16;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps  = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT DUBSTEP ===".postln;
)

// --- KIT DRUM'N'BASS -----------------------------------------------
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickDrive = 1.5; ~kickClick = 0.3;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
~clapSteps  = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT DnB ===".postln;
)

// --- KIT TRAP ------------------------------------------------------
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq = 42; ~kickPitchAmt = 2.5; ~kickDecay = 0.6; ~kickDrive = 1.2; ~kickClick = 0.08;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,1,0,0, 1,0,1,0, 0,1,0,1]; ~percAmp = 0.2;
~snareSteps = (0 ! 16);
~reload.value; "=== KIT TRAP ===".postln;
)

// --- KIT HOUSE ------------------------------------------------------
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickDrive = 1.2; ~kickClick = 0.12;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~snareSteps = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT HOUSE ===".postln;
)

// --- KIT BREAKBEAT --------------------------------------------------
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.3; ~kickDrive = 1.3; ~kickClick = 0.25;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.45;
~snareFreq = 200; ~snareNoiseAmt = 0.6;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.10;
~percInst = \openHat; ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.22;
~clapSteps  = (0 ! 16);
~reload.value; "=== KIT BREAKBEAT ===".postln;
)



// =====================================================================
//  NOUVEAUX KITS
// =====================================================================

// --- KIT HARDSTYLE -- kick gabber + clap large + tail "reverse" -----
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

// --- KIT DRUM'N'BASS PUNCHY (alt) -- kick punchy + amen + hat fast --
(
~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 58; ~kickPitchAmt = 4.5; ~kickDecay = 0.16; ~kickDrive = 1.8; ~kickClick = 0.4;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1]; ~snareAmp = 0.55;
~snareFreq = 250; ~snareNoiseAmt = 0.75; ~snareDecay = 0.09;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.13;
~clapSteps  = (0 ! 16);
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT DRUM'N'BASS PUNCHY ===".postln;
)

// --- KIT JUNGLE -- chopped breakbeat + ragga rim --------------------
(
~kickSteps  = [1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickDrive = 1.6; ~kickClick = 0.32;
~snareSteps = [0,0,0,0, 1,0,1,0, 0,0,0,1, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq = 220; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
~hatSteps   = [1,1,0,1, 1,0,1,1, 1,1,0,1, 1,0,1,1]; ~hatAmp = 0.12;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.30;
~reload.value; "=== KIT JUNGLE ===".postln;
)

// --- KIT GARAGE 2-STEP -- clap shuffled + snare pad -----------------
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickDrive = 1.2; ~kickClick = 0.15;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.4;
~snareFreq = 200; ~snareNoiseAmt = 0.55; ~snareDecay = 0.20;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.11;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = (0 ! 16);
~reload.value; "=== KIT GARAGE 2-STEP ===".postln;
)

// --- KIT TRAP808 -- 808 boom + clap + hi-hat trap rolls -------------
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.6;
~kickFreq = 38; ~kickPitchAmt = 1.8; ~kickDecay = 0.85; ~kickDrive = 1.0; ~kickClick = 0.05;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,1,0, 1,1,1,1, 1,1,1,0, 1,1,1,1]; ~hatAmp = 0.09;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,0,0, 1,0,1,0, 0,1,1,0]; ~percAmp = 0.18;
~reload.value; "=== KIT TRAP808 ===".postln;
)

// --- KIT PHONK -- cowbell + 808 + pitched snare --------------------
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.6;
~kickFreq = 40; ~kickPitchAmt = 2.0; ~kickDecay = 0.7; ~kickDrive = 1.2; ~kickClick = 0.08;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.45;
~snareFreq = 280; ~snareNoiseAmt = 0.65; ~snareDecay = 0.14;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percInst = \cowbell; ~cowbellFreq = 800;
~percSteps = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.32;
~reload.value; "=== KIT PHONK ===".postln;
)

// --- KIT FOOTWORK -- rapid hat + 808 + clap stutter -----------------
(
~kickSteps  = [1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0]; ~kickAmp = 0.55;
~kickFreq = 42; ~kickPitchAmt = 2.4; ~kickDecay = 0.5; ~kickDrive = 1.3; ~kickClick = 0.10;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~percAmp = 0.22;
~reload.value; "=== KIT FOOTWORK ===".postln;
)

// --- KIT LIQUID DnB -- subtle kick + breakbeat + smooth hat ---------
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq = 50; ~kickPitchAmt = 3.0; ~kickDecay = 0.28; ~kickDrive = 1.2; ~kickClick = 0.18;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.42;
~snareFreq = 220; ~snareNoiseAmt = 0.55; ~snareDecay = 0.14;
~hatSteps   = [1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.09;
~clapSteps  = (0 ! 16);
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT LIQUID DnB ===".postln;
)

// --- KIT SYNTHWAVE -- kick 80s + reverb snare + hat soft ------------
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.30; ~kickDrive = 1.2; ~kickClick = 0.18;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~snareFreq = 180; ~snareNoiseAmt = 0.55; ~snareDecay = 0.22;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT SYNTHWAVE ===".postln;
)

// --- KIT INDUSTRIAL -- kick metal + snare reverse + perc clang ------
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28; ~kickDrive = 3.5; ~kickClick = 0.4;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~snareFreq = 260; ~snareNoiseAmt = 0.8; ~snareDecay = 0.10;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,1]; ~percAmp = 0.4;
~reload.value; "=== KIT INDUSTRIAL ===".postln;
)

// --- KIT TRIBAL WORLD -- perc layered + kick small + shaker ---------
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
~kickFreq = 48; ~kickPitchAmt = 2.2; ~kickDecay = 0.4; ~kickDrive = 1.0; ~kickClick = 0.06;
~snareSteps = (0 ! 16);
~hatSteps   = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,0,1,1]; ~hatAmp = 0.08;
~clapSteps  = (0 ! 16);
~percInst = \tom; ~tomFreq = 95;
~percSteps  = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
~reload.value; "=== KIT TRIBAL WORLD ===".postln;
)

// --- KIT HARDCORE -- kick sature + snare 909 distordu + claps -------
(
~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.65;
~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.20; ~kickDrive = 4.0; ~kickClick = 0.35;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq = 240; ~snareNoiseAmt = 0.85; ~snareDecay = 0.10;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.12;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.42;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT HARDCORE ===".postln;
)

// --- KIT LO-FI HIP-HOP -- kick muted + snare vinyl + perc dust ------
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~kickAmp = 0.45;
~kickFreq = 45; ~kickPitchAmt = 2.0; ~kickDecay = 0.55; ~kickDrive = 1.0; ~kickClick = 0.04;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.40;
~snareFreq = 190; ~snareNoiseAmt = 0.45; ~snareDecay = 0.15;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.08;
~clapSteps  = (0 ! 16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.14;
~reload.value; "=== KIT LO-FI HIP-HOP ===".postln;
)

// --- KIT FUTURE GARAGE -- kick rolling + snare ghost + 16th hat -----
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickDrive = 1.2; ~kickClick = 0.10;
~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.30;
~snareFreq = 210; ~snareNoiseAmt = 0.5; ~snareDecay = 0.15;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
~percSteps  = (0 ! 16);
~reload.value; "=== KIT FUTURE GARAGE ===".postln;
)

// --- KIT DETROIT DEEP -- kick 909 + clap warm + perc minimal --------
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.32; ~kickDrive = 1.3; ~kickClick = 0.16;
~snareSteps = (0 ! 16);
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.13;
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
~reload.value; "=== KIT DETROIT DEEP ===".postln;
)



