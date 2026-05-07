// =====================================================================
//  examples/03_multi_melody_tracks.scd  --  Multi-pistes melodiques
//
//  TITRE       : Plusieurs voix melodiques en parallele
//  DUREE       : ~5 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT dans 00_load.scd (charge melodies/index.scd
//                qui charge tracks.scd avec ses 3 pistes par defaut)
//
//  BUT
//    Le moteur a UNE voix melody (\melodySeq). Ce systeme s'AJOUTE
//    en parallele : chaque piste \m1, \m2, \m3 a son propre Pdef
//    independant + Event de parametres dans ~mel[\name].
//
//    Helpers : ~melTrackOn / Off / Set / Solo / Harm / List
// =====================================================================


// --- [etape 1] Setup de base -- demarrer la rythmique --------------
//   On garde le kick + hat du moteur, on coupe la melodie LEGACY (\melodySeq)
//   pour que les nouvelles pistes soient seules a faire de la melodie.
(
~kickAmp = 0.55; ~hatAmp = 0.18;
~melodyAmp = 0;       // mute la melodie legacy
~reload.value;
[\kickSeq, \hatSeq].do { |k| Pdef(k).play };
"rythmique en place -- prochaine etape : ~melTrackOn".postln;
)


// --- [etape 2] Lancer la piste m1 (lead pad par defaut) -------------
//   m1 est preconfigure avec ~m1 (32 notes, scale minor pent).
( ~melTrackOn.(\m1); )


// --- [etape 3] Changer l'instrument de m1 -- warmPad ---------------
//   ~melTrackSet rebuild le Pdef automatiquement.
( ~melTrackSet.(\m1, \inst, \warmPad); )


// --- [etape 4] Changer la melodie de m1 -- on prend ml5 (64 pas) ---
//   ml5 est une melodie longue de 64 pas (palette/melodies/long.scd).
//   .copy car on ne veut pas que les futures mutations modifient ~ml5.
( ~melTrackSet.(\m1, \notes, ~ml5.copy); )


// --- [etape 5] Lancer la piste m2 (counter pluck) -------------------
//   m2 est preconfiguree pluck pan -0.3 (cote gauche).
( ~melTrackOn.(\m2); )


// --- [etape 6] Changer m2 en pluck rapide --------------------------
//   On peut empiler les ~melTrackSet.
(
~melTrackSet.(\m2, \inst, \pluck);
~melTrackSet.(\m2, \dur, 0.125);    // 1/32 (rapide)
~melTrackSet.(\m2, \pan, -0.5);
)


// --- [etape 7] Generer une harmonie automatique sur m1 -------------
//   ~melTrackHarm.(source, dest, preset) cree une nouvelle piste
//   "harm1" derivee de m1, harmonisee a la tierce.
//   Presets : \third \fifth \counter \arp \chord \tranceLayer ...
( ~melTrackHarm.(\m1, \harm1, \third); )

// (variante) harmonie a la quinte au lieu de la tierce
// ( ~melTrackHarm.(\m1, \harm1, \fifth); )


// --- [etape 8] Solo / Unsolo (mute toutes sauf une) -----------------
( ~melTrackSolo.(\m1); )       // seule m1 est audible
//  -- attendre 8 secondes
( ~melTrackUnsolo.(); )


// --- [etape 9] Lister toutes les pistes actives ---------------------
( ~melTrackList.(); )


// --- [etape 10] Tirer une melodie aleatoire par genre --------------
//   Exemple : trance pour m1, oriental pour m2.
( ~melTrackByGenre.(\m1, \trance); )
( ~melTrackByGenre.(\m2, \oriental); )


// --- [etape 11] Stop des pistes melodiques --------------------------
(
~melTrackOff.(\m1);
~melTrackOff.(\m2);
~melTrackOff.(\harm1);
"melodic tracks OFF".postln;
)


// --- [etape 12] STOP complet (rythmique aussi) ---------------------
(
~melTrackChoke.();    // stop TOUTES les pistes melodiques
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP COMPLET ===".postln;
)
