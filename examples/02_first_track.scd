// =====================================================================
//  examples/02_first_track.scd  --  Lancer ta premiere track
//
//  TITRE       : Track A "Acid Journey" en autopilot
//  DUREE       : ~7 minutes (la duree complete de la track)
//  NIVEAU      : debutant
//  PREREQUIS   : evaluer CHARGER TOUT dans 00_load.scd
//
//  BUT
//    - Charger une track autonome (tracks/A_acid_journey.scd)
//    - La lancer via le bloc principal de la track
//    - Tweaker quelques params pendant qu'elle joue
//    - Stop avec ~track.stop
// =====================================================================


// --- [etape 1] Verifier que le moteur est charge --------------------
//   Si tu vois "engine pas charge", retourne dans 00_load.scd et
//   evalue CHARGER TOUT.
(
if (~reload.isNil) {
    "!!! engine pas charge -- evalue CHARGER TOUT dans 00_load.scd".postln;
} {
    "engine OK -- pret a lancer la track".postln;
};
)


// --- [etape 2] Charger le fichier de la track -----------------------
//   .load ne fait QUE definir ~track (Routine), il ne lance rien.
//   Ouvre tracks/A_acid_journey.scd dans l'IDE pour voir le code.
(
(~base ++ "tracks/A_acid_journey.scd").load;
)
//  -- attendre le post "[A 0:00]" : il indique que la track a demarre.
//  ATTENTION : load() execute le contenu, donc la Routine .play est
//  declenche. La track joue maintenant.


// --- [etape 3] (optionnel) Si tu prefere demarrer manuellement ------
//   Ouvre tracks/A_acid_journey.scd, place ton curseur dans le bloc
//   commencant par "( ~track !? { ~track.stop }; ~track = Routine({"
//   et fais Cmd+Entree. C'est exactement ce que .load fait.


// --- [etape 4] TWEAK pendant que la track joue -----------------------
//   La track a sa propre logique, mais tu peux toujours surcharger
//   les variables globales. Ton override tient jusqu'au prochain
//   "passage" interne de la track qui les reecrit.

// Boost le volume kick pendant la section acid rave
( ~kickAmp = 0.75; ~reload.value; "kickAmp boost".postln; )

// Casser la melodie : nouveau pattern aleatoire dans une scale
( ~melodyNotes = ~genMelody.(0.6, ~scaleMinorPent); ~reload.value; )

// Ajouter une harmonie a la tierce par-dessus
( ~enableHarmony.(\third); )

// Acidifier le filtre acid (resonance up)
( ~acidRq = 0.08; ~acidCutoffEnv = 5500; ~reload.value; )


// --- [etape 5] STOP de la track --------------------------------------
//   ~track.stop arrete la Routine ; les Pdef continuent de jouer
//   le dernier etat. Pour TOUT couper, voir [etape 6].
( ~track !? { ~track.stop; "track stoppee".postln }; )


// --- [etape 6] STOP complet (sequenceurs + track) -------------------
(
~track !? { ~track.stop };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP COMPLET ===".postln;
)
