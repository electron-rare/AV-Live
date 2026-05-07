// =====================================================================
//  examples/09_scenes_recall.scd  --  Save / recall scenes
//
//  TITRE       : Snapshot / restore de l'etat global
//  DUREE       : ~5 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + ouvrir scenes.scd, evaluer son SETUP (1er bloc)
//
//  CONCEPTS
//    Une "scene" est un snapshot de TOUTES les variables d'environnement
//    listees dans ~sceneKeys (kickAmp, melodyNotes, melodyCutoff...).
//    Tu peux la sauvegarder avec ~saveScene.(\nom), la rappeler avec
//    ~loadScene.(\nom), et persister le tout sur disque.
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~saveScene.isNil) {
    "!!! scenes.scd pas charge -- ouvre scenes.scd et evalue son SETUP".postln;
} {
    "scenes.scd OK".postln;
};
)


// --- [etape 1] Lancer une track A pour avoir un point de depart ----
//   Charge tracks/A_acid_journey.scd qui set tous les params ET
//   demarre les Pdef. La track passe en "minimal" pour les ~30 1eres s.
(
(~base ++ "tracks/A_acid_journey.scd").load;
)
//  -- attendre 5s que les params soient stables.


// --- [etape 2] SAVE l'etat actuel comme \verseA --------------------
( ~saveScene.(\verseA); )


// --- [etape 3] Modifier les params (kick + cutoff + melodie) -------
(
~kickAmp = 0.8;
~melodyCutoff = 6500;
~melodyNotes = ~genMelody.(0.7, ~scaleMinor);
~reload.value;
"params modifies".postln;
)


// --- [etape 4] SAVE cet etat comme \verseAvariant ------------------
( ~saveScene.(\verseAvariant); )


// --- [etape 5] LOAD \verseA -- on revient a l'etat initial ---------
( ~loadScene.(\verseA); )
//  -- on entend les params revenir : kick 0.5, cutoff 1500, etc.


// --- [etape 6] LOAD \verseAvariant -- retour a la variante --------
( ~loadScene.(\verseAvariant); )


// --- [etape 7] Lister les scenes sauvegardees ----------------------
( ~listScenes.value; )


// --- [etape 8] Supprimer une scene ---------------------------------
( ~deleteScene.(\verseAvariant); )
( ~listScenes.value; )


// --- [etape 9] Persistence sur disque ------------------------------
//   ~saveScenesToDisk ecrit dans scenes_saved.scd a la racine du projet.
//   ~loadScenesFromDisk recharge depuis ce fichier.
( ~saveScenesToDisk.value; )
//  -- on peut quitter SuperCollider, relancer la session, recharger
//  CHARGER TOUT + scenes.scd, puis :
( ~loadScenesFromDisk.value; )


// --- [etape 10] STOP -----------------------------------------------
(
~track !? { ~track.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
