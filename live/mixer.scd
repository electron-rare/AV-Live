// =====================================================================
//  mixer.scd  --  Mixer / faders par voie pour systeme live
//
//  PREREQUIS : engine.scd evalue (~kickAmp, ~hatAmp, ..., ~reload defini)
//
//  PHILOSOPHIE
//    Les amps "de reference" (~mixRef) sont les valeurs courantes au
//    moment de l'init du mixer. Les coefficients ~mix sont des
//    multiplicateurs (0..1+) appliques sur ~mixRef avant chaque reload.
//    -> ~setVol.(\kick, 0.5) baisse le kick a 50% de sa valeur de base
//    -> ~mixReset remet tous les coefs a 1 (= valeurs de reference)
//    -> changer ~mixRef.kick rebase la reference (ex: changement de kit)
//
//  USAGE RAPIDE
//    ( ~setVol.(\kick, 0.7); )
//    ( ~mute.(\hat); )                  ( ~unmute.(\hat); )
//    ( ~solo.(\acid); )                 ( ~unsolo.(); )
//    ( ~xfade.(\acid, \melody, 4); )
//    ( ~mixPreset.(\drumsHeavy); )
//    ( ~mixShow.(); )
// =====================================================================

(
// --- 1. Init des structures ----------------------------------------
~mixVoices = [\kick, \hat, \snare, \clap, \perc, \acid, \melody, \harmony];

// Coefficients courants (multiplicateurs 0..1+ par voie)
~mix = ~mix ?? {
    (kick: 1, hat: 1, snare: 1, clap: 1, perc: 1, acid: 1, melody: 1, harmony: 1)
};

// Etats internes
~mixMuted    = ~mixMuted    ?? { Dictionary.new };  // voies mutees -> ancien coef
~mixSoloed   = ~mixSoloed   ?? { Dictionary.new };  // snapshot avant solo
~mixesSaved  = ~mixesSaved  ?? { Dictionary.new };  // mixes nommes
~mixFocusBak = ~mixFocusBak ?? { nil };             // snapshot avant focus
~mixDuckRout = ~mixDuckRout ?? { nil };             // routine duck en cours
~mixFadeRout = ~mixFadeRout ?? { Dictionary.new };  // routines de fade par voie
~mixMasterRt = ~mixMasterRt ?? { nil };             // routine master fade


// ~mixRef : valeurs "de reference" des amps moteur (capturees a l'init)
// Si une voie est consideree mutee (amp = 0), on garde une reference par
// defaut pour pouvoir restaurer.
~mixRefDefaults = (
    kick: 0.5, hat: 0.18, snare: 0.45, clap: 0.35,
    perc: 0.25, acid: 0.32, melody: 0.16, harmony: 0.14
);

// Capture les amps moteur courants comme reference (1ere fois seulement)
~mixCaptureRef = {
    ~mixRef = ();
    ~mixVoices.do { |v|
        var key = (v.asString ++ "Amp").asSymbol;
        var cur = currentEnvironment[key];
        // si amp courant est nil ou 0 -> prend la valeur par defaut
        if (cur.isNil or: { cur == 0 }) {
            ~mixRef[v] = ~mixRefDefaults[v];
        } {
            ~mixRef[v] = cur;
        };
    };
};

// Capture seulement si pas deja fait (preserve la reference entre reloads)
~mixRef ?? { ~mixCaptureRef.value };

// Re-capture force (utile apres changement de kit / preset moteur)
~mixRebase = {
    ~mixCaptureRef.value;
    "[mixer] reference rebase".postln;
};


// --- 2. Application des coefficients --------------------------------
// amp = ref * coef_voie * master  (puis reload des Pdef)
~mixMaster = ~mixMaster ?? 1.0;     // multiplicateur global non-destructif
~mixApply = {
    ~mixVoices.do { |v|
        var key = (v.asString ++ "Amp").asSymbol;
        var refV = ~mixRef[v] ? 0;
        var coef = ~mix[v] ? 1;
        currentEnvironment.put(key, refV * coef * ~mixMaster);
    };
    ~reload.value;
};


// --- 3. Set / get / reset volume par voie ---------------------------
~setVol = { |voie, val|
    if (~mixVoices.includes(voie).not) {
        ("!! voie inconnue : " ++ voie ++ " -- voies : " ++ ~mixVoices).postln;
    } {
        ~mix[voie] = val.max(0);
        ~mixApply.value;
        ("[mix] " ++ voie ++ " = " ++ val.round(0.01)).postln;
    };
};

~getVol = { |voie| ~mix[voie] ? 1 };

~mixReset = {
    ~mixVoices.do { |v| ~mix[v] = 1 };
    ~mixMuted.clear;
    ~mixSoloed.clear;
    ~mixApply.value;
    "[mix] reset (tous coefs = 1)".postln;
};


// --- 4. Mute / Unmute / Solo ----------------------------------------
~mute = { |voie|
    if (~mixVoices.includes(voie).not) {
        ("!! voie inconnue : " ++ voie).postln;
    } {
        if (~mixMuted.includesKey(voie).not) {
            ~mixMuted[voie] = ~mix[voie] ? 1;
            ~mix[voie] = 0;
            ~mixApply.value;
            ("[mute] " ++ voie).postln;
        };
    };
};

~unmute = { |voie|
    if (~mixMuted.includesKey(voie)) {
        ~mix[voie] = ~mixMuted[voie];
        ~mixMuted.removeAt(voie);
        ~mixApply.value;
        ("[unmute] " ++ voie).postln;
    } {
        ("[unmute] " ++ voie ++ " n'etait pas mute").postln;
    };
};

~muteToggle = { |voie|
    if (~mixMuted.includesKey(voie)) { ~unmute.(voie) } { ~mute.(voie) };
};

~muteAll = {
    ~mixVoices.do { |v|
        if (~mixMuted.includesKey(v).not) {
            ~mixMuted[v] = ~mix[v] ? 1;
            ~mix[v] = 0;
        };
    };
    ~mixApply.value;
    "[mute all]".postln;
};

~unmuteAll = {
    ~mixMuted.keysValuesDo { |v, prev| ~mix[v] = prev };
    ~mixMuted.clear;
    ~mixApply.value;
    "[unmute all]".postln;
};

~mutedList = {
    var l = ~mixMuted.keys.asArray;
    ("[muted] " ++ l).postln;
    l;
};

// Solo : mute toutes les autres voies (snapshot dans ~mixSoloed)
~solo = { |voie|
    if (~mixVoices.includes(voie).not) {
        ("!! voie inconnue : " ++ voie).postln;
    } {
        // Si pas deja en solo, snapshot l'etat courant
        if (~mixSoloed.size == 0) {
            ~mixVoices.do { |v| ~mixSoloed[v] = ~mix[v] ? 1 };
        };
        ~mixVoices.do { |v|
            ~mix[v] = if (v == voie) { ~mixSoloed[v] } { 0 };
        };
        ~mixApply.value;
        ("[solo] " ++ voie).postln;
    };
};

~unsolo = {
    if (~mixSoloed.size == 0) {
        "[unsolo] aucun solo actif".postln;
    } {
        ~mixSoloed.keysValuesDo { |v, val| ~mix[v] = val };
        ~mixSoloed.clear;
        ~mixApply.value;
        "[unsolo]".postln;
    };
};


// --- 5. Master volume / fades ---------------------------------------
// Set le multiplicateur master ABSOLU (non destructif sur les coefs voies)
//   ~masterVol.(0.5) -> moitie ; ~masterVol.(1) -> retour normal
~masterVol = { |val|
    ~mixMaster = val.max(0);
    ~mixApply.value;
    ("[master] = " ++ ~mixMaster.round(0.01)).postln;
};

// Fade le multiplicateur master vers une valeur cible (preserve les coefs voies)
~masterFade = { |target = 0, dur = 4|
    ~mixMasterRt !? { ~mixMasterRt.stop };
    ~mixMasterRt = Routine({
        var steps = (dur * 30).max(2).asInteger;
        var startMaster = ~mixMaster ? 1;
        steps.do { |i|
            var t = (i + 1) / steps;
            ~mixMaster = startMaster.blend(target, t);
            ~mixApply.value;
            (dur / steps).wait;
        };
        ("[master fade] -> " ++ target.round(0.01)).postln;
    }).play;
};

// Fade-in depuis 0 vers le master courant (1.0 par defaut)
~masterFadeIn = { |dur = 4, target = 1|
    ~mixMaster = 0;
    ~mixApply.value;
    ~masterFade.(target, dur);
};

// Fade-out vers 0 puis stop des Pdef sequencer (preserve les coefs voies)
~masterFadeOut = { |dur = 4|
    ~mixMasterRt !? { ~mixMasterRt.stop };
    ~mixMasterRt = Routine({
        var steps = (dur * 30).max(2).asInteger;
        var startMaster = ~mixMaster ? 1;
        steps.do { |i|
            var t = (i + 1) / steps;
            ~mixMaster = startMaster.blend(0, t);
            ~mixApply.value;
            (dur / steps).wait;
        };
        [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
         \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
        "[master fade-out] STOP".postln;
    }).play;
};

// Duck momentane : baisse a depth*current pendant attack, restaure en release
~masterDuck = { |depth = 0.3, attack = 0.05, release = 0.4|
    ~mixDuckRout !? { ~mixDuckRout.stop };
    ~mixDuckRout = Routine({
        var snapshot = ();
        var stepsA = (attack * 30).max(2).asInteger;
        var stepsR = (release * 30).max(2).asInteger;
        ~mixVoices.do { |v| snapshot[v] = ~mix[v] ? 1 };
        // attack : descente vers depth*current
        stepsA.do { |i|
            var t = (i + 1) / stepsA;
            ~mixVoices.do { |v|
                ~mix[v] = snapshot[v].blend(snapshot[v] * depth, t);
            };
            ~mixApply.value;
            (attack / stepsA).wait;
        };
        // release : remontee
        stepsR.do { |i|
            var t = (i + 1) / stepsR;
            ~mixVoices.do { |v|
                ~mix[v] = (snapshot[v] * depth).blend(snapshot[v], t);
            };
            ~mixApply.value;
            (release / stepsR).wait;
        };
        "[duck] OK".postln;
    }).play;
};


// --- 6. Presets de balance ------------------------------------------
~mixPresets = (
    flat:        (kick: 1.0, hat: 1.0, snare: 1.0, clap: 1.0,
                  perc: 1.0, acid: 1.0, melody: 1.0, harmony: 1.0),
    drumsHeavy:  (kick: 1.3, hat: 1.2, snare: 1.2, clap: 1.1,
                  perc: 1.1, acid: 0.7, melody: 0.5, harmony: 0.4),
    melodicLead: (kick: 0.7, hat: 0.6, snare: 0.6, clap: 0.5,
                  perc: 0.5, acid: 0.6, melody: 1.5, harmony: 1.1),
    acidFocus:   (kick: 0.8, hat: 0.6, snare: 0.5, clap: 0.4,
                  perc: 0.4, acid: 1.5, melody: 0.5, harmony: 0.3),
    bassFocus:   (kick: 1.3, hat: 0.5, snare: 0.6, clap: 0.4,
                  perc: 0.4, acid: 1.3, melody: 1.1, harmony: 0.5),
    breakdown:   (kick: 0.0, hat: 0.0, snare: 0.0, clap: 0.0,
                  perc: 0.3, acid: 0.6, melody: 1.1, harmony: 1.0),
    buildup:     (kick: 0.4, hat: 0.7, snare: 0.5, clap: 0.5,
                  perc: 0.6, acid: 0.9, melody: 1.0, harmony: 0.8),
    drop:        (kick: 1.2, hat: 1.1, snare: 1.1, clap: 1.1,
                  perc: 1.0, acid: 1.0, melody: 1.0, harmony: 0.9),
    dub:         (kick: 1.3, hat: 1.0, snare: 0.5, clap: 0.6,
                  perc: 1.2, acid: 0.7, melody: 1.4, harmony: 0.6),
    trance:      (kick: 1.2, hat: 1.2, snare: 0.8, clap: 1.2,
                  perc: 0.7, acid: 0.6, melody: 1.4, harmony: 1.0),
    detroit:     (kick: 1.0, hat: 0.9, snare: 0.9, clap: 0.8,
                  perc: 0.8, acid: 1.0, melody: 1.0, harmony: 0.9),
    hardcore:    (kick: 1.5, hat: 1.0, snare: 1.4, clap: 1.0,
                  perc: 0.9, acid: 1.1, melody: 0.5, harmony: 0.3),
);

~mixPreset = { |name|
    var p = ~mixPresets[name];
    if (p.isNil) {
        ("!! preset inconnu : " ++ name ++
         " -- dispos : " ++ ~mixPresets.keys.asArray).postln;
    } {
        ~mixVoices.do { |v| ~mix[v] = p[v] ? 1 };
        ~mixMuted.clear;
        ~mixSoloed.clear;
        ~mixApply.value;
        ("[preset] " ++ name).postln;
    };
};


// --- 7. Save / recall des balances ----------------------------------
~saveMix = { |name|
    var snap = ();
    ~mixVoices.do { |v| snap[v] = ~mix[v] ? 1 };
    ~mixesSaved[name] = snap;
    ("[mix saved] " ++ name).postln;
};

~loadMix = { |name|
    var snap = ~mixesSaved[name];
    if (snap.isNil) {
        ("!! mix '" ++ name ++ "' inexistant. Dispos : " ++
            ~mixesSaved.keys.asArray).postln;
    } {
        ~mixVoices.do { |v| ~mix[v] = snap[v] ? 1 };
        ~mixMuted.clear;
        ~mixSoloed.clear;
        ~mixApply.value;
        ("[mix loaded] " ++ name).postln;
    };
};

~listMixes = {
    "=== MIXES sauvegardes ===".postln;
    if (~mixesSaved.size == 0) {
        "  (aucun)".postln;
    } {
        ~mixesSaved.keysValuesDo { |k, v|
            ("  " ++ k).postln;
        };
    };
    ~mixesSaved.keys.asArray;
};

~deleteMix = { |name|
    if (~mixesSaved.includesKey(name)) {
        ~mixesSaved.removeAt(name);
        ("[mix deleted] " ++ name).postln;
    } { ("mix '" ++ name ++ "' inexistant").postln };
};


// --- 8. Helpers de balance live -------------------------------------
// Crossfade entre 2 voies sur dur secondes
~xfade = { |voieA, voieB, dur = 4|
    var key = (voieA.asString ++ "_" ++ voieB.asString).asSymbol;
    ~mixFadeRout[key] !? { ~mixFadeRout[key].stop };
    ~mixFadeRout[key] = Routine({
        var steps = (dur * 30).max(2).asInteger;
        var startA = ~mix[voieA] ? 1;
        var startB = ~mix[voieB] ? 1;
        var targetA = 0;
        var targetB = if (startB > 0) { startB } { 1 };
        steps.do { |i|
            var t = (i + 1) / steps;
            ~mix[voieA] = startA.blend(targetA, t);
            ~mix[voieB] = startB.blend(targetB, t);
            ~mixApply.value;
            (dur / steps).wait;
        };
        ("[xfade] " ++ voieA ++ " -> " ++ voieB).postln;
    }).play;
};

// Fade smooth d'une voie vers une cible
~fadeVol = { |voie, target = 1, dur = 2|
    if (~mixVoices.includes(voie).not) {
        ("!! voie inconnue : " ++ voie).postln;
    } {
        ~mixFadeRout[voie] !? { ~mixFadeRout[voie].stop };
        ~mixFadeRout[voie] = Routine({
            var steps = (dur * 30).max(2).asInteger;
            var start = ~mix[voie] ? 1;
            steps.do { |i|
                var t = (i + 1) / steps;
                ~mix[voie] = start.blend(target, t);
                ~mixApply.value;
                (dur / steps).wait;
            };
            ("[fade] " ++ voie ++ " -> " ++ target.round(0.01)).postln;
        }).play;
    };
};

// Echange instantane de 2 voies
~swapVol = { |voieA, voieB|
    var tmp = ~mix[voieA] ? 1;
    ~mix[voieA] = ~mix[voieB] ? 1;
    ~mix[voieB] = tmp;
    ~mixApply.value;
    ("[swap] " ++ voieA ++ " <-> " ++ voieB).postln;
};

// Focus : boost une voie, baisse les autres a "others"
~focus = { |voie, others = 0.3|
    if (~mixVoices.includes(voie).not) {
        ("!! voie inconnue : " ++ voie).postln;
    } {
        // snapshot avant focus
        ~mixFocusBak = ();
        ~mixVoices.do { |v| ~mixFocusBak[v] = ~mix[v] ? 1 };
        ~mixVoices.do { |v|
            ~mix[v] = if (v == voie) { 1.0 } { others };
        };
        ~mixApply.value;
        ("[focus] " ++ voie ++ " (others=" ++ others ++ ")").postln;
    };
};

~unfocus = {
    if (~mixFocusBak.isNil) {
        "[unfocus] aucun focus actif".postln;
    } {
        ~mixFocusBak.keysValuesDo { |v, val| ~mix[v] = val };
        ~mixFocusBak = nil;
        ~mixApply.value;
        "[unfocus]".postln;
    };
};


// --- 9. Affichage / debug -------------------------------------------
// Bargraph ASCII (12 cells, max coef = 1.5 pour la visu)
~mixShow = {
    var max = 1.5;
    var cells = 12;
    "=== MIXER ===".postln;
    ~mixVoices.do { |v|
        var coef = ~mix[v] ? 1;
        var filled = ((coef / max) * cells).round.asInteger.clip(0, cells);
        var empty = cells - filled;
        var bar = String.fill(filled, $|) ++ String.fill(empty, $.);
        var lbl = (v.asString ++ "       ").copyRange(0, 7);
        var muted = if (~mixMuted.includesKey(v)) { " [MUTED]" } { "" };
        var soloed = if (~mixSoloed.size > 0 and: { coef > 0 }) {
            " [SOLO]"
        } { "" };
        // remplace les pipes pour rendre visuel : utilise des chars block
        bar = bar.replace("|", "#");
        (" " ++ lbl ++ "|" ++ bar ++ "  " ++
            coef.round(0.01).asString ++ muted ++ soloed).postln;
    };
    "=============".postln;
};

// Info compacte une ligne
~mixInfo = {
    var s = "[mix] ";
    ~mixVoices.do { |v|
        s = s ++ v.asString ++ ":" ++ (~mix[v] ? 1).round(0.01).asString ++ " ";
    };
    s.postln;
};


// --- 10. Limiter / clip warning -------------------------------------
// Calcul approximatif : somme des coef * amp_ref par voie
// Si > seuil -> warn (le master limiter sauvera, mais le mix est sale)
~mixClipWarn = { |seuil = 1.2|
    var sum = 0;
    ~mixVoices.do { |v|
        var refV = ~mixRef[v] ? 0;
        var coef = ~mix[v] ? 1;
        sum = sum + (refV * coef);
    };
    if (sum > seuil) {
        ("!! [clip warn] somme amps = " ++ sum.round(0.01) ++
         " > seuil " ++ seuil ++ " -- risque de pompage limiter").postln;
    } {
        ("[ok] somme amps = " ++ sum.round(0.01) ++
         " (seuil " ++ seuil ++ ")").postln;
    };
    sum;
};


"=== mixer pret -- ~setVol ~mute ~solo ~mixPreset ~mixShow ===".postln;
)


// =====================================================================
//  EXEMPLES D'USAGE -- Cmd+Entree sur un bloc pour l'executer
//  PREREQUIS : avoir evalue le bloc SETUP en tete de fichier d'abord
// =====================================================================

// --- Faders simples --------------------------------------------------

// Baisse kick a 70%
( ~setVol.(\kick, 0.7); )

// Boost acid a 130%
( ~setVol.(\acid, 1.3); )

// Baisse melody a 40%
( ~setVol.(\melody, 0.4); )

// Lit le coef courant d'une voie
( ~getVol.(\kick); )

// Reset tous les coefs a 1
( ~mixReset.(); )


// --- Mute / unmute ---------------------------------------------------

// Mute hat
( ~mute.(\hat); )

// Unmute hat
( ~unmute.(\hat); )

// Toggle mute acid
( ~muteToggle.(\acid); )

// Mute toutes les voies
( ~muteAll.(); )

// Unmute toutes les voies
( ~unmuteAll.(); )

// Liste les voies mutees
( ~mutedList.(); )


// --- Solo ------------------------------------------------------------

// Solo acid (tout sauf acid -> mute)
( ~solo.(\acid); )

// Restore l'etat avant solo
( ~unsolo.(); )


// --- Master volume / fades -------------------------------------------

// Baisse global x0.5
( ~masterVol.(0.5); )

// Fade tous les coefs vers 0 en 8s
( ~masterFade.(0, 8); )

// Fade-in 4s depuis silence
( ~masterFadeIn.(4); )

// Fade-out 6s puis stop des Pdef
( ~masterFadeOut.(6); )

// Duck momentane (drop) : depth=0.3, attack=0.05s, release=0.5s
( ~masterDuck.(0.3, 0.05, 0.5); )


// --- Presets de balance ----------------------------------------------

// Tous coefs = 1
( ~mixPreset.(\flat); )

// Drums devant
( ~mixPreset.(\drumsHeavy); )

// Melody devant
( ~mixPreset.(\melodicLead); )

// Acid devant
( ~mixPreset.(\acidFocus); )

// Kick + acid devant
( ~mixPreset.(\bassFocus); )

// Drums coupes (breakdown)
( ~mixPreset.(\breakdown); )

// Buildup
( ~mixPreset.(\buildup); )

// Drop
( ~mixPreset.(\drop); )

// Dub
( ~mixPreset.(\dub); )

// Trance
( ~mixPreset.(\trance); )

// Detroit
( ~mixPreset.(\detroit); )

// Hardcore
( ~mixPreset.(\hardcore); )


// --- Save / recall des balances --------------------------------------

// Sauvegarde la balance courante sous \verseA
( ~saveMix.(\verseA); )

// Sauvegarde sous \drop1
( ~saveMix.(\drop1); )

// Recharge \verseA
( ~loadMix.(\verseA); )

// Liste les mixes sauvegardes
( ~listMixes.(); )

// Supprime un mix sauvegarde
( ~deleteMix.(\verseA); )


// --- Helpers live ----------------------------------------------------

// Crossfade acid -> melody en 4s
( ~xfade.(\acid, \melody, 4); )

// Fade kick vers 0.3 en 2s
( ~fadeVol.(\kick, 0.3, 2); )

// Echange instantane des coefs acid <-> melody
( ~swapVol.(\acid, \melody); )

// Focus acid (devant), autres voies a 0.2
( ~focus.(\acid, 0.2); )

// Restore l'etat avant focus
( ~unfocus.(); )


// --- Affichage / debug -----------------------------------------------

// Bargraph ASCII de tous les coefs
( ~mixShow.(); )

// Info compacte une ligne
( ~mixInfo.(); )

// Alerte si la somme des amps depasse le seuil (1.2 par defaut)
( ~mixClipWarn.(); )


// --- Rebase reference (apres changement de kit moteur) ---------------

// Re-capture les ~xxxAmp courants comme nouvelle reference
( ~mixRebase.(); )


// =====================================================================
//  WORKFLOW LIVE PERFORMANCE COMPLET (sequence d'exemples chainables)
// =====================================================================

// 1. Demarrage en silence puis montee
( ~mixPreset.(\breakdown); ~masterFadeIn.(8); )

// 2. Verse calme (melody devant) + sauvegarde
( ~mixPreset.(\melodicLead); ~saveMix.(\verseA); )

// 3. Buildup progressif
( ~mixPreset.(\buildup); ~fadeVol.(\hat, 1.2, 4); )

// 4a. DROP : duck preparatoire
( ~masterDuck.(0.3, 0.1, 0.5); )

// 4b. DROP : preset drop + sauvegarde
( ~mixPreset.(\drop); ~saveMix.(\drop1); )

// 5a. Section acid solo : focus
( ~focus.(\acid, 0.25); )

// 5b. ... 16 mesures plus tard : unfocus
( ~unfocus.(); )

// 6. Breakdown ambient
( ~mixPreset.(\breakdown); )

// 7. Retour drop final
( ~loadMix.(\drop1); )

// 8. Fade-out final
( ~masterFadeOut.(12); )
