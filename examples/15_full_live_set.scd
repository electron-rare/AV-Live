// =====================================================================
//  examples/15_full_live_set.scd  --  Set live complet 30 minutes
//
//  TITRE       : Performance live structuree avec tous les outils
//  DUREE       : ~30 minutes
//  NIVEAU      : avance
//  PREREQUIS   : CHARGER TOUT (00_load.scd)
//                + SETUP de live.scd (~drop ~breakdown ~vcfOn ...)
//                + SETUP de fx_bus.scd (~send ~fxPreset)
//                + SETUP de mixer.scd (~mixPreset ~setVol ~mute)
//                + SETUP de scenes.scd (~saveScene ~loadScene)
//
//  STRUCTURE DU SET (timeline en minutes)
//      00:00  INTRO        drone + ambient + buildup (4 min)
//      04:00  DROP 1       techno minimal (6 min) avec mute/solo/tweaks
//      10:00  ACID         multi-mel + LFO cutoff + drop (6 min)
//      16:00  BREAKDOWN    chord prog + reverb tail (4 min)
//      20:00  DROP 2       hard kit + bitcrush + glitch (4 min)
//      24:00  TRANCE       seqBuildup + seqDrop final (3 min)
//      27:00  OUTRO        masterFadeOut 4 min
//
//  CONVENTION
//    Tu evalues UN BLOC a chaque transition (les tags [00:00] etc.
//    indiquent le temps suggere). Entre les blocs, tu fais des tweaks
//    libres (changer ~melodyCutoff, lancer un ~drop, etc.).
// =====================================================================


// --- [etape 0] VERIFICATIONS ---------------------------------------
(
var ok = true;
if (~reload.isNil)     { "!!! engine pas charge".postln; ok = false };
if (~drop.isNil)       { "!!! live.scd SETUP manquant".postln; ok = false };
if (~send.isNil)       { "!!! fx_bus.scd SETUP manquant".postln; ok = false };
if (~mixPreset.isNil)  { "!!! mixer.scd SETUP manquant".postln; ok = false };
if (~saveScene.isNil)  { "!!! scenes.scd SETUP manquant".postln; ok = false };
if (ok) { "=== TOUS LES MODULES SONT PRETS ===".postln };
)


// --- [00:00] INTRO -- drone + ambient + buildup -------------------
//   On part d'un mix vide, on monte progressivement.
//   masterVol bas + reverb saturee = ambiance ouverture.
(
~bpm = 124; TempoClock.default.tempo = ~bpm / 60;
~kickAmp = 0; ~hatAmp = 0; ~snareAmp = 0; ~clapAmp = 0; ~percAmp = 0;
~acidAmp = 0; ~melodyAmp = 0; ~harmonyAmp = 0;
~melodyInst = \warmPad;
~melodyAttack = 0.8; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
~harmonyInst = \drone;
~harmonyAttack = 1.0; ~harmonyRelease = 3.0; ~harmonyAmp = 0.0;
~harmonyNotes = [36,0,0,0,0,0,0,0, 36,0,0,0,0,0,0,0,
                 36,0,0,0,0,0,0,0, 36,0,0,0,0,0,0,0];
~melodyNotes = ~m33.copy;     // melodie ambient
~reload.value;
[\melodySeq, \harmonySeq].do { |k| Pdef(k).play };
~fxPreset.(\space);    // shimmer + reverb + chorus
"=== [00:00] INTRO -- drone + ambient ===".postln;
)
//  -- monter doucement ~melodyAmp et ~harmonyAmp en quelques etapes :
//  attendre 30s avant le bloc suivant.

( ~melodyAmp = 0.10; ~harmonyAmp = 0.18; ~reload.value; )    // [00:30]
( ~melodyAmp = 0.16; ~harmonyAmp = 0.22; ~reload.value; )    // [01:30]


// --- [03:30] BUILDUP vers le drop techno -- 30s ------------------
//   Snare roll + filtre qui s'ouvre + masterFadeIn.
(
~buildup.(30);                    // helper de live.scd : snare roll + open filter
~saveScene.(\preDrop1);          // au cas ou
"=== [03:30] BUILDUP -- 30s ===".postln;
)


// --- [04:00] DROP 1 -- TECHNO MINIMAL -----------------------------
//   Kit techno pur 4/4, melody en lead, ~mixPreset \drop.
(
~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.6;
~kickFreq = 55; ~kickDecay = 0.32; ~kickDrive = 1.3; ~kickClick = 0.2;
~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
~snareSteps = (0 ! 16); ~clapSteps = (0 ! 16); ~percSteps = (0 ! 16);
~melodyInst = \lead;
~melodyAttack = 0.012; ~melodyRelease = 0.25; ~melodyCutoff = 2400;
~melodyAmp = 0.18;
~melodyNotes = ~m1.copy;
~harmonyAmp = 0.10;
~reload.value;
[\kickSeq, \hatSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
~fxPreset.(\trance);      // rev + delay 1/8 + chorus
~mixPreset.(\drop);
~saveScene.(\drop1);
"=== [04:00] DROP 1 -- TECHNO MINIMAL ===".postln;
)
//  -- laisser tourner 1 minute, puis tweaks libres :
//   ( ~mute.(\hat); )                 ;; couper le hat 16 beats
//   ( ~unmute.(\hat); )
//   ( ~setVol.(\acid, 1.4); )         ;; pousser l'acid
//   ( ~drop.(4); )                    ;; mini-drop interne


// --- [07:00] VARIATIONS DROP 1 -- mute / solo --------------------
( ~mute.(\hat); )                 // hat coupee
//  -- 8 beats
( ~unmute.(\hat); )
( ~focus.(\melody, 0.4); )        // melodie en avant, autres a 40%
//  -- 16 beats
( ~unfocus.(); )


// --- [08:00] LFO sur le cutoff de la melodie ---------------------
( ~lfoTo.(\melodyCutoff, 0.25, 2000, \sin, 3500); )
//  -- la melodie respire lentement (cycle 4s).


// --- [09:30] mini drop interne avant la transition ACID ----------
( ~drop.(4); )


// --- [10:00] TRANSITION VERS ACID --------------------------------
//   On stoppe le LFO, on bascule sur \saw3 + acid, on enclenche
//   le systeme multi-pistes melodiques.
(
~lfoStopVar.(\melodyCutoff);
~melodyInst = \saw3; ~melodyAmp = 0.18;
~acidAmp = 0.32;
~acidNotes = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
~melodyNotes = ~m29.copy;     // melodie acid
~reload.value;
Pdef(\acidSeq).play;
~mixPreset.(\acidFocus);
"=== [10:00] ACID JOURNEY ===".postln;
)


// --- [11:00] Multi-piste : ajouter m2 en pluck contrer la mel ----
//   m2 est preconfiguree dans melodies/tracks.scd ; on la lance et
//   on lui colle une counter-melody.
(
~melTrackSet.(\m2, \inst, \pluck);
~melTrackSet.(\m2, \notes, ~m25.copy);
~melTrackSet.(\m2, \pan, -0.4);
~melTrackOn.(\m2);
"=== m2 counter pluck ON ===".postln;
)


// --- [12:00] LFO drunk sur le BPM -- subtile derive --------------
( ~lfoTo.(\bpm, 0.05, 6, \drunk, 132); )


// --- [14:00] Drop interne (acid section) -------------------------
( ~drop.(4); )


// --- [15:30] BREAKDOWN -- chord prog + reverb tail ---------------
//   On stoppe le LFO + acid + m2, on fait un breakdown.
(
~lfoStopVar.(\bpm);
TempoClock.default.tempo = 124 / 60; ~bpm = 124;
~melTrackOff.(\m2);
Pdef(\acidSeq).stop;
Pdef(\hatSeq).stop;
~breakdown.(8);
"=== [15:30] BREAKDOWN ===".postln;
)


// --- [16:00] CHORDS PROGRESSION -- Synthwave + harmony ----------
//   chordsToMelody + chordsToHarmony pour empiler une nappe.
(
~melodyInst = \warmPad;
~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
~melodyAmp = 0.16;
~melodyNotes = ~chordsToMelody.(~progSynthwave);
~harmonyInst = \strings;
~harmonyAttack = 0.5; ~harmonyRelease = 2.0; ~harmonyAmp = 0.16;
~harmonyDur = 1.0;
~harmonyNotes = ~chordsToHarmony.(~progSynthwave);
~kickAmp = 0;     // pas de kick pendant le breakdown
~reload.value;
~fxPreset.(\dream);
~mixPreset.(\breakdown);
"=== [16:00] CHORDS SYNTHWAVE ===".postln;
)


// --- [18:00] REVERB TAIL puis BUILDUP final --------------------
( ~reverbTail.(8); )                       // [18:00] tail 8s
( ~buildup.(30); ~saveScene.(\preDrop2); ) // [18:30] buildup 30s


// --- [20:00] DROP 2 -- HARD kit + bitcrush -----------------------
//   Kit hardcore + bitcrush en send + masterSat.
(
~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.7;
~kickFreq = 60; ~kickDecay = 0.25; ~kickDrive = 3.0; ~kickClick = 0.3;
~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
~melodyInst = \hardLead; ~melodyAmp = 0.22; ~melodyDrive = 3.0;
~melodyNotes = ~m67.copy;     // melodie hardcore
~harmonyAmp = 0.0;
~reload.value;
[\kickSeq, \hatSeq, \clapSeq, \melodySeq].do { |k| Pdef(k).play };
~fxPreset.(\industrial);
~satOn !? { ~satOn.(0.4) };       // master saturation legere
~mixPreset.(\hardcore);
~saveScene.(\drop2);
"=== [20:00] DROP 2 -- HARD ===".postln;
)


// --- [22:00] GLITCH + bitcrush moments ---------------------------
( ~glitch.(2); )
//  -- 8 beats
( ~bitCrushNow.(6, 8000, 1); )
//  -- 8 beats
( ~stutter.(8, 1); )
//  -- 8 beats
( ~freeze.(4); )


// --- [24:00] TRANSITION TRANCE -- seqBuildup + seqDrop -----------
//   On stoppe les Pdef pour laisser ~seqXxx prendre le controle.
(
~satOff !? { ~satOff.() };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
~bpm = 138; TempoClock.default.tempo = ~bpm / 60;
~melodyInst = \supersaw;
~melodyNotes = ~chordsToMelody.(~progTrance);
~reload.value;
~fxPreset.(\trance);
"=== [24:00] TRANCE -- seqBuildup ===".postln;
)
( ~seqBuildup.(16); )           // 16 mesures crescendo


// --- [26:00] DROP TRANCE FINAL -----------------------------------
( ~seqDrop.(); )
//  -- attendre la fin de la sequence puis relancer un beat.
(
[\kickSeq, \hatSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
~mixPreset.(\trance);
~saveScene.(\dropFinal);
"=== [26:00] TRANCE FINAL ===".postln;
)


// --- [27:00] OUTRO -- masterFadeOut 4 minutes -------------------
//   ~masterFadeOut diminue masterVol vers 0 sur dur secondes.
//   On laisse les Pdef tourner ; le silence vient progressivement.
(
~masterFadeOut.(240);
"=== [27:00] OUTRO -- fade-out 4 min ===".postln;
)
//  -- patience : 4 minutes pour atteindre 0. Tu peux profiter.


// --- [31:00] STOP TOTAL -----------------------------------------
//   Apres le fade, libere tout proprement.
(
~lfoStopAllVars !? { ~lfoStopAllVars.() };
~lfoStopAll !? { ~lfoStopAll.() };
~vcfOff !? { ~vcfOff.() };
~melTrackChoke !? { ~melTrackChoke.() };
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
~track !? { ~track.stop };
~masterLim !? { ~masterLim.free; ~masterLim = nil };
~scBus !? { ~scBus.free; ~scBus = nil };
"=== SET TERMINE -- merci ===".postln;
)
