// =====================================================================
//  examples/07_loops_manager.scd  --  Gestionnaire de boucles
//
//  TITRE       : Demarrer/stopper des Pdef en boucles propres
//  DUREE       : ~6 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + ouvrir loops.scd et evaluer son SETUP (1er bloc top-level)
//
//  CONCEPTS
//    Le moteur expose 8 Pdef (~kickSeq ... ~harmonySeq) que l'on lance
//    classiquement avec Pdef(\xxx).play. loops.scd est une sur-couche
//    qui te permet de :
//      - Nommer chaque boucle (\kick1, \hat1, \verse, \drop ...)
//      - Limiter la duree (en beats / bars / repetitions)
//      - Chainer / parall des boucles
//      - Snapshot l'etat des params au moment du lancement
//      - Fade in / out + countdown
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~loopOn.isNil) {
    "!!! loops.scd pas charge -- ouvre loops.scd et evalue son SETUP".postln;
} {
    "loops.scd OK".postln;
};
)


// --- [etape 1] Demarrer kick + hat en boucle ----------------------
//   ~loopOn.(name, source) ; source = symbol Pdef ou Function
(
~kickAmp = 0.55; ~hatAmp = 0.18; ~reload.value;
~loopOn.(\kick1, \kickSeq);
~loopOn.(\hat1,  \hatSeq);
)


// --- [etape 2] Lister les boucles actives --------------------------
( ~loopList.(); )


// --- [etape 3] Repeat snare 4 fois sur 4 secondes chacune ----------
//   ~loopRepeat.(name, source, n, dur)
//   Demarre snareSeq, joue 4 cycles de 4s, puis stop auto.
(
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~reload.value;
~loopRepeat.(\snare1, \snareSeq, 4, 4);
)
//  -- attendre 16s. Apres, le snare s'arrete tout seul.


// --- [etape 4] Acid sur 32 beats puis stop --------------------------
//   ~loopBeats.(name, source, beats)
( ~loopBeats.(\acid1, \acidSeq, 32); )
//  -- 32 beats = 8 mesures 4/4. Stop automatique.


// --- [etape 5] Lancer m1 avec un countdown 4 beats -----------------
//   ~loopWithCountdown.(name, source, beats, max)
//   Affiche "4...3...2...1..." dans la console puis lance le Pdef.
//   max = inf -> boucle infinie apres le countdown.
( ~loopWithCountdown.(\m1main, \melodySeq, 4, inf); )


// --- [etape 6] Fade-out de la kick sur 4 secondes ------------------
( ~loopFade.(\kick1, 4); )
//  -- la kick descend lineairement vers 0 et se libere.


// --- [etape 7] Chainer 3 boucles dans l'ordre ----------------------
//   ~loopChain.([[name, source, beats], ...])
//   -- chaque entry joue beats puis declenche la suivante.
//   Avant : on coupe ce qui tourne pour avoir un demarrage propre.
( ~loopOffAll.(); )
(
~loopChain.([
    [\a, \kickSeq,    8],     // 8 beats kick seul
    [\b, \melodySeq, 16],     // 16 beats melodie
    [\c, \hatSeq,     8],     // 8 beats hat
]);
)
//  -- duree totale = 32 beats. Suivre dans la console.


// --- [etape 8] Boucles paralleles (toutes en meme temps) ----------
( ~loopOffAll.(); )
(
~loopParallel.([
    [\k, \kickSeq],
    [\h, \hatSeq],
    [\m, \melodySeq],
]);
)


// --- [etape 9] Voir la progression en temps reel -------------------
//   Utile quand tu as des ~loopBeats / ~loopRepeat en cours.
( ~loopProgress.(); )


// --- [etape 10] ~allOn / ~allOff -- les 8 voies du moteur ----------
( ~loopOffAll.(); )
( ~allOn.(); )       // les 8 Pdef du moteur en boucle
//  -- attendre 8s
( ~allOff.(); )      // les 8 stop


// --- [etape 11] STOP global ----------------------------------------
(
~loopOffAll.();
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
