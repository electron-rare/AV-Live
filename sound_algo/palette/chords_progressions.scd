// =====================================================================
//  chords_progressions.scd  -- Progressions d'accords authentiques
//                              (issus de la deep recherche)
//
//  Cm = i, Eb = III, Ab = VI, Bb = VII (degres mineur naturel)
// =====================================================================

// --- Trance i-VII-VI-VII (Am-G-F-G classique) ---------------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 67, 0,    // Am
    55, 0, 59, 0, 62, 0, 67, 0,    // G
    53, 0, 57, 0, 60, 0, 65, 0,    // F
    55, 0, 59, 0, 62, 0, 67, 0     // G
];
~reload.value; "trance i-VII-VI-VII".postln;
)

// --- Detroit Cm-Eb-Ab-Bb (mineur naturel, soulful) ---------------
(
~melodyNotes = [
    60, 0, 63, 0, 67, 0, 70, 0,    // Cm
    63, 0, 65, 0, 67, 0, 72, 0,    // Eb
    56, 0, 60, 0, 63, 0, 68, 0,    // Ab (b6)
    58, 0, 62, 0, 65, 0, 70, 0     // Bb (b7)
];
~reload.value; "detroit Cm-Eb-Ab-Bb".postln;
)

// --- Vocal trance i-VI-III-VII (Am-F-C-G emotional) ---------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 0, 0,    // Am
    53, 0, 57, 0, 60, 0, 0, 0,    // F
    60, 0, 64, 0, 67, 0, 0, 0,    // C
    55, 0, 59, 0, 62, 0, 0, 0     // G
];
~reload.value; "vocal trance i-VI-III-VII".postln;
)

// --- Synthwave i-bVI-bVII-i (Am-F-G-Am 80s) ----------------------
(
~melodyNotes = [
    57, 0, 60, 64, 60, 0, 64, 67,    // Am
    53, 0, 57, 60, 57, 0, 60, 65,    // F
    55, 0, 59, 62, 59, 0, 62, 67,    // G
    57, 0, 60, 64, 60, 64, 67, 72    // Am
];
~reload.value; "synthwave i-bVI-bVII-i".postln;
)

// --- Phonk i-bVII-bVI dark loop ----------------------------------
(
~melodyNotes = [
    48, 0, 0, 0, 51, 0, 0, 0,    // Cm root
    46, 0, 0, 0, 50, 0, 0, 0,    // Bb (bVII)
    44, 0, 0, 0, 48, 0, 0, 0,    // Ab (bVI)
    46, 0, 0, 0, 51, 0, 0, 0     // Bb
];
~reload.value; "phonk dark i-bVII-bVI".postln;
)

// --- Dubstep mineur harmonique (Cm avec B natural) ---------------
(
~melodyNotes = [
    36, 0, 0, 0, 36, 0, 39, 0,    // C bass
    36, 0, 0, 0, 41, 0, 0, 0,    // F
    36, 0, 0, 0, 39, 0, 41, 0,    // C-Eb-F
    47, 0, 0, 0, 48, 0, 0, 0     // B-C (lead tone)
];
~reload.value; "dubstep harmonic minor".postln;
)

// --- Acid trance phrygien dominant (E phryigien) -----------------
(
~melodyNotes = [
    52, 53, 56, 59, 60, 59, 56, 53,    // E F G# B C
    52, 53, 56, 59, 60, 64, 60, 59,
    52, 56, 59, 60, 64, 67, 64, 60,
    52, 53, 56, 59, 60, 59, 56, 52
];
~reload.value; "acid phrygien dominant".postln;
)

// --- Drum'n'Bass liquid (Em mélodique) ---------------------------
(
~melodyNotes = [
    64, 0, 67, 0, 71, 0, 67, 64,    // Em
    62, 0, 65, 0, 69, 0, 67, 0,    // D
    60, 0, 64, 0, 67, 0, 71, 0,    // C
    59, 0, 62, 0, 67, 0, 71, 0     // B
];
~reload.value; "liquid dnb Em melodic".postln;
)

// --- Detroit Cm7 jazz comping ------------------------------------
(
~melodyNotes = [
    60, 63, 67, 70, 67, 63, 60, 67,    // Cm7
    55, 60, 63, 65, 60, 55, 0, 0,
    58, 62, 65, 68, 65, 62, 58, 65,    // Bb7
    60, 63, 67, 70, 0, 0, 0, 0
];
~reload.value; "detroit Cm7 jazz".postln;
)

// --- Asian pentatonique majeure (Do Re Mi Sol La) ----------------
(
~melodyNotes = [
    60, 0, 62, 0, 65, 0, 67, 0,
    69, 0, 67, 0, 65, 0, 62, 0,
    72, 0, 69, 0, 67, 0, 65, 0,
    62, 0, 60, 0, 65, 0, 67, 0
];
~reload.value; "asian penta majeure".postln;
)

// --- Hirajoshi (gamme japonaise 1, 2, b3, 5, b6) -----------------
(
~melodyNotes = [
    60, 0, 62, 63, 0, 67, 68, 0,
    72, 0, 68, 67, 63, 62, 60, 0,
    60, 0, 62, 63, 67, 68, 72, 0,
    74, 75, 72, 68, 67, 63, 62, 60
];
~reload.value; "hirajoshi japonais".postln;
)

// --- Industrial : atonal/cluster (chromatique sombre) -----------
(
~melodyNotes = [
    36, 37, 0, 39, 36, 0, 38, 37,
    36, 37, 38, 40, 0, 39, 37, 36,
    36, 0, 39, 0, 41, 0, 39, 0,
    36, 37, 0, 36, 0, 38, 36, 0
];
~reload.value; "industrial atonal cluster".postln;
)

// --- Drone doom : quintes ouvertes (power chords) ---------------
(
~melodyNotes = [
    36, 0, 0, 0, 0, 0, 0, 0,
    43, 0, 0, 0, 0, 0, 0, 0,    // 5te
    36, 0, 0, 0, 0, 0, 0, 0,
    41, 0, 0, 0, 0, 0, 0, 0     // b6
];
~reload.value; "drone doom power chords".postln;
)

// --- Tribal : modal hijaz (gamme arabe) -------------------------
(
~melodyNotes = [
    60, 0, 61, 0, 64, 0, 65, 0,    // 1, b2, 3, 4
    67, 0, 68, 0, 71, 0, 72, 0,    // 5, b6, 7, 1
    72, 0, 71, 0, 68, 0, 67, 0,
    65, 0, 64, 0, 61, 0, 60, 0
];
~reload.value; "tribal hijaz arabe".postln;
)

// --- Glitch IDM : intervalles dissonants --------------------------
(
~melodyNotes = [
    60, 73, 67, 0, 72, 65, 0, 71,
    63, 0, 76, 67, 0, 60, 73, 0,
    65, 0, 72, 79, 65, 0, 71, 60,
    73, 67, 0, 80, 64, 71, 65, 0
];
~reload.value; "glitch IDM dissonant".postln;
)

// --- Hardcore : mineur harmonique distordu ------------------------
(
~melodyNotes = [
    36, 0, 0, 0, 39, 0, 0, 0,
    41, 0, 0, 0, 47, 0, 0, 0,    // 7e majeure caracteristique mineur harmonique
    48, 0, 0, 0, 47, 0, 41, 0,
    39, 0, 0, 0, 36, 0, 0, 0
];
~reload.value; "hardcore mineur harmonique".postln;
)



// =====================================================================
//  =====  TABLEAUX D'ACCORDS (~progXxx)  ==============================
//
//  Format compact : ~progXxx = [[c1n1, c1n2, c1n3], [c2n1, c2n2, c2n3], ...]
//  chaque sous-array = 1 accord (3 ou 4 notes MIDI).
//  A utiliser depuis melodies/harmony helpers ou pour generer
//  ~melodyNotes/~harmonyNotes en deroulant les accords.
//
//  Helper : ~chordsToMelody.(progArr, stepsPerChord) deroule un tableau
//  d'accords en ligne melodique (top note de chaque accord, espacee).
// =====================================================================
(
// --- Helper : deroule progression en ligne melodique 32 steps ---------
~chordsToMelody = { |prog, stepsPerChord = 8|
    var n = prog.size;
    var notes = Array.fill(n * stepsPerChord, { 0 });
    prog.do { |chord, ci|
        // place tonique sur premier step, top sur step central
        notes[ci * stepsPerChord] = chord[0];
        if (chord.size > 1) {
            notes[ci * stepsPerChord + (stepsPerChord/2).asInteger] = chord.last;
        };
    };
    notes;
};

// --- Helper : deroule prog en harmonie (toutes notes empilees) -------
~chordsToHarmony = { |prog, stepsPerChord = 8|
    var n = prog.size;
    var notes = Array.fill(n * stepsPerChord, { 0 });
    // mode simple : tonique de chaque accord en debut
    prog.do { |chord, ci|
        notes[ci * stepsPerChord] = chord[0];
    };
    notes;
};



// --- Jazz ii-V-I (en C : Dm7 G7 Cmaj7) -------------------------------
~progIIVI    = [ [62, 65, 69, 72], [55, 59, 62, 65], [60, 64, 67, 71] ];

// --- Rock/Blues I-IV-V (en C) ---------------------------------------
~progIIVV    = [ [60, 64, 67], [65, 69, 72], [67, 71, 74] ];

// --- Pop I-V-vi-IV (en C) -- "axis of awesome" ----------------------
~progPop     = [ [60, 64, 67], [67, 71, 74], [69, 72, 76], [65, 69, 72] ];

// --- Sad pop vi-IV-I-V (en C) ---------------------------------------
~progSadPop  = [ [69, 72, 76], [65, 69, 72], [60, 64, 67], [67, 71, 74] ];

// --- Epique mineur i-iv-VII-III (en Am) -----------------------------
~progEpicMin = [ [57, 60, 64], [62, 65, 69], [67, 71, 74], [64, 67, 71] ];

// --- Andalouse i-VI-III-VII (en Am) ---------------------------------
~progAndalou = [ [57, 60, 64], [65, 69, 72], [60, 64, 67], [67, 71, 74] ];

// --- Rock mineur i-bVII-bVI-bVII (en Am) ----------------------------
~progRockMin = [ [57, 60, 64], [55, 59, 62], [53, 57, 60], [55, 59, 62] ];

// --- Flamenco i-bVII-bVI-V (en Am) ----------------------------------
~progFlamenco = [ [57, 60, 64], [55, 59, 62], [53, 57, 60], [52, 56, 59] ];

// --- Jazz turn-around I-vi-ii-V (en C) ------------------------------
~progTurnArnd = [ [60, 64, 67, 71], [69, 72, 76, 79], [62, 65, 69, 72], [55, 59, 62, 65] ];

// --- Modal interchange (bIII, bVI, bVII en C major) ------------------
~progModal   = [ [60, 64, 67], [63, 67, 70], [68, 72, 75], [70, 74, 77] ];

// --- Tritone substitution (Dm7 - Db7 - Cmaj7) ------------------------
~progTritone = [ [62, 65, 69, 72], [49, 53, 56, 59], [60, 64, 67, 71] ];

// --- Minor 7th progressions (Cm7-Fm7-Bb7-Ebmaj7) --------------------
~progMin7    = [ [60, 63, 67, 70], [65, 68, 72, 75], [58, 62, 65, 68], [63, 67, 70, 74] ];

// --- Coltrane changes (B-D-Eb-Gb-G-Bb-B) augmente -------------------
~progColtrane = [ [59, 63, 66], [50, 54, 57], [51, 55, 58],
                  [54, 58, 61], [55, 59, 62], [58, 62, 65], [59, 63, 66] ];

// --- Phrygien i-bII-bVII-bVI (en E phrygien) ------------------------
~progPhrygien = [ [52, 55, 59], [53, 56, 60], [50, 53, 57], [48, 51, 55] ];

// --- Lydien I-II-vii (en C lydien) ----------------------------------
~progLydien  = [ [60, 64, 67], [62, 66, 69], [71, 74, 77] ];

// --- Dorien (i-IV en D dorien) --------------------------------------
~progDorien  = [ [62, 65, 69], [67, 71, 74] ];

// --- Hungarian minor (Am avec quartes augmentees -- D#) -------------
~progHungar  = [ [57, 60, 64], [62, 65, 68], [55, 58, 62], [57, 60, 64] ];

// --- Hijaz Arabic I-bII-iii-IV (en C hijaz) -------------------------
~progHijaz   = [ [60, 61, 64], [61, 64, 68], [64, 67, 71], [65, 69, 72] ];

// --- Vietnamese pentatonique (oan : C-Db-F-G-Ab) --------------------
~progVietnam = [ [60, 65, 67], [61, 65, 68], [60, 67, 72], [60, 65, 67] ];

// --- Hirajoshi (gamme japonaise : 1-2-b3-5-b6) -----------------------
~progHirajoshi = [ [60, 62, 63], [60, 67, 68], [62, 63, 67] ];

// --- Detroit techno standard i-bIII-bVI-bVII (en Am) ----------------
~progDetroit = [ [57, 60, 64], [60, 63, 67], [65, 69, 72], [67, 71, 74] ];

// --- Trance i-VI-VII-i (en Am) --------------------------------------
~progTrance  = [ [57, 60, 64], [65, 69, 72], [67, 71, 74], [57, 60, 64] ];

// --- Drum'n'bass 2 chord vamp (Em-Cmaj7) -----------------------------
~progDnB     = [ [64, 67, 71], [60, 64, 67, 71] ];

// --- Dubstep wobble bass (1 accord drone Cm) ------------------------
~progDubstep = [ [48, 51, 55] ];

// --- Synthwave I-V-vi-iii (en C) ------------------------------------
~progSynthwave = [ [60, 64, 67], [67, 71, 74], [69, 72, 76], [64, 67, 71] ];

// --- Ambient drone (cluster Cmaj7add9) -------------------------------
~progAmbient = [ [60, 62, 64, 67, 71] ];

"=== Progressions tabulaires (~progXxx) chargees ===".postln;
)



// =====================================================================
//  =====  PROGRESSIONS AUTO-APPLICANTES (~melodyNotes 32 steps)  ======
// =====================================================================

// --- Jazz ii-V-I (Dm7-G7-Cmaj7) -- 8 steps par accord ---------------
(
~melodyNotes = [
    62, 0, 65, 0, 69, 0, 72, 0,
    55, 0, 59, 0, 62, 0, 65, 0,
    60, 0, 64, 0, 67, 0, 71, 0,
    60, 0, 64, 0, 67, 0, 71, 0
];
~reload.value; "jazz ii-V-I".postln;
)

// --- Rock/Blues I-IV-V (C-F-G) -------------------------------------
(
~melodyNotes = [
    60, 0, 64, 0, 67, 0, 60, 0,
    65, 0, 69, 0, 72, 0, 65, 0,
    67, 0, 71, 0, 74, 0, 67, 0,
    60, 0, 64, 0, 67, 0, 60, 0
];
~reload.value; "rock blues I-IV-V".postln;
)

// --- Pop I-V-vi-IV (C-G-Am-F) -- "axis of awesome" -----------------
(
~melodyNotes = [
    60, 0, 64, 0, 67, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0,
	    60, 0, 64, 0, 67, 0, 60, 0,
    65, 0, 69, 0, 72, 0, 65, 0,
    67, 0, 71, 0, 74, 0, 67, 0,
    60, 0, 64, 0, 67, 0, 60, 0,
    69, 0, 72, 0, 76, 0, 0, 0,
    65, 0, 69, 0, 72, 0, 0, 0,
	    69, 0, 72, 0, 76, 0, 0, 0,
    65, 0, 69, 0, 72, 0, 0, 0,
    60, 0, 64, 0, 67, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0,
	    60, 0, 64, 0, 67, 0, 60, 0,
    65, 0, 69, 0, 72, 0, 65, 0,
    67, 0, 71, 0, 74, 0, 67, 0,
    60, 0, 64, 0, 67, 0, 60, 0
];
~reload.value; "pop I-V-vi-IV".postln;
)

// --- Sad pop vi-IV-I-V (Am-F-C-G) ----------------------------------
(
~melodyNotes = [
    69, 0, 72, 0, 76, 0, 0, 0,
    65, 0, 69, 0, 72, 0, 0, 0,
    60, 0, 64, 0, 67, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0
];
~reload.value; "sad pop vi-IV-I-V".postln;
)

// --- Epique mineur i-iv-VII-III (Am-Dm-G-C) ------------------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 0, 0,
    62, 0, 65, 0, 69, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0,
    64, 0, 67, 0, 71, 0, 0, 0
];
~reload.value; "epique mineur i-iv-VII-III".postln;
)

// --- Andalouse i-VI-III-VII (Am-F-C-G) -----------------------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 0, 0,
    65, 0, 69, 0, 72, 0, 0, 0,
    60, 0, 64, 0, 67, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0
];
~reload.value; "andalouse i-VI-III-VII".postln;
)

// --- Rock mineur i-bVII-bVI-bVII (Am-G-F-G) ------------------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 0, 0,
    55, 0, 59, 0, 62, 0, 0, 0,
    53, 0, 57, 0, 60, 0, 0, 0,
    55, 0, 59, 0, 62, 0, 0, 0
];
~reload.value; "rock mineur i-bVII-bVI-bVII".postln;
)

// --- Flamenco i-bVII-bVI-V (Am-G-F-E) ------------------------------
(
~melodyNotes = [
    57, 0, 60, 0, 64, 0, 0, 0,
    55, 0, 59, 0, 62, 0, 0, 0,
    53, 0, 57, 0, 60, 0, 0, 0,
    52, 0, 56, 0, 59, 0, 0, 0
];
~reload.value; "flamenco i-bVII-bVI-V".postln;
)

// --- Jazz turn-around I-vi-ii-V (C-Am-Dm-G7) -----------------------
(
~melodyNotes = [
    60, 0, 64, 0, 67, 0, 71, 0,
    69, 0, 72, 0, 76, 0, 79, 0,
    62, 0, 65, 0, 69, 0, 72, 0,
    55, 0, 59, 0, 62, 0, 65, 0
];
~reload.value; "jazz turn-around I-vi-ii-V".postln;
)

// --- Modal interchange (C-Eb-Ab-Bb -- emprunts mineur naturel) -----
(
~melodyNotes = [
    60, 0, 64, 0, 67, 0, 0, 0,
    63, 0, 67, 0, 70, 0, 0, 0,
    68, 0, 72, 0, 75, 0, 0, 0,
    70, 0, 74, 0, 77, 0, 0, 0
];
~reload.value; "modal interchange bIII-bVI-bVII".postln;
)

// --- Tritone subst (Dm7-Db7-Cmaj7) ---------------------------------
(
~melodyNotes = [
    62, 0, 65, 0, 69, 0, 72, 0,
    62, 0, 65, 0, 69, 0, 72, 0,
    49, 0, 53, 0, 56, 0, 59, 0,
    60, 0, 64, 0, 67, 0, 71, 0
];
~reload.value; "tritone substitution".postln;
)

// --- Minor 7th progression (Cm7-Fm7-Bb7-Ebmaj7) --------------------
(
~melodyNotes = [
    60, 0, 63, 0, 67, 0, 70, 0,
    65, 0, 68, 0, 72, 0, 75, 0,
    58, 0, 62, 0, 65, 0, 68, 0,
    63, 0, 67, 0, 70, 0, 74, 0
];
~reload.value; "minor 7th progression".postln;
)

// --- Coltrane changes (B-Eb-G augmente classique Giant Steps) ------
(
~melodyNotes = [
    59, 63, 66, 0, 50, 54, 57, 0,
    55, 59, 62, 0, 51, 55, 58, 0,
    54, 58, 61, 0, 59, 63, 66, 0,
    55, 59, 62, 0, 60, 64, 67, 0
];
~reload.value; "Coltrane changes".postln;
)

// --- Phrygien i-bII-bVII-bVI (E-F-D-C en E phrygien) ---------------
(
~melodyNotes = [
    52, 0, 55, 0, 59, 0, 0, 0,
    53, 0, 56, 0, 60, 0, 0, 0,
    50, 0, 53, 0, 57, 0, 0, 0,
    48, 0, 51, 0, 55, 0, 0, 0
];
~reload.value; "phrygien i-bII-bVII-bVI".postln;
)

// --- Lydien I-II-vii (C-D-Bm en C lydien) --------------------------
(
~melodyNotes = [
    60, 0, 64, 0, 67, 0, 0, 0,
    62, 0, 66, 0, 69, 0, 0, 0,
    71, 0, 74, 0, 77, 0, 0, 0,
    60, 0, 64, 0, 67, 0, 0, 0
];
~reload.value; "lydien I-II-vii".postln;
)

// --- Dorien (i-IV en D dorien : Dm-G) ------------------------------
(
~melodyNotes = [
    62, 0, 65, 0, 69, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0,
    62, 0, 65, 0, 69, 0, 0, 0,
    67, 0, 71, 0, 74, 0, 0, 0
];
~reload.value; "dorien i-IV".postln;
)

// --- Hungarian minor (Am avec D# quarte aug) -----------------------
(
~melodyNotes = [
    57, 0, 60, 0, 63, 0, 66, 0,    // Am avec note hongroise
    62, 0, 65, 0, 68, 0, 0, 0,
    55, 0, 58, 0, 62, 0, 0, 0,
    57, 0, 60, 0, 64, 0, 0, 0
];
~reload.value; "hungarian minor".postln;
)

// --- Hijaz Arabic I-bII-iii-IV (C-Db-Em-F) -------------------------
(
~melodyNotes = [
    60, 0, 61, 0, 64, 0, 0, 0,
    61, 0, 64, 0, 68, 0, 0, 0,
    64, 0, 67, 0, 71, 0, 0, 0,
    65, 0, 69, 0, 72, 0, 0, 0
];
~reload.value; "hijaz arabic I-bII-iii-IV".postln;
)

// --- Vietnamese pentatonique oan ------------------------------------
(
~melodyNotes = [
    60, 0, 65, 0, 67, 0, 0, 0,
    61, 0, 65, 0, 68, 0, 0, 0,
    60, 0, 67, 0, 72, 0, 0, 0,
    65, 0, 67, 0, 60, 0, 0, 0
];
~reload.value; "vietnamese pentatonique".postln;
)

