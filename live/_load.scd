// =====================================================================
//  live/_load.scd  --  CHARGEMENT COMPLET LIVE en un Cmd+Entree
//
//  IDEMPOTENT : detecte si le bootstrap a deja tourne (via ~setupAll_done)
//  et ne refait pas le travail inutilement.
//
//  Fait :
//    1. Set ~base si nil
//    2. Si pas deja boote : charge engine + synthdefs + scales + melodies
//       + harmonics + setup.scd, puis ~setupAll.()
//       (~setupAll charge fx_bus / live / mixer / scenes / loops / fills /
//        sequences / jump + les 5 wrappers ~kk/~mm/~ff/~cc/~p)
//    3. Polling sur ~kk (defini en DERNIER par liveSetup async) pour
//       confirmer que tout est charge
//    4. Ouvre les fichiers essentiels dans l'editeur SC
//    5. Affiche "=== LIVE READY ==="
//
//  Utilisation :
//    (~base ++ "live/_load.scd").load;
//      OU
//    "/Users/electron/Documents/Projets_Creatifs/sound_algo/live/_load.scd".load;
// =====================================================================
(
~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };

Routine({
    var maxWait = 30, waited = 0;

    if (~setupAll_done == true and: { ~kk.notNil }) {
        "[live/_load] bootstrap deja fait, skip".postln;
    } {
        // --- 1. Modules .load-compatibles -------------------------------
        "[live/_load] engine + synthdefs + palette ...".postln;
        (~base ++ "engine.scd").load;
        (~base ++ "synthdefs/asia.scd").load;
        (~base ++ "synthdefs/extra.scd").load;
        (~base ++ "synthdefs/authentic.scd").load;
        (~base ++ "palette/scales.scd").load;
        (~base ++ "palette/melodies/index.scd").load;
        (~base ++ "palette/harmonics/index.scd").load;

        // --- 2. setup.scd : definit ~check / ~setupAll / ~teardown -----
        "[live/_load] setup.scd ...".postln;
        (~base ++ "setup.scd").load;

        // --- 3. ~setupAll : boot serveur + charge tous modules live + --
        //   les 5 wrappers (~kk / ~mm / ~ff / ~cc / ~p)
        //   liveSetup tourne dans s.waitForBoot{}, donc async.
        "[live/_load] ~setupAll (boot + modules live + wrappers) ...".postln;
        ~setupAll.();

        // --- 4. Polling : ~kk est defini en DERNIER par liveSetup ------
        //   (apres tous les autres modules + apres ~loadFirstBlock kicks).
        //   Quand ~kk est non-nil, liveSetup a TOUT charge.
        while { ~kk.isNil and: { waited < maxWait } } {
            0.2.wait;
            waited = waited + 0.2;
        };
        if (~kk.isNil) {
            ("[live/_load] !! timeout " ++ maxWait
                ++ "s sur ~kk. liveSetup a peut-etre echoue.").postln;
        } {
            ~setupAll_done = true;
        };
    };

    if (s.serverRunning) { s.sync };

    // --- 5. Ouvrir les fichiers essentiels dans l'editeur SC ------------
    //   Document.open est IDE-only (ScIDE classique). En sclang CLI ou
    //   dans certaines extensions VSCode, la classe Document n'existe
    //   pas -> on skip silencieusement avec try{}.
    // Ouvrir les fichiers essentiels dans l'editeur SC -- si Document
    // est dispo. La classe Document n'existe pas en sclang CLI ni dans
    // certaines extensions VSCode (pas de Qt charge) -> on skip.
    {
        var docClass = \Document.asClass;
        if (docClass.notNil) {
            "[live/_load] ouverture des fichiers essentiels dans l'IDE ...".postln;
            [
                "01_live.scd",                  // tableau de bord live
                "live/kicks.scd",               // ~kk
                "live/melodies.scd",            // ~mm
                "live/fx.scd",                  // ~ff
                "live/chains.scd",              // ~cc
                "live/patterns.scd",            // ~p
                "live/live_fx_panel.scd",       // panneau FX exhaustif
                "live/mixer.scd",               // ~setVol / ~mixPreset
                "live/scenes.scd",              // ~saveScene / ~loadScene
                "live/tweaks.scd",              // tweaks Cmd+Entree par bloc
                "control/jump.scd",             // ~jumpTo
                "palette/rhythm/fills.scd",     // ~snareFill / ~tomFill
            ].do { |path|
                var full = ~base ++ path;
                if (File.exists(full)) {
                    try { docClass.perform(\open, full) } { |err|
                        ("  [skip Document.open] " ++ path).postln;
                    };
                } { ("  [skip] " ++ path ++ " inexistant").postln };
            };
        } {
            "[live/_load] Document indisponible (sclang CLI ou VSCode sans IDE) -- skip ouverture".postln;
        };
    }.value;

    "".postln;
    "=== LIVE READY ===".postln;
    "  Wrappers : ~kk(kicks) ~mm(melodies) ~ff(fx) ~cc(chains) ~p(patterns)".postln;
    "  Mixer    : ~setVol ~mute ~solo ~mixPreset ~masterVol".postln;
    "  Live     : ~lfoTo ~vcfOn ~drop ~breakdown ~buildup".postln;
    "  Scenes   : ~saveScene ~loadScene ~listScenes".postln;
    "  Jump     : ~jumpTo.(\\X, \\section_slug)".postln;
    "  Status   : ~check.()".postln;
    "  Stop     : ~teardown.()".postln;
    "  -> ouvre 01_live.scd pour les blocs Cmd+Entree prets a l'emploi".postln;
}).play(AppClock);
)
