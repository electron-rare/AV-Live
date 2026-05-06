// =====================================================================
//  examples/01_quickstart.scd  --  Premier demarrage
//
//  TITRE       : Hello, sound_algo
//  DUREE       : ~2 minutes
//  NIVEAU      : debutant
//  PREREQUIS   : aucun (on charge tout depuis ce fichier)
//
//  BUT
//    - Lancer le moteur complet (engine + synthdefs + helpers + live/*)
//    - Demarrer un beat techno minimal (kick + hat + acid)
//    - Modifier 2-3 parametres en live
//    - Stopper proprement
//
//  Chaque parenthese (...) ci-dessous est un bloc independant. Pose
//  ton curseur dedans, Cmd+Entree pour evaluer. Avance bloc par bloc.
// =====================================================================


// --- [etape 1] CHARGER TOUT (~5s, attend que le serveur boote) ------
//   Reproduit exactement le bloc CHARGER TOUT de 00_load.scd : charge
//   engine + synthdefs + scales + melodies + harmonics + setup, puis
//   appelle ~setupAll.() qui boote le serveur et charge fx_bus + live
//   + mixer + scenes + loops + fills + sequences + jump. Termine par
//   un ~check.() qui rapporte l'etat de chaque module.
(
~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
(~base ++ "engine.scd").load;
(~base ++ "synth/_index.scd").load;
(~base ++ "fx/_index.scd").load;
(~base ++ "palette/scales.scd").load;
(~base ++ "palette/melodies/index.scd").load;
(~base ++ "palette/harmonics/index.scd").load;
(~base ++ "setup.scd").load;
~setupAll.();
"=== CHARGEMENT EN COURS -- attendre la fin du boot et le ~check final ===".postln;
)


// --- [etape 2] PLAY -- lance les 8 sequenceurs Pdef -------------------
//   Reproduit le bloc PLAY DEFAULT de 00_load.scd.
//   Attendre que le bloc precedent ait fini son boot (3-5s) et que tu
//   voies "=== setupAll DONE ===" dans le post window.
(
TempoClock.default.tempo = ~bpm / 60;
~reload.value;
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
"=== PLAY ===".postln;
)
//  >> Tu dois entendre kick + hat + acid 303. Laisse tourner 30s.


// --- [etape 3] TWEAK 1 : monter le volume du kick --------------------
//   ~kickAmp est une variable globale. Apres modif, ~reload.value
//   reconstruit les Pdef avec la nouvelle valeur.
(
~kickAmp = 0.7;     // defaut 0.5
~reload.value;
("kickAmp = " ++ ~kickAmp).postln;
)


// --- [etape 4] TWEAK 2 : ouvrir le filtre de la melodie -------------
//   ~melodyCutoff = frequence de coupure du LPF de la voix melody.
(
~melodyCutoff = 5000;  // defaut 2400, plus haut = plus brillant
~reload.value;
("melodyCutoff = " ++ ~melodyCutoff).postln;
)


// --- [etape 5] TWEAK 3 : changer le BPM -------------------------------
(
~bpm = 140;
TempoClock.default.tempo = ~bpm / 60;
("bpm = " ++ ~bpm).postln;
)


// --- [etape 6] STOP -- coupe les sequenceurs --------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)


// --- [etape 7] ARRET TOTAL (libere tout proprement) -------------------
//   ~teardown.() vient de setup.scd : stop tous les Pdef/routines/LFO,
//   libere ~masterLim + ~scBus + bus FX. A faire quand tu veux quitter.
( ~teardown.(); )
