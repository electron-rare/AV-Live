// =====================================================================
//  examples/08_jump_sections.scd  --  Naviguer dans les tracks
//
//  TITRE       : ~jumpTo -- aller direct a une section de track
//  DUREE       : ~5 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + ouvrir jump.scd, evaluer SETUP JUMP (1er bloc) et
//                evaluer le bloc ~sections['A'] = (...) pour A
//
//  CONCEPTS
//    jump.scd indexe ~sections[trackLetter][slug] -> { ...code... }
//    pour chaque section de chaque track. Utile pour :
//      - Tester rapidement le drop d'une track sans attendre 4 minutes
//      - Faire un medley en alternant les sections de plusieurs tracks
//      - Skip-mode pendant une perf live
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~jumpTo.isNil) {
    "!!! jump.scd pas charge -- ouvre jump.scd et evalue SETUP JUMP".postln;
} {
    if (~sections['A'].isNil) {
        "!!! ~sections['A'] vide -- evalue le bloc 'TRACK A' de jump.scd".postln;
    } {
        "jump.scd + sections A OK".postln;
    };
};
)


// --- [etape 1] Saut direct sur l'intro de A ------------------------
//   ~jumpTo.(letter, slug)  -- letter = 'A' (string char) ou \A
//   Le slug doit correspondre a une cle de ~sections['A'].
( ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad'); )
//  -- on entend immediatement le 1er moment de A (intro pad lent).
//  Laisser tourner ~30s.


// --- [etape 2] Saut direct sur l'acid rave (drop de A) -------------
( ~jumpTo.('A', 'acid_rave_kick_t1_melody_lead_variations'); )
//  -- le drop arrive instantanement, sans attendre les 2 minutes
//  d'intro normale.


// --- [etape 3] Detroit stabs (3e section) --------------------------
( ~jumpTo.('A', 'detroit_stabs_kick_t2_melody_stab'); )


// --- [etape 4] Hard push (4e section) ------------------------------
( ~jumpTo.('A', 'hard_push_kick_t4_distordu'); )


// --- [etape 5] Outro -----------------------------------------------
( ~jumpTo.('A', 'outro_melody_pad_qui_s_efface'); )


// --- [etape 6] MEDLEY -- comparer des sections rapidement ----------
//   On joue 4 sections, ~10s chacune, dans une Routine.
//   Utile pour audition rapide.
(
Routine({
    "[medley] intro".postln;
    ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad');
    10.wait;
    "[medley] acid rave".postln;
    ~jumpTo.('A', 'acid_rave_kick_t1_melody_lead_variations');
    10.wait;
    "[medley] detroit".postln;
    ~jumpTo.('A', 'detroit_stabs_kick_t2_melody_stab');
    10.wait;
    "[medley] hard push".postln;
    ~jumpTo.('A', 'hard_push_kick_t4_distordu');
    10.wait;
    "[medley] OUTRO".postln;
    ~jumpTo.('A', 'outro_melody_pad_qui_s_efface');
}).play;
)


// --- [etape 7] (bonus) Comparer la meme section de plusieurs tracks
//   Ouvre jump.scd, evalue le bloc ~sections['B'] et ~sections['F'].
//   Puis :
//     ( ~jumpTo.('B', 'dub_start_kick_t3_boomy_melody_pad'); )
//     ( ~jumpTo.('F', '...'); )
//   (les slugs disponibles sont commentes en bas de chaque bloc de jump.scd)


// --- [etape 8] STOP ------------------------------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
