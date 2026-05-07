// =====================================================================
//  examples/13_world_ethno.scd  --  Workflow oriental / world / asia
//
//  TITRE       : Construire un morceau ethnique
//  DUREE       : ~6 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd) charge synth/_index.scd
//                qui inclut taiko, didgeridoo, guzheng, shakuhachi, tabla
//                ainsi que toute la palette asia (koto, erhu, pipa, ...)
//                + palette/chords_progressions.scd pour ~progHijaz +
//                ~progVietnam (a charger separement) :
(
(~base ++ "palette/chords_progressions.scd").load;
(~base ++ "palette/rhythm/_index.scd").load;
)
//
//  PALETTE
//    asia         : \koto \erhu \pipa \gong \growl \reeseHard
//    authentic    : \didgeridoo \guzheng \shakuhachi \taiko \tabla
//    progressions : ~progHijaz ~progVietnam ~progHirajoshi
//    melodies     : ~melodyByGenre.(\oriental | \asian | \tribal)
// =====================================================================


// --- [etape 1] Demarrer un beat tribal de base --------------------
//   Kick lent + tabla sur les contre-temps.
(
~bpm = 92;
TempoClock.default.tempo = ~bpm / 60;
~kickAmp = 0.45; ~hatAmp = 0.0;
~kickFreq = 50; ~kickDecay = 0.5;
~percInst = \tabla;     // tabla en lieu de rim/cowbell
~percSteps = [0,0,1,0, 1,0,1,0, 0,1,0,1, 1,0,0,1]; ~percAmp = 0.4;
~melodyAmp = 0.18;
~reload.value;
[\kickSeq, \percSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
"beat tribal en place".postln;
)


// --- [etape 2] Melodie au koto + scale orientale ------------------
//   ~m17 est une melodie asian dans palette/melodies/short.scd.
(
~melodyInst = \koto;
~melodyAttack = 0.005; ~melodyRelease = 0.4;
~melodyCutoff = 5500; ~melodyAmp = 0.2;
~melodyNotes = ~m17.copy;
~reload.value;
"=== melodie KOTO -- ~m17 ===".postln;
)


// --- [etape 3] Tirer une melodie aleatoire dans le bank \oriental --
//   ~melodyByGenre.(\oriental) lit ~melodyBank[\oriental] (10 melodies)
//   et applique une au hasard.
( ~melodyByGenre.(\oriental); )
//  -- relancer plusieurs fois pour decouvrir d'autres melodies.


// --- [etape 4] Couche basse au didgeridoo (drone bourdonnant) -----
//   On utilise la voix harmony : pose un drone profond sur la fond.
(
~harmonyInst = \didgeridoo;
~harmonyAttack = 0.05; ~harmonyRelease = 1.5;
~harmonyAmp = 0.22;
~harmonyDur = 1.0;
~enableHarmony.(\bassline);     // genere une bassline depuis melody
~reload.value;
"=== didgeridoo bassline ===".postln;
)


// --- [etape 5] Reemplacer perc par taiko -------------------------
//   Le taiko sonne plus martial, parfait pour buildup.
(
~percInst = \taiko;
~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,1, 0,1,0,0]; ~percAmp = 0.5;
~reload.value;
"=== taiko perc ===".postln;
)


// --- [etape 6] Melodie depuis prog Hijaz (gamme arabe) ------------
//   chordsToMelody deroule les notes des accords sur 32 pas.
(
~melodyNotes = ~chordsToMelody.(~progHijaz);
~melodyInst = \shakuhachi;     // flute japonaise
~reload.value;
"=== shakuhachi -- prog HIJAZ ===".postln;
)


// --- [etape 7] Melodie depuis prog Vietnam ------------------------
(
~melodyNotes = ~chordsToMelody.(~progVietnam);
~melodyInst = \erhu;       // violon chinois
~melodyAttack = 0.2; ~melodyRelease = 0.6;
~reload.value;
"=== erhu -- prog VIETNAM ===".postln;
)


// --- [etape 8] ~seqWorldEvolve -- sequence world toute prete ------
//   Avant : on coupe la rythmique, la sequence prend le controle.
(
[\kickSeq, \percSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
~seqWorldEvolve.();
"=== seqWorldEvolve ===".postln;
)
//  -- Routine de ~30s qui fait evoluer le mix world.


// --- [etape 9] VCF formant -- voyelles pour le coté incantatoire --
//   live.scd doit avoir ete setup avant cette etape (sinon ~vcfOn nil).
( ~vcfOn !? { ~vcfOn.(\formant, 0, 0.2) }; )    // 'a' large
//  -- changer de voyelle avec ~vcfSet
( ~vcfSet !? { ~vcfSet.(\vowel, 2) }; )         // 'i' aigue
( ~vcfSet !? { ~vcfSet.(\vowel, 3) }; )         // 'o' rond
( ~vcfOff !? { ~vcfOff.() }; )


// --- [etape 10] STOP global ----------------------------------------
(
~seqStop !? { ~seqStop.() };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
