// =====================================================================
//  styles.scd
//  5 styles complets : Acid Rave / Deep Dub / Hard Techno / Detroit / Minimal
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
// =====================================================================

// =====================================================================

// --- ACID RAVE -- 132 BPM, full energy, melodie pentatonique ---------
(
~bpm = 132;
~acidNotes   = [ 36, 36, 48, 36, 39, 36, 43, 39,
                 36, 41, 36, 39, 43, 36, 36, 41 ];
~acidAccents = [  1,  0,  0,  0,  1,  0,  1,  0,
                  0,  1,  0,  0,  1,  0,  0,  1 ];
~acidSlides  = [  0,  0,  1,  0,  0,  0,  0,  1,
                  0,  0,  0,  1,  0,  0,  0,  0 ];
~kickSteps   = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
~hatSteps    = [ 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0 ];
~melodyNotes = [ 60, 0, 67, 0, 70, 0, 67, 65,
                 63, 0, 60, 0,  0, 67, 70, 72,
                 75, 0, 72, 70, 67, 0,  0, 65,
                 63, 60, 0, 67, 70, 0, 72,  0 ];
~acidCutoff = 800; ~acidRq = 0.15; ~acidDrive = 2.5; ~acidAmp = 0.32;
~kickAmp = 0.5; ~hatAmp = 0.18;
~melodyCutoff = 2400; ~melodyAttack = 0.012; ~melodyRelease = 0.25; ~melodyAmp = 0.16;
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
"=== ACID RAVE 132 BPM ===".postln;
)

// --- DEEP DUB -- 110 BPM, kick lent, plastikman acid, nappe melodique -
(
~bpm = 110;
~acidNotes   = [ 36, 36, 36, 36, 36, 36, 41, 36,
                 36, 36, 36, 36, 36, 39, 36, 36 ];
~acidAccents = [  1,  0,  0,  0,  0,  0,  0,  0,
                  0,  0,  0,  0,  1,  0,  0,  0 ];
~acidSlides  = [  0,  0,  0,  0,  0,  0,  1,  0,
                  0,  0,  0,  0,  0,  1,  0,  0 ];
~kickSteps   = [ 1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ];
~hatSteps    = [ 0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0 ];
// Nappe lente arpegee
~melodyNotes = [ 60,  0,  0,  0, 63,  0,  0,  0,
                 67,  0,  0,  0, 70,  0,  0,  0,
                 72,  0,  0,  0, 70,  0,  0,  0,
                 67,  0,  0,  0, 63,  0,  0,  0 ];
~acidCutoff = 400; ~acidRq = 0.2; ~acidDrive = 1.6; ~acidAmp = 0.25;
~kickAmp = 0.45; ~hatAmp = 0.10;
~melodyCutoff = 1500; ~melodyAttack = 0.08; ~melodyRelease = 1.2; ~melodyAmp = 0.14;
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
"=== DEEP DUB 110 BPM ===".postln;
)

// --- HARD TECHNO -- 145 BPM, kick double, drive max, pas de melodie ---
(
~bpm = 145;
~acidNotes   = [ 36, 39, 48, 36, 41, 39, 43, 36,
                 39, 41, 36, 48, 39, 36, 41, 39 ];
~acidAccents = [  1,  0,  1,  0,  0,  1,  0,  1,
                  0,  0,  1,  0,  1,  0,  0,  1 ];
~acidSlides  = [  1,  0,  0,  1,  0,  0,  1,  0,
                  0,  1,  0,  1,  0,  1,  0,  0 ];
~kickSteps   = [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ];
~hatSteps    = [ 0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0 ];
~melodyNotes = (0 ! 32);
~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 3.5; ~acidAmp = 0.32;
~kickAmp = 0.5; ~hatAmp = 0.16; ~melodyAmp = 0;
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
"=== HARD TECHNO 145 BPM ===".postln;
)

// --- DETROIT -- 128 BPM, melodie stabs en mineur ---------------------
(
~bpm = 128;
~acidNotes   = [ 36, 36, 48, 36, 39, 36, 43, 39,
                 36, 41, 36, 39, 43, 36, 36, 41 ];
~acidAccents = [  1,  0,  0,  0,  1,  0,  1,  0,
                  0,  1,  0,  0,  1,  0,  0,  1 ];
~acidSlides  = [  0,  0,  1,  0,  0,  0,  0,  1,
                  0,  0,  0,  1,  0,  0,  0,  0 ];
~kickSteps   = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
~hatSteps    = [ 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0 ];
~melodyNotes = [ 63, 0, 0, 0, 70, 0, 67, 0,
                 65, 0, 0, 0, 70, 0, 72, 0,
                 63, 0, 0, 0, 67, 0, 70, 0,
                 65, 0, 60, 0, 67, 0, 0, 0 ];
~acidCutoff = 700; ~acidRq = 0.18; ~acidDrive = 2.2; ~acidAmp = 0.28;
~kickAmp = 0.5; ~hatAmp = 0.15;
~melodyCutoff = 2200; ~melodyAttack = 0.005; ~melodyRelease = 0.1; ~melodyAmp = 0.18;
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
"=== DETROIT 128 BPM ===".postln;
)

// --- MINIMAL -- 124 BPM, epure, melodie 2 notes ----------------------
(
~bpm = 124;
~acidNotes   = [ 36, 0, 0, 0, 36, 0, 0, 0,
                 36, 0, 0, 41, 36, 0, 0, 0 ];
~acidAccents = [  1, 0, 0, 0,  1, 0, 0, 0,
                  1, 0, 0, 0,  1, 0, 0, 0 ];
~acidSlides  = [  0, 0, 0, 0,  0, 0, 0, 0,
                  0, 0, 0, 1,  0, 0, 0, 0 ];
~kickSteps   = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
~hatSteps    = [ 0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0 ];
~melodyNotes = [ 60, 0, 0, 0, 0, 0, 0, 0,
                 67, 0, 0, 0, 0, 0, 0, 0,
                 60, 0, 0, 0, 0, 0, 0, 0,
                 65, 0, 0, 0, 0, 0, 0, 0 ];
~acidCutoff = 500; ~acidRq = 0.25; ~acidDrive = 1.5; ~acidAmp = 0.3;
~kickAmp = 0.5; ~hatAmp = 0.08;
~melodyCutoff = 1800; ~melodyAttack = 0.02; ~melodyRelease = 0.6; ~melodyAmp = 0.13;
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
"=== MINIMAL 124 BPM ===".postln;
)



