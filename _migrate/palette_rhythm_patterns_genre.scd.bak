// =====================================================================
//  patterns_genre.scd  -- Patterns rythmiques signature par genre
//                         (issus de la deep recherche musicologique)
//
//  Chaque preset charge kick/hat/snare/clap/perc en alignement
//  authentique au genre. Cmd+Entree = applique le pattern complet.
// =====================================================================



// =====================================================================
//  ACID TECHNO (135-150) -- 4-on-floor + hihat shuffle 16ths
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=55;~kickPitchAmt=3.0;~kickDecay=0.32;~kickDrive=1.4;~kickClick=0.22;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.13;  // shuffle
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.35; // discret
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percSteps  = (0!16);
~reload.value; "=== ACID TECHNO 135-150 BPM ===".postln;
)

// =====================================================================
//  HARD TECHNO (140-148) -- kick punchy distorted + hat 16ths rapide
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=4.5;~kickDecay=0.28;~kickDrive=3.0;~kickClick=0.32;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.14;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
~percSteps  = (0!16);
~reload.value; "=== HARD TECHNO 140-148 BPM ===".postln;
)

// =====================================================================
//  HYPNOTIC TECHNO (128-135) -- kick discret + ghost snare lointain
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=50;~kickPitchAmt=2.5;~kickDecay=0.35;~kickDrive=1.0;~kickClick=0.08;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;  // tres discret
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percSteps  = [0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.15;  // ghost
~reload.value; "=== HYPNOTIC TECHNO 128-135 BPM ===".postln;
)

// =====================================================================
//  DUBSTEP (140 half-time) -- kick on 1, snare on 3 (ressenti 70 BPM)
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq=48;~kickPitchAmt=3.5;~kickDecay=0.5;~kickDrive=1.5;~kickClick=0.15;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.10;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~snareFreq=220;~snareNoiseAmt=0.7;~snareDecay=0.18;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== DUBSTEP 140 BPM half-time ===".postln;
)

// =====================================================================
//  UPLIFTING TRANCE (138) -- kick 4/4 + offbeat bass + clap 2&4
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=55;~kickPitchAmt=3.2;~kickDecay=0.28;~kickDrive=1.5;~kickClick=0.20;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
~percSteps  = (0!16);
~reload.value; "=== UPLIFTING TRANCE 138 BPM ===".postln;
)

// =====================================================================
//  DETROIT TECHNO (124) -- 909 swing 56% + ghost notes
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0]; ~kickAmp = 0.5;  // ghost
~kickFreq=52;~kickPitchAmt=2.8;~kickDecay=0.32;~kickDrive=1.3;~kickClick=0.16;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.13;  // shuffle
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.32;  // ghost claps
~percSteps  = (0!16);
~reload.value; "=== DETROIT TECHNO 124 BPM swing ===".postln;
)

// =====================================================================
//  LIQUID DNB (174) -- amen feel + ghost notes
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=55;~kickPitchAmt=4.0;~kickDecay=0.18;~kickDrive=1.5;~kickClick=0.30;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq=240;~snareNoiseAmt=0.7;~snareDecay=0.10;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== LIQUID DNB 174 BPM amen ===".postln;
)

// =====================================================================
//  NEUROFUNK (174) -- breakbeat complex + 32th rolls
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,1]; ~kickAmp = 0.55;
~kickFreq=58;~kickPitchAmt=4.5;~kickDecay=0.15;~kickDrive=2.0;~kickClick=0.4;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.14;
~snareSteps = [0,0,0,1, 1,0,0,0, 0,1,0,0, 1,0,1,1]; ~snareAmp = 0.55;
~snareFreq=260;~snareNoiseAmt=0.75;~snareDecay=0.08;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== NEUROFUNK DNB 174 BPM ===".postln;
)

// =====================================================================
//  FUTURE GARAGE (130-140) -- 2-step syncope, kick irregulier
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=48;~kickPitchAmt=2.5;~kickDecay=0.5;~kickDrive=1.2;~kickClick=0.10;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;  // skippy
~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.3;  // sparse
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
~percSteps  = (0!16);
~reload.value; "=== FUTURE GARAGE 2-STEP ===".postln;
)

// =====================================================================
//  HARDCORE GABBER (180) -- kick gabber distorted intense, hihat absent
// =====================================================================
(
~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.65;
~kickFreq=60;~kickPitchAmt=5.0;~kickDecay=0.18;~kickDrive=4.0;~kickClick=0.35;
~hatSteps   = (0!16); ~hatAmp = 0;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== HARDCORE GABBER 180 BPM ===".postln;
)

// =====================================================================
//  PHONK (130 half-time) -- cowbell Memphis + 808 + trap hats
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=42;~kickPitchAmt=2.5;~kickDecay=0.6;~kickDrive=1.3;~kickClick=0.10;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;  // trap triplets
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
~percInst = \cowbell; ~cowbellFreq = 800;
~percSteps  = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.32;
~reload.value; "=== PHONK 130 BPM ===".postln;
)

// =====================================================================
//  TRIBAL ETHNO (100-128) -- toms polyrhythm 3:4
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.45;
~kickFreq=48;~kickPitchAmt=2.2;~kickDecay=0.4;~kickDrive=1.1;~kickClick=0.08;
~hatSteps   = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~hatAmp = 0.08;  // organique
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 90;
~percSteps  = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
~reload.value; "=== TRIBAL ETHNO 100 BPM ===".postln;
)

// =====================================================================
//  AMBIENT CINEMATIC (60-80) -- percussions ultra rares + tom solitaire
// =====================================================================
(
~kickSteps  = (0!16); ~kickAmp = 0;
~hatSteps   = (0!16);
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 60;
~percSteps  = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.3;
~reload.value; "=== AMBIENT CINEMATIC -- pas de kick ===".postln;
)

// =====================================================================
//  CHIPTUNE 8-BIT (150) -- kick triangle sharp, noise burst
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=80;~kickPitchAmt=4.5;~kickDecay=0.12;~kickDrive=1.4;~kickClick=0.5;  // chip kick
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.12;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.40;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== CHIPTUNE 8-BIT 150 BPM ===".postln;
)

// =====================================================================
//  SYNTHWAVE 80s (100) -- kick + LinnDrum gated snare + hat 8ths
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
~kickFreq=55;~kickPitchAmt=3.0;~kickDecay=0.3;~kickDrive=1.2;~kickClick=0.18;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;  // gated
~snareFreq=180;~snareNoiseAmt=0.55;~snareDecay=0.20;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;  // doubl
~percSteps  = (0!16);
~reload.value; "=== SYNTHWAVE 100 BPM ===".postln;
)

// =====================================================================
//  INDUSTRIAL TECHNO (140-160) -- kick hard distorded + metal hits
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=5.0;~kickDecay=0.28;~kickDrive=3.5;~kickClick=0.4;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;  // breakbeat
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.4;
~reload.value; "=== INDUSTRIAL TECHNO ===".postln;
)

// =====================================================================
//  DUB TECHNO (126-130) -- kick muffle + clap echo dub
// =====================================================================
(
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
~kickFreq=48;~kickPitchAmt=2.3;~kickDecay=0.45;~kickDrive=1.0;~kickClick=0.06;  // muffled
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 0,1,0,0, 0,0,0,0, 0,1,0,0]; ~clapAmp = 0.25;  // delay
~percSteps  = (0!16);
~reload.value; "=== DUB TECHNO 126 BPM ===".postln;
)

// =====================================================================
//  GLITCH IDM (variable) -- patterns generes aleatoires
// =====================================================================
(
~kickSteps  = ~genKickPattern.(0.4);
~snareSteps = ~genKickPattern.(0.3);
~hatSteps   = ~genKickPattern.(0.7);
~clapSteps  = ~genKickPattern.(0.2);
~percSteps  = ~genKickPattern.(0.4);
~kickFreq=55;~kickPitchAmt=3.5;~kickDecay=0.18;~kickDrive=2.0;~kickClick=0.3;
~kickAmp = 0.5; ~hatAmp = 0.12; ~snareAmp = 0.45; ~clapAmp = 0.3; ~percAmp = 0.3;
~reload.value; "=== GLITCH IDM random ===".postln;
)

// =====================================================================
//  DRONE DOOM (60) -- kick massif espace + crash long
// =====================================================================
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq=40;~kickPitchAmt=2.0;~kickDecay=0.8;~kickDrive=2.0;~kickClick=0.04;
~hatSteps   = (0!16);
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 50;
~percSteps  = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.4;
~reload.value; "=== DRONE DOOM 60 BPM ===".postln;
)



// =====================================================================
//  =====  21 GENRES SUPPLEMENTAIRES (deuxieme batch)  =================
// =====================================================================



// =====================================================================
//  HARD TECHNO BERLIN (140-145) -- 4/4 hard kick + open hat sustain
// =====================================================================
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

// =====================================================================
//  ACID HOUSE 88 BPM (Chicago classique)
// =====================================================================
(
~bpm = 88; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=50;~kickPitchAmt=2.8;~kickDecay=0.38;~kickDrive=1.2;~kickClick=0.10;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.12;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.34;
~percSteps  = (0!16);
~reload.value; "=== ACID HOUSE 88 BPM ===".postln;
)

// =====================================================================
//  TRANCE 138 UPLIFTING (variation grand kick + clap reverb)
// =====================================================================
(
~bpm = 138; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.58;
~kickFreq=55;~kickPitchAmt=3.5;~kickDecay=0.30;~kickDrive=1.6;~kickClick=0.22;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.42;
~percSteps  = [0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,1]; ~percAmp = 0.18;
~percInst = \rim;
~reload.value; "=== TRANCE 138 UPLIFTING (V2) ===".postln;
)

// =====================================================================
//  PSY TRANCE 145 (basse offbeat + kick punchy + hat dense)
// =====================================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=58;~kickPitchAmt=4.0;~kickDecay=0.22;~kickDrive=1.8;~kickClick=0.28;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.16;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.25;
~reload.value; "=== PSY TRANCE 145 BPM ===".postln;
)

// =====================================================================
//  GOA TRANCE 145 (psy roots, 16th notes acid)
// =====================================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=56;~kickPitchAmt=3.5;~kickDecay=0.25;~kickDrive=1.5;~kickClick=0.22;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 100;
~percSteps  = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.30;
~reload.value; "=== GOA TRANCE 145 BPM ===".postln;
)

// =====================================================================
//  HARDSTYLE 150 (kick gabber + reverse kick simulee + clap large)
// =====================================================================
(
~bpm = 150; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0]; ~kickAmp = 0.65;
~kickFreq=62;~kickPitchAmt=5.5;~kickDecay=0.30;~kickDrive=4.0;~kickClick=0.45;
~hatSteps   = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.45;
~percSteps  = (0!16);
~reload.value; "=== HARDSTYLE 150 BPM ===".postln;
)

// =====================================================================
//  HANDS UP TRANCE 150 (eurodance moderne, clap large)
// =====================================================================
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

// =====================================================================
//  LIQUID DNB 174 (alt) -- amen smooth + ghost note + open hat
// =====================================================================
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

// =====================================================================
//  NEUROFUNK DNB 174 (alt) -- snare reese + breakbeat hard
// =====================================================================
(
~bpm = 174; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,1, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq=60;~kickPitchAmt=4.8;~kickDecay=0.14;~kickDrive=2.2;~kickClick=0.42;
~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,0,1, 1,1,1,0]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,1, 1,0,0,0, 0,1,0,0, 1,0,1,1]; ~snareAmp = 0.6;
~snareFreq=270;~snareNoiseAmt=0.8;~snareDecay=0.07;
~clapSteps  = (0!16);
~percSteps  = (0!16);
~reload.value; "=== NEUROFUNK DNB 174 BPM (V2) ===".postln;
)

// =====================================================================
//  JUNGLE 165 (chopped breakbeat + ragga rim)
// =====================================================================
(
~bpm = 165; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=55;~kickPitchAmt=3.5;~kickDecay=0.20;~kickDrive=1.6;~kickClick=0.32;
~hatSteps   = [1,1,0,1, 1,0,1,1, 1,1,0,1, 1,0,1,1]; ~hatAmp = 0.12;
~snareSteps = [0,0,0,0, 1,0,1,0, 0,0,0,1, 1,0,0,1]; ~snareAmp = 0.55;
~snareFreq=220;~snareNoiseAmt=0.7;~snareDecay=0.10;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.30;
~reload.value; "=== JUNGLE 165 BPM ===".postln;
)

// =====================================================================
//  DRUM & BASS JUMP-UP 174 (kick funky + snare bouncy)
// =====================================================================
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

// =====================================================================
//  FUTURE BASS 150 (half-time, snare large, hat trap)
// =====================================================================
(
~bpm = 150; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.55;
~kickFreq=48;~kickPitchAmt=3.0;~kickDecay=0.45;~kickDrive=1.4;~kickClick=0.15;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
~snareFreq=210;~snareNoiseAmt=0.6;~snareDecay=0.20;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,1]; ~percAmp = 0.18;
~reload.value; "=== FUTURE BASS 150 BPM ===".postln;
)

// =====================================================================
//  DEEP HOUSE 122 (kick warm + clap soft + hat shuffled)
// =====================================================================
(
~bpm = 122; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=48;~kickPitchAmt=2.5;~kickDecay=0.40;~kickDrive=1.1;~kickClick=0.10;
~hatSteps   = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.16;
~reload.value; "=== DEEP HOUSE 122 BPM ===".postln;
)

// =====================================================================
//  TECH HOUSE 126 (groove tight + hat 16th + clap tight)
// =====================================================================
(
~bpm = 126; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq=52;~kickPitchAmt=2.8;~kickDecay=0.32;~kickDrive=1.3;~kickClick=0.18;
~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.15;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.34;
~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,1]; ~percAmp = 0.22;
~reload.value; "=== TECH HOUSE 126 BPM ===".postln;
)

// =====================================================================
//  PROGRESSIVE HOUSE 124 (kick pad + clap echo + hat air)
// =====================================================================
(
~bpm = 124; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.52;
~kickFreq=50;~kickPitchAmt=2.6;~kickDecay=0.36;~kickDrive=1.2;~kickClick=0.12;
~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \openHat; ~percSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.20;
~reload.value; "=== PROGRESSIVE HOUSE 124 BPM ===".postln;
)

// =====================================================================
//  TRIBAL TECHNO 130 (toms layered + kick warm + percussions dense)
// =====================================================================
(
~bpm = 130; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
~kickFreq=50;~kickPitchAmt=2.6;~kickDecay=0.34;~kickDrive=1.2;~kickClick=0.12;
~hatSteps   = [0,0,1,0, 0,1,0,1, 0,0,1,0, 0,1,0,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = (0!16);
~percInst = \tom; ~tomFreq = 95;
~percSteps  = [1,0,0,1, 0,1,1,0, 1,0,0,1, 0,1,1,0]; ~percAmp = 0.40;
~reload.value; "=== TRIBAL TECHNO 130 BPM ===".postln;
)

// =====================================================================
//  INDUSTRIAL 145 (alt sombre, perc clang)
// =====================================================================
(
~bpm = 145; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 1,0,1,0, 1,0,0,0, 1,0,1,0]; ~kickAmp = 0.62;
~kickFreq=62;~kickPitchAmt=5.2;~kickDecay=0.28;~kickDrive=3.8;~kickClick=0.42;
~hatSteps   = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.13;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
~snareFreq=270;~snareNoiseAmt=0.85;~snareDecay=0.08;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = [1,0,0,1, 1,0,1,0, 1,0,0,1, 1,0,1,1]; ~percAmp = 0.45;
~reload.value; "=== INDUSTRIAL 145 BPM (V2) ===".postln;
)

// =====================================================================
//  BREAKCORE 200+ (kick hyperdense + breakbeat + snare metallic)
// =====================================================================
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

// =====================================================================
//  FOOTWORK 160 (juke triplet kick + clap stutter)
// =====================================================================
(
~bpm = 160; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0]; ~kickAmp = 0.55;
~kickFreq=42;~kickPitchAmt=2.4;~kickDecay=0.50;~kickDrive=1.3;~kickClick=0.10;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~snareSteps = (0!16);
~clapSteps  = [0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0]; ~clapAmp = 0.32;
~percInst = \rim; ~percSteps = [0,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~percAmp = 0.22;
~reload.value; "=== FOOTWORK 160 BPM ===".postln;
)

// =====================================================================
//  IDM (intelligent dance music, variable, glitchy random)
// =====================================================================
(
~bpm = 130; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = ~genKickPattern.(0.35);
~snareSteps = ~genKickPattern.(0.25);
~hatSteps   = ~genKickPattern.(0.65);
~clapSteps  = ~genKickPattern.(0.18);
~percSteps  = ~genKickPattern.(0.40);
~kickFreq=55;~kickPitchAmt=3.2;~kickDecay=0.22;~kickDrive=1.8;~kickClick=0.28;
~kickAmp = 0.5; ~hatAmp = 0.12; ~snareAmp = 0.45; ~clapAmp = 0.28; ~percAmp = 0.30;
~reload.value; "=== IDM (random) ===".postln;
)

// =====================================================================
//  GLITCH HOP 110 (half-time hip-hop + glitch perc)
// =====================================================================
(
~bpm = 110; TempoClock.default.tempo = ~bpm/60;
~kickSteps  = [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~kickAmp = 0.55;
~kickFreq=45;~kickPitchAmt=2.5;~kickDecay=0.45;~kickDrive=1.3;~kickClick=0.15;
~hatSteps   = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.50;
~snareFreq=220;~snareNoiseAmt=0.6;~snareDecay=0.12;
~clapSteps  = (0!16);
~percInst = \rim; ~percSteps = ~genKickPattern.(0.5); ~percAmp = 0.25;
~reload.value; "=== GLITCH HOP 110 BPM ===".postln;
)

