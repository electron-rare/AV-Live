// =====================================================================
//  examples/06_drum_kits_sequences.scd  --  Kits + sequences
//
//  TITRE       : Macros pour swap de kit + sequences scenaristiques
//  DUREE       : ~6 minutes
//  NIVEAU      : debutant
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//
//  BUT
//    palette/rhythm/drum_kits/   : 21 kits complets (Techno, DnB, Phonk, ...)
//      -- chaque kit est un fichier qui set ~kickSteps + ~hatSteps + ...
//         et appelle ~reload.value
//    palette/rhythm/sequences/   : macros de sequences pretes a l'emploi
//      -- chaque seq est une Routine qui orchestre transitions + tempo
//
//  Le _index.scd charge fills + sequences. Les drum_kits restent
//  evalues a la demande (Cmd+Entree sur le fichier d'un kit).
// =====================================================================


// --- [etape 1] Charger sequences + un kit au choix -----------------
(
(~base ++ "palette/rhythm/_index.scd").load;     // fills + sequences
(~base ++ "palette/rhythm/drum_kits/kit_techno.scd").load;  // exemple kit
"sequences + kit techno charges".postln;
)


// --- [etape 2] Lancer le moteur -----------------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
"PLAY".postln;
)


// --- [etape 3] KIT TECHNO -- 4/4 classique -------------------------
//   Le kit set kickSteps + hatSteps + amp, puis ~reload.value.
//   On entend tout de suite la diff.
(
~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
~kickDrive = 1.3; ~kickClick = 0.2;
~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~snareSteps = (0 ! 16); ~clapSteps = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT TECHNO ===".postln;
)
//  -- ecouter 16 beats puis passer au kit suivant.


// --- [etape 4] KIT DUBSTEP -- kick lourd + snare backbeat ----------
(
~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 48; ~kickPitchAmt = 3.5; ~kickDecay = 0.5;
~kickDrive = 1.5; ~kickClick = 0.15;
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.5;
~snareFreq = 220; ~snareNoiseAmt = 0.65; ~snareDecay = 0.16;
~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps  = (0 ! 16); ~percSteps = (0 ! 16);
~reload.value; "=== KIT DUBSTEP ===".postln;
)


// --- [etape 5] KIT PHONK -- cowbell + 808 + pitched snare ----------
//   Ce kit existe dans drum_kits.scd ; on peut aussi recharger
//   directement le fichier et evaluer le bloc dedie.
(
~kickSteps = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0]; ~kickAmp = 0.55;
~kickFreq = 42; ~kickPitchAmt = 2.5; ~kickDecay = 0.6;
~kickDrive = 1.2; ~kickClick = 0.05;        // 808 boomy
~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
~snareFreq = 280; ~snareNoiseAmt = 0.4; ~snareDecay = 0.08;
~hatSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.12;
~percInst = \cowbell;
~percSteps = [0,0,0,1, 0,0,0,0, 0,0,0,1, 0,0,1,0]; ~percAmp = 0.2;
~clapSteps = (0 ! 16);
~reload.value; "=== KIT PHONK ===".postln;
)


// --- [etape 6] Couper le moteur avant de tester les sequences -----
//   Les ~seqXxx prennent le controle ; on coupe les Pdef pour eviter
//   les conflits avec leur orchestration interne.
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"sequenceurs stoppes -- pret pour ~seqXxx".postln;
)


// --- [etape 7] ~seqIntro -- montee progressive (~30s) --------------
( ~seqIntro.(); )
//  -- la sequence dure ~30 secondes ; attendre la fin.


// --- [etape 8] ~seqBuildup.(bars) -- crescendo trance --------------
//   .(8) = 8 mesures. Snare roll + filtre qui s'ouvre + amp up.
( ~seqBuildup.(8); )


// --- [etape 9] ~seqDrop -- drop techno (silence sec + blast) -------
( ~seqDrop.(); )


// --- [etape 10] ~seqTechnoLoop.(repeats) -- N pattern techno -------
( ~seqTechnoLoop.(4); )
//  -- joue 4 iterations d'un pattern techno classique.


// --- [etape 11] ~seqDubstepDrop -- drop dubstep ---------------------
( ~seqDubstepDrop.(); )


// --- [etape 12] ~seqAcidEvolve -- acid qui mute progressivement ----
//   Genere ~30s d'acid avec mutations toutes les 4 mesures.
( ~seqAcidEvolve.(); )


// --- [etape 13] STOP la sequence en cours --------------------------
( ~seqStop.(); )


// --- [etape 14] STOP global ----------------------------------------
(
~seqStop.();
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
