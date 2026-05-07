// =====================================================================
//  examples/12_chord_progressions.scd  --  Progressions d'accords
//
//  TITRE       : Generer melodie/harmonie depuis ~progXxx
//  DUREE       : ~5 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd) -- charge automatiquement
//                palette/chords_progressions.scd via melodies/index.scd ?
//                NON -- il faut le charger separement :
(
(~base ++ "palette/chords_progressions.scd").load;
)
//
//  CONCEPTS
//    ~progXxx = [[c1n1, c1n2, c1n3], [c2n1, c2n2, c2n3], ...]
//      -- tableau d'accords, chaque accord = liste de notes MIDI
//    ~chordsToMelody.(prog, stepsPerChord)  deroule la prog en melodie
//    ~chordsToHarmony.(prog, stepsPerChord) deroule la prog en harmony
//
//    PROGRESSIONS DISPO : ~progIIVI ~progPop ~progSadPop ~progEpicMin
//      ~progAndalou ~progFlamenco ~progPhrygien ~progLydien ~progDorien
//      ~progHungar ~progHijaz ~progVietnam ~progHirajoshi ~progDetroit
//      ~progTrance ~progDnB ~progDubstep ~progSynthwave ~progAmbient
//      (voir palette/chords_progressions.scd pour la liste complete)
// =====================================================================


// --- [etape 1] Demarrer un beat de base -------------------------
(
~kickAmp = 0.55; ~hatAmp = 0.18; ~melodyAmp = 0.18;
~melodyInst = \warmPad;
~melodyAttack = 0.4; ~melodyRelease = 1.5;
~reload.value;
[\kickSeq, \hatSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
)


// --- [etape 2] Detroit prog -- soulful Cm-Eb-Ab-Bb -----------------
(
~melodyNotes = ~chordsToMelody.(~progDetroit);
~reload.value;
"=== prog DETROIT ===".postln;
)
//  -- on entend la melodie deroulee depuis la prog. Laisser 16-32 beats.


// --- [etape 3] Trance prog (i-VII-VI-VII) --------------------------
(
~melodyNotes = ~chordsToMelody.(~progTrance);
~reload.value;
"=== prog TRANCE ===".postln;
)


// --- [etape 4] Pop prog (axis of awesome : I-V-vi-IV) -------------
(
~melodyNotes = ~chordsToMelody.(~progPop);
~reload.value;
"=== prog POP ===".postln;
)


// --- [etape 5] Andalouse prog (i-VI-III-VII en Am) -----------------
(
~melodyNotes = ~chordsToMelody.(~progAndalou);
~reload.value;
"=== prog ANDALOU ===".postln;
)


// --- [etape 6] Hijaz prog (gamme arabe) ----------------------------
(
~melodyNotes = ~chordsToMelody.(~progHijaz);
~reload.value;
"=== prog HIJAZ ===".postln;
)


// --- [etape 7] Synthwave prog (Am-F-G-Am 80s) ----------------------
(
~melodyNotes = ~chordsToMelody.(~progSynthwave);
~reload.value;
"=== prog SYNTHWAVE ===".postln;
)


// --- [etape 8] DnB prog (Em melodique) -----------------------------
(
~melodyNotes = ~chordsToMelody.(~progDnB);
~reload.value;
"=== prog DnB ===".postln;
)


// --- [etape 9] Empiler une harmonie en plus (depuis la meme prog) --
//   ~chordsToHarmony empile toutes les notes de chaque accord =>
//   genere des "stabs" d'accords joues a 1/4, par dessus la melodie.
(
~harmonyInst = \pad;
~harmonyAmp = 0.16;
~harmonyDur = 1.0;     // 1 noir = 1 stab par beat
~harmonyNotes = ~chordsToHarmony.(~progSynthwave);
~reload.value;
"=== harmony SYNTHWAVE empilee ===".postln;
)


// --- [etape 10] Trance + Trance harmony (full layered) -------------
(
~melodyNotes  = ~chordsToMelody.(~progTrance);
~harmonyNotes = ~chordsToHarmony.(~progTrance);
~reload.value;
"=== prog TRANCE full layered ===".postln;
)


// --- [etape 11] Couper l'harmonie ----------------------------------
( ~harmonyAmp = 0; ~reload.value; "harmony OFF".postln; )


// --- [etape 12] STOP global -----------------------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
