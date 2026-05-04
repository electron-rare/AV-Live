// =====================================================================
//  setup.scd  --  Verification d'etat + init complete du projet
//
//  USAGE PRINCIPAL (workflow recommande) :
//    Tout est fait depuis 00_load.scd > bloc "CHARGER TOUT". Ce fichier
//    est charge automatiquement par le loader, qui appelle ~setupAll.()
//    a la fin. Tu n'as PAS besoin de l'ouvrir manuellement en general.
//
//  USAGE MANUEL (debug ou redemarrage rapide) :
//    Ouvre ce fichier dans l'IDE puis Cmd+Entree sur un bloc :
//      ( ~check.() )       -- rapport d'etat colore
//      ( ~setupAll.() )    -- recharge TOUT (engine + live + ...)
//      ( ~setupLive.() )   -- recharge UNIQUEMENT live/* (rapide)
//      ( ~ensureLive.() )  -- charge ce qui manque seulement
//      ( ~teardown.() )    -- stop tout proprement
//
//  HELPERS EXPOSES (tous definis dans le 1er bloc -- .load-compatible) :
//    ~check                  status global colore
//    ~setupAll               charge engine + synthdefs + scales + melodies
//                            + harmonics + boot serveur + setup live + check
//    ~setupLive              recharge UNIQUEMENT les modules live (rapide)
//    ~ensureLive             charge live/* paresseusement (seulement absents)
//    ~teardown               stop tout proprement
//    ~loadFirstBlock(path)   helper interne -- evalue le 1er bloc d'un .scd
//
//  STRUCTURE
//    Le 1er bloc top-level contient TOUS les helpers : c'est le SETUP
//    HELPERS, evaluable via .load setup.scd (ce que fait CHARGER TOUT).
//    Les blocs suivants sont des exemples Cmd+Entree (pas charges par
//    .load, evaluables manuellement dans l'IDE).
// =====================================================================


// =====================================================================
//  SETUP HELPERS (1er bloc top-level -- .load-compatible)
//
//  Definit ~base, ~loadFirstBlock, ~check, ~setupAll, ~setupLive,
//  ~ensureLive, ~teardown. Ce bloc est execute par .load setup.scd
//  depuis le bloc CHARGER TOUT de 00_load.scd.
// =====================================================================
(
// --- BASE PATH (auto-detection si pas deja defini) -------------------
~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };
"~base = ".post; ~base.postln;


// --- HELPER : ~loadFirstBlock ---------------------------------------
//   Lit un fichier .scd et evalue son PREMIER bloc top-level (...) en
//   comptant les parens balancees. Sert pour les fichiers multi-blocs
//   dont seul le 1er bloc est le SETUP a evaluer (live/*, jump.scd, ...).
//
//   Robuste : try/protect pour qu'une erreur d'un fichier n'arrete pas
//   les autres. Print clair de chaque etape ([setupAll] ... OK / FAIL).
// --------------------------------------------------------------------
~loadFirstBlock = { |path|
    var src, depth = 0, start = nil, firstBlock = nil;
    var label = path.basename;
    var i = 0, n, ch, ch2;
    var inLineComment = false, inBlockComment = false, inString = false;
    if (File.exists(path).not) {
        ("[setupAll] " ++ label ++ " ... FAIL (fichier introuvable)").postln;
    } {
        src = File.readAllString(path);
        n = src.size;
        block { |break|
            while { i < n } {
                ch = src[i];
                ch2 = if (i + 1 < n) { src[i + 1] } { $  };
                // ----- gestion des etats -----
                if (inLineComment) {
                    if (ch == $\n) { inLineComment = false };
                    i = i + 1;
                } {
                if (inBlockComment) {
                    if ((ch == $*) and: { ch2 == $/ }) { inBlockComment = false; i = i + 2 }
                    { i = i + 1 };
                } {
                if (inString) {
                    if (ch == $\\) { i = i + 2 }       // skip escape
                    { if (ch == $") { inString = false; i = i + 1 } { i = i + 1 } };
                } {
                    // ----- pas dans un comment / string -----
                    // entree commentaire ligne
                    if ((ch == $/) and: { ch2 == $/ }) { inLineComment = true; i = i + 2 }
                    // entree commentaire bloc
                    { if ((ch == $/) and: { ch2 == $* }) { inBlockComment = true; i = i + 2 }
                    // char literal SC : $( ou $) ou $" -- on saute le caractere suivant
                    { if ((ch == $$) and: { (ch2 == $() or: { (ch2 == $)) or: { ch2 == $" } } }) { i = i + 2 }
                    // entree string
                    { if (ch == $") { inString = true; i = i + 1 }
                    // parens REELLES
                    { if (ch == $() {
                        if (depth == 0) { start = i };
                        depth = depth + 1;
                        i = i + 1;
                    } { if (ch == $)) {
                        depth = depth - 1;
                        if ((depth == 0) and: { start.notNil }) {
                            firstBlock = src.copyRange(start, i);
                            break.value;
                        };
                        i = i + 1;
                    } { i = i + 1 } } } } } };
                } } };
            };
        };
        if (firstBlock.isNil) {
            ("[setupAll] " ++ label ++ " ... FAIL (aucun bloc trouve)").postln;
        } {
            ("[setupAll] " ++ label ++ " ... loading [" ++ firstBlock.size ++ " chars]").post;
            try {
                firstBlock.interpret;
                "  OK".postln;
            } { |err|
                "  FAIL".postln;
                ("    " ++ err.errorString).postln;
            };
        };
    };
};


// --- HELPER : ~loadAllBlocks ----------------------------------------
//   Comme ~loadFirstBlock mais charge TOUS les blocs top-level d'un
//   fichier. Utile pour fichiers comme sequences.scd qui ont leurs
//   helpers en bloc 1 puis ~seqIntro/Buildup/Drop en blocs separes.
//   Ignore comments / strings / char literals.
// --------------------------------------------------------------------
~loadAllBlocks = { |path|
    var src, depth = 0, start = nil, blocks = List.new;
    var label = path.basename;
    var i = 0, n, ch, ch2;
    var inLineComment = false, inBlockComment = false, inString = false;
    if (File.exists(path).not) {
        ("[setupAll] " ++ label ++ " ... FAIL (fichier introuvable)").postln;
    } {
        src = File.readAllString(path);
        n = src.size;
        while { i < n } {
            ch = src[i];
            ch2 = if (i + 1 < n) { src[i + 1] } { $  };
            if (inLineComment) {
                if (ch == $\n) { inLineComment = false }; i = i + 1;
            } {
            if (inBlockComment) {
                if ((ch == $*) and: { ch2 == $/ }) { inBlockComment = false; i = i + 2 } { i = i + 1 };
            } {
            if (inString) {
                if (ch == $\\) { i = i + 2 } { if (ch == $") { inString = false; i = i + 1 } { i = i + 1 } };
            } {
                if ((ch == $/) and: { ch2 == $/ }) { inLineComment = true; i = i + 2 }
                { if ((ch == $/) and: { ch2 == $* }) { inBlockComment = true; i = i + 2 }
                { if ((ch == $$) and: { (ch2 == $() or: { (ch2 == $)) or: { ch2 == $" } } }) { i = i + 2 }
                { if (ch == $") { inString = true; i = i + 1 }
                { if (ch == $() {
                    if (depth == 0) { start = i };
                    depth = depth + 1; i = i + 1;
                } { if (ch == $)) {
                    depth = depth - 1;
                    if ((depth == 0) and: { start.notNil }) {
                        blocks.add(src.copyRange(start, i));
                        start = nil;
                    };
                    i = i + 1;
                } { i = i + 1 } } } } } };
            } } };
        };
        ("[setupAll] " ++ label ++ " ... " ++ blocks.size ++ " blocs ").post;
        try {
            blocks.do { |b| b.interpret };
            "  OK".postln;
        } { |err|
            "  FAIL".postln;
            ("    " ++ err.errorString).postln;
        };
    };
};


// --- HELPER : ~check ------------------------------------------------
//   Affiche un rapport coloree (postln) listant l'etat de chaque
//   module. Utilise des prefixes ASCII :
//     [OK] = tout est la
//     [!!] = certains helpers manquent (action recommandee)
//     [--] = pas initialise (optionnel : MIDI, jump)
// --------------------------------------------------------------------
~check = {
    var sd = SynthDescLib.global.synthDescs;
    var hasSd = { |sym| sd[sym].notNil };
    var hasV  = { |sym| currentEnvironment[sym].notNil };
    var allSd = { |list| list.every { |s| hasSd.(s) } };
    var allV  = { |list| list.every { |s| hasV.(s) } };
    var missingSd = { |list| list.select { |s| hasSd.(s).not } };
    var missingV  = { |list| list.select { |s| hasV.(s).not } };
    var actions = List.new;
    var line = { |label, status, msg|
        ("[" ++ label ++ "]").padRight(13).post;
        status.post; "  ".post; msg.postln;
    };

    "".postln;
    "=== sound_algo STATUS ===".postln;

    // ----- Server -----
    if (s.serverRunning) {
        ("[server]     running, " ++ s.numSynths ++ " synths, "
            ++ s.avgCPU.round(0.1) ++ "% CPU").postln;
    } {
        "[server]     [--]  pas demarre  (lance ~setupAll ou s.boot)".postln;
        actions.add("Lance ~setupAll.() pour booter le serveur");
    };

    // ----- engine.scd -----
    block { |b|
        var engineSd = [\kick, \hat, \snare, \clap, \acid, \lead, \pad, \pluck,
                        \fmBell, \stab, \saw3, \openHat, \crash, \tom, \rim,
                        \cowbell, \reese, \bass808, \impact, \riser, \sweep,
                        \vinyl, \masterLim];
        var engineHelpers = [\reload, \bpm, \kickAmp, \melodyAmp, \melodyNotes,
                             \kickSteps, \scBus, \masterLim];
        var miss = missingSd.(engineSd) ++ missingV.(engineHelpers);
        if (miss.isEmpty) {
            line.("engine", "[OK]", engineSd.size.asString
                ++ " SynthDefs + ~reload + ~scBus + ~masterLim");
        } {
            line.("engine", "[!!]", "manquant : " ++ miss);
            actions.add("CHARGER TOUT depuis 00_load.scd (engine + synthdefs + scales + melodies + harmonics)");
        };
    };

    // ----- synthdefs/asia.scd -----
    block { |b|
        var asia = [\koto, \erhu, \pipa, \gong, \growl, \reeseHard];
        var miss = missingSd.(asia);
        if (miss.isEmpty) { line.("asia", "[OK]", asia.size.asString ++ " SynthDefs"); }
        { line.("asia", "[!!]", "manquant : " ++ miss); };
    };

    // ----- synthdefs/extra.scd -----
    block { |b|
        var extra = [\squareLead, \fmLead, \organLead, \hardLead, \warmPad,
                     \strings, \choir, \fmBass, \subBoom, \handpan, \flute, \drone];
        var miss = missingSd.(extra);
        if (miss.isEmpty) { line.("extra", "[OK]", extra.size.asString ++ " SynthDefs"); }
        { line.("extra", "[!!]", "manquant : " ++ miss); };
    };

    // ----- synthdefs/authentic.scd -----
    block { |b|
        var auth = [\kickGabber, \kick808, \snareGated, \reeseDnB, \supersaw,
                    \hooverbass, \rhodes, \vocalPad, \didgeridoo, \guzheng,
                    \shakuhachi, \taiko, \tabla, \scratch];
        var miss = missingSd.(auth);
        if (miss.isEmpty) { line.("authentic", "[OK]", auth.size.asString ++ " SynthDefs"); }
        { line.("authentic", "[!!]", "manquant : " ++ miss); };
    };

    // ----- palette/scales.scd -----
    block { |b|
        var scales = [\scaleMinor, \scaleDorian, \scaleMinorPent, \scaleAcid,
                      \scaleHijaz, \scaleVietnam];
        var helpers = [\genMelody, \mutate, \octavate, \transpose, \retrograde,
                       \densify, \sparsify, \jitter, \genAcidNotes, \genKickPattern,
                       \randomTweak];
        var miss = missingV.(scales) ++ missingV.(helpers);
        if (miss.isEmpty) {
            line.("scales", "[OK]", "16 scales + ~genMelody/mutate/octavate/...");
        } {
            line.("scales", "[!!]", "manquant : " ++ miss);
            actions.add("CHARGER TOUT (scales = source unique helpers melodiques)");
        };
    };

    // ----- palette/melodies/* -----
    block { |b|
        var probes = [\m1, \m78, \ml1, \ml30, \mxl1, \mxl15, \mepic1, \mepic10,
                      \melodyBank, \useMelody, \melodyByGenre, \chainPatterns, \buildArc];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("melodies", "[OK]",
                "~m1..78, ~ml1..30, ~mxl1..15, ~mepic1..10 + ~useMelody/byGenre");
        } {
            line.("melodies", "[!!]", "manquant : " ++ miss);
            actions.add("CHARGER TOUT (charge palette/melodies/index.scd)");
        };
    };

    // ----- palette/harmonics/* -----
    block { |b|
        var probes = [\enableHarmony, \genThirdHarmony, \genFifthHarmony,
                      \genCounterMelody, \genArpFromChords];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("harmonics", "[OK]", "~enableHarmony + 4 helpers");
        } {
            line.("harmonics", "[!!]", "manquant : " ++ miss);
            actions.add("CHARGER TOUT (charge palette/harmonics/index.scd)");
        };
    };

    // ----- palette/melodies/tracks.scd (multi-pistes) -----
    block { |b|
        var probes = [\mel, \melTrackAdd, \melTrackOn, \melTrackOff, \melTrackSet,
                      \melTrackList, \melTrackSolo];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("mel-track", "[OK]", "~mel + ~melTrackAdd/On/Off/Set/...");
        } {
            line.("mel-track", "[!!]", "manquant : " ++ miss);
        };
    };

    // ----- live API wrappers (~kk / ~mm / ~ff / ~cc / ~p) -----
    //   Ces wrappers (live/_load.scd) remplacent fonctionnellement les
    //   ~kK1, ~clC1, ~pcP1 des palette/rhythm/* (qui sont multi-blocs).
    block { |b|
        var probes = [\kk, \kPat, \kTim, \kList,
                      \mm, \mShort, \mLong, \mEpic, \mGen, \mList,
                      \ff, \fxSnd, \fxSt, \fxDrop, \fxList,
                      \chIntro, \chDrop, \chBuildup, \chList,
                      \pKit, \pGenre, \pHat, \pList];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("live-api", "[OK]", "~kk ~mm ~ff ~chIntro ~pKit + 19 wrappers");
        } {
            line.("live-api", "[!!]", "manquant : " ++ miss);
            actions.add("Lance (~base++\"live/_load.scd\").load (charge les 5 wrappers live)");
        };
    };

    // ----- palette/rhythm/fills.scd (~snareFill / ~tomFill) -----
    block { |b|
        var probes = [\snareFill, \tomFill];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("fills", "[OK]", "~snareFill / ~tomFill");
        } {
            line.("fills", "[!!]", "~snareFill et/ou ~tomFill manquent");
            actions.add("Lance ~setupAll.() (charge palette/rhythm/fills.scd)");
        };
    };

    // ----- palette/rhythm/sequences.scd (~seqPlay / ~seqIntro / ...) -----
    block { |b|
        var probes = [\seqPlay, \seqStop, \seqIntro, \seqBuildup, \seqDrop];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("sequences", "[OK]", "~seqPlay / ~seqIntro / ~seqBuildup / ~seqDrop / ...");
        } {
            line.("sequences", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge palette/rhythm/sequences.scd)");
        };
    };

    // ----- palette/chords_progressions.scd -----
    block { |b|
        var probes = [\progDetroit, \progTrance, \progDnB, \chordsToMelody];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("chords", "[OK]", "~progXxx + ~chordsToMelody/Harmony");
        } {
            line.("chords", "[--]", "non charge (optionnel) : " ++ miss);
        };
    };

    // ----- live/live.scd -----
    block { |b|
        var probes = [\lfoTo, \vcfOn, \drop, \breakdown, \stutter, \glitch,
                      \freeze, \addFx, \compOn, \satOn];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("live", "[OK]", "~lfoTo / ~vcfOn / ~drop / ~stutter / ~addFx / ~compOn / ...");
        } {
            line.("live", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge live/live.scd)");
        };
    };

    // ----- live/mixer.scd -----
    block { |b|
        var probes = [\setVol, \mute, \solo, \mixPreset, \mixMaster, \mix];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("mixer", "[OK]", "~setVol / ~mute / ~solo / ~mixPreset / ~mixMaster");
        } {
            line.("mixer", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge live/mixer.scd)");
        };
    };

    // ----- live/fx_bus.scd -----
    block { |b|
        var probes = [\fxFx, \fxBuses, \send, \setFx, \lfo, \fxPreset, \tap];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("fx_bus", "[OK]", "9 bus FX + ~send / ~setFx / ~lfo / ~fxPreset / ~tap");
        } {
            line.("fx_bus", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge live/fx_bus.scd EN PREMIER)");
        };
    };

    // ----- live/scenes.scd -----
    block { |b|
        var probes = [\saveScene, \loadScene, \listScenes];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("scenes", "[OK]", "~saveScene / ~loadScene / ~listScenes");
        } {
            line.("scenes", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge live/scenes.scd)");
        };
    };

    // ----- live/loops.scd -----
    block { |b|
        var probes = [\loopOn, \loopOff, \loopRepeat, \loopProgress, \loopList];
        var miss = missingV.(probes);
        if (miss.isEmpty) {
            line.("loops", "[OK]", "~loopOn / ~loopOff / ~loopRepeat / ~loopProgress");
        } {
            line.("loops", "[!!]", "manquant : " ++ miss);
            actions.add("Lance ~setupAll.() (charge live/loops.scd)");
        };
    };

    // ----- control/midi.scd (optionnel) -----
    block { |b|
        if (~midiFuncs.notNil and: { ~midiFuncs.size > 0 }) {
            line.("midi", "[OK]", "~midiFuncs (" ++ ~midiFuncs.size ++ " mappings)");
        } {
            line.("midi", "[--]", "pas init (optionnel) -- ouvre control/midi.scd");
        };
    };

    // ----- control/playlist.scd (optionnel) -----
    block { |b|
        if (hasV.(\playPlaylist)) {
            line.("playlist", "[OK]", "~playPlaylist pret");
        } {
            line.("playlist", "[--]", "pas charge (optionnel) -- ouvre control/playlist.scd");
        };
    };

    // ----- control/jump.scd -----
    block { |b|
        if (hasV.(\jumpTo) and: { hasV.(\sections) }) {
            var nbTracks = ~sections.size;
            line.("jump", "[OK]", "~jumpTo + ~sections (" ++ nbTracks ++ " tracks chargees)");
        } {
            line.("jump", "[!!]", "pas init");
            actions.add("Lance ~setupAll.() (charge control/jump.scd)");
        };
    };

    "=== fin status ===".postln;

    if (actions.size > 0) {
        "".postln;
        "ACTIONS RECOMMANDEES :".postln;
        actions.do { |a| ("  - " ++ a).postln };
    } {
        "".postln;
        "Tout est OK -- pret a jouer.".postln;
    };
    "".postln;
};


// --- HELPER : ~setupAll ---------------------------------------------
//   Charge engine + synthdefs + scales + melodies + harmonics, attend
//   le boot du serveur (skip si deja boote), puis evalue le 1er bloc
//   (SETUP) de chaque module live + rhythm/fills + rhythm/sequences +
//   control/jump. Termine par ~check.()
//
//   Print clair de chaque etape via ~loadFirstBlock (qui catche les
//   erreurs : un fichier qui plante n'arrete PAS les autres).
//
//   Ordre d'init des modules live :
//     1. fx_bus.scd            (alloue les bus FX, doit etre en PREMIER)
//     2. live.scd              (LFO/VCF/tricks/SynthDefs additionnels)
//     3. mixer.scd             (~mix / ~setVol / ~mute / ~solo)
//     4. scenes.scd            (~saveScene / ~loadScene)
//     5. loops.scd             (~loopOn / ~loopOff / ~loopRepeat)
//     6. rhythm/fills.scd      (~snareFill / ~tomFill)
//     7. rhythm/sequences.scd  (~seqPlay / ~seqIntro / ~seqDrop / ...)
//     8. control/jump.scd      (~jumpTo + ~sections)
//
//   PAS init automatiquement :
//     - control/midi.scd       (init MIDI -- a faire manuellement)
//     - control/playlist.scd   (juste un helper, charge a la demande)
//     - live/tweaks.scd        (one-liners, pas de SETUP)
// --------------------------------------------------------------------
~setupAll = {
    var liveSetup = {
        "".postln;
        "=== ~setupAll : init modules live ===".postln;

        // Ordre critique : fx_bus.scd EN PREMIER (alloue ~fxBuses / ~fxFx
        // que les autres modules peuvent referencer)
        ~loadFirstBlock.(~base ++ "live/fx_bus.scd");
        ~loadFirstBlock.(~base ++ "live/live.scd");
        ~loadFirstBlock.(~base ++ "live/mixer.scd");
        ~loadFirstBlock.(~base ++ "live/scenes.scd");
        ~loadFirstBlock.(~base ++ "live/loops.scd");
        ~loadFirstBlock.(~base ++ "palette/rhythm/fills.scd");
        ~loadAllBlocks.(~base ++ "palette/rhythm/sequences.scd");
        ~loadAllBlocks.(~base ++ "palette/chords_progressions.scd");
        ~loadFirstBlock.(~base ++ "control/jump.scd");

        // 5 wrappers API live (~kk / ~mm / ~ff / ~cc / ~p) -- 1er bloc
        // chacun contient les definitions ; les blocs suivants sont des
        // exemples interactifs Cmd+Entree qu'on ne veut PAS executer au boot.
        ~loadFirstBlock.(~base ++ "live/kicks.scd");
        ~loadFirstBlock.(~base ++ "live/melodies.scd");
        ~loadFirstBlock.(~base ++ "live/fx.scd");
        ~loadFirstBlock.(~base ++ "live/chains.scd");
        ~loadFirstBlock.(~base ++ "live/patterns.scd");

        s.sync;
        "".postln;
        "=== setupAll DONE ===".postln;
        "".postln;
        ~check.value;
    };

    "=== ~setupAll : start ===".postln;
    ~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };

    // --- 1. Charge tous les fichiers .load-compatibles ---
    "[setupAll] engine.scd ... loading".postln;
    (~base ++ "engine.scd").load;
    "[setupAll] synthdefs/asia.scd ... loading".postln;
    (~base ++ "synthdefs/asia.scd").load;
    "[setupAll] synthdefs/extra.scd ... loading".postln;
    (~base ++ "synthdefs/extra.scd").load;
    "[setupAll] synthdefs/authentic.scd ... loading".postln;
    (~base ++ "synthdefs/authentic.scd").load;
    "[setupAll] palette/scales.scd ... loading".postln;
    (~base ++ "palette/scales.scd").load;
    "[setupAll] palette/melodies/index.scd ... loading".postln;
    (~base ++ "palette/melodies/index.scd").load;
    "[setupAll] palette/harmonics/index.scd ... loading".postln;
    (~base ++ "palette/harmonics/index.scd").load;

    // --- 2. Boot serveur (skip si deja boote) puis init modules live ---
    if (s.serverRunning) {
        "=== ~setupAll : serveur deja boote, skip waitForBoot ===".postln;
        liveSetup.value;
    } {
        "=== ~setupAll : boot serveur en cours... ===".postln;
        s.waitForBoot {
            s.sync;
            "=== ~setupAll : boot OK ===".postln;
            liveSetup.value;
        };
    };
};


// --- HELPER : ~setupLive --------------------------------------------
//   Charge UNIQUEMENT les modules live (ne touche pas engine /
//   synthdefs / scales / melodies / harmonics). Pour redemarrage
//   rapide quand le serveur tourne deja avec engine charge.
// --------------------------------------------------------------------
~setupLive = {
    ~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };
    if (s.serverRunning.not) {
        "!! ~setupLive : serveur pas demarre. Lance ~setupAll a la place.".postln;
    } {
        "=== ~setupLive : init modules live seulement ===".postln;
        ~loadFirstBlock.(~base ++ "live/fx_bus.scd");
        ~loadFirstBlock.(~base ++ "live/live.scd");
        ~loadFirstBlock.(~base ++ "live/mixer.scd");
        ~loadFirstBlock.(~base ++ "live/scenes.scd");
        ~loadFirstBlock.(~base ++ "live/loops.scd");
        ~loadFirstBlock.(~base ++ "palette/rhythm/fills.scd");
        ~loadAllBlocks.(~base ++ "palette/rhythm/sequences.scd");
        ~loadAllBlocks.(~base ++ "palette/chords_progressions.scd");
        ~loadFirstBlock.(~base ++ "control/jump.scd");
        // 5 wrappers API live (~kk / ~mm / ~ff / ~cc / ~p)
        ~loadFirstBlock.(~base ++ "live/kicks.scd");
        ~loadFirstBlock.(~base ++ "live/melodies.scd");
        ~loadFirstBlock.(~base ++ "live/fx.scd");
        ~loadFirstBlock.(~base ++ "live/chains.scd");
        ~loadFirstBlock.(~base ++ "live/patterns.scd");
        "=== ~setupLive : OK ===".postln;
        ~check.value;
    };
};


// --- HELPER : ~ensureLive -------------------------------------------
//   Helper paresseux : detecte ce qui manque dans live/* + fills +
//   sequences + jump et charge SEULEMENT les modules absents.
//   Idempotent : peut etre appele plusieurs fois sans rien recharger.
// --------------------------------------------------------------------
~ensureLive = {
    var loaded = 0;
    ~base = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };
    if (s.serverRunning.not) {
        "!! ~ensureLive : serveur pas demarre. Lance ~setupAll d'abord.".postln;
    } {
        // fx_bus en premier (les autres modules peuvent en dependre)
        if (~fxFx.isNil or: { ~send.isNil }) {
            "ensure : fx_bus.scd".postln;
            ~loadFirstBlock.(~base ++ "live/fx_bus.scd");
            loaded = loaded + 1;
        };
        if (~lfoTo.isNil or: { ~vcfOn.isNil }) {
            "ensure : live.scd".postln;
            ~loadFirstBlock.(~base ++ "live/live.scd");
            loaded = loaded + 1;
        };
        if (~setVol.isNil or: { ~mixPreset.isNil }) {
            "ensure : mixer.scd".postln;
            ~loadFirstBlock.(~base ++ "live/mixer.scd");
            loaded = loaded + 1;
        };
        if (~saveScene.isNil) {
            "ensure : scenes.scd".postln;
            ~loadFirstBlock.(~base ++ "live/scenes.scd");
            loaded = loaded + 1;
        };
        if (~loopOn.isNil) {
            "ensure : loops.scd".postln;
            ~loadFirstBlock.(~base ++ "live/loops.scd");
            loaded = loaded + 1;
        };
        if (~snareFill.isNil or: { ~tomFill.isNil }) {
            "ensure : fills.scd".postln;
            ~loadFirstBlock.(~base ++ "palette/rhythm/fills.scd");
            loaded = loaded + 1;
        };
        if (~seqPlay.isNil or: { ~seqIntro.isNil }) {
            "ensure : sequences.scd".postln;
            ~loadAllBlocks.(~base ++ "palette/rhythm/sequences.scd");
            loaded = loaded + 1;
        };
        if (~jumpTo.isNil) {
            "ensure : jump.scd".postln;
            ~loadFirstBlock.(~base ++ "control/jump.scd");
            loaded = loaded + 1;
        };
        if (~progDetroit.isNil or: { ~chordsToMelody.isNil }) {
            "ensure : chords_progressions.scd".postln;
            ~loadAllBlocks.(~base ++ "palette/chords_progressions.scd");
            loaded = loaded + 1;
        };
        // 5 wrappers API live (chacun expose un dict + des wrappers env)
        if (~kk.isNil) {
            "ensure : live/kicks.scd".postln;
            ~loadFirstBlock.(~base ++ "live/kicks.scd");
            loaded = loaded + 1;
        };
        if (~mm.isNil) {
            "ensure : live/melodies.scd".postln;
            ~loadFirstBlock.(~base ++ "live/melodies.scd");
            loaded = loaded + 1;
        };
        if (~ff.isNil) {
            "ensure : live/fx.scd".postln;
            ~loadFirstBlock.(~base ++ "live/fx.scd");
            loaded = loaded + 1;
        };
        if (~cc.isNil) {
            "ensure : live/chains.scd".postln;
            ~loadFirstBlock.(~base ++ "live/chains.scd");
            loaded = loaded + 1;
        };
        if (~p.isNil) {
            "ensure : live/patterns.scd".postln;
            ~loadFirstBlock.(~base ++ "live/patterns.scd");
            loaded = loaded + 1;
        };
        if (loaded == 0) {
            "=== ~ensureLive : tout est deja la, rien a charger ===".postln;
        } {
            ("=== ~ensureLive : " ++ loaded ++ " module(s) charge(s) ===").postln;
        };
    };
};


// --- HELPER : ~teardown ---------------------------------------------
//   Stop tout proprement :
//     - ~track et autres routines
//     - tous les Pdef de l'engine
//     - LFO / VCF / loops / playlist / sequences
//     - libere ~masterLim et ~scBus
//     - libere les bus FX et synths FX si presents
// --------------------------------------------------------------------
~teardown = {
    "=== ~teardown : stop tout ===".postln;

    // Routines de track / sweep / loops engine
    ~track !? { ~track.stop; ~track = nil };
    ~filterSweep !? { ~filterSweep.stop; ~filterSweep = nil };
    ~randomLoop !? { ~randomLoop.stop; ~randomLoop = nil };
    ~melodyEvolve !? { ~melodyEvolve.stop; ~melodyEvolve = nil };
    ~lRotate !? { ~lRotate.stop; ~lRotate = nil };

    // Tous les Pdef
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };

    // LFO live (live.scd)
    ~lfoStopEverything !? { ~lfoStopEverything.value };

    // LFO fx_bus (fx_bus.scd)
    ~lfoStopAll !? { ~lfoStopAll.value };

    // VCF master
    ~vcfOff !? { ~vcfOff.value };

    // Loops live
    ~loopOffAll !? { ~loopOffAll.value };

    // Sequences (palette/rhythm/sequences.scd)
    ~seqStop !? { ~seqStop.value };

    // Auto-fx (autoPan / tremolo)
    ~stopAutoFx !? {
        [\kick, \hat, \snare, \clap, \perc, \acid, \melody, \harmony]
            .do { |v| ~stopAutoFx.(v) };
    };

    // Compresseur / saturation master
    ~compOff !? { ~compOff.value };
    ~satOff  !? { ~satOff.value };

    // Playlist
    ~playlist !? { ~playlist.stop; ~playlist = nil };

    // Free pdef tracks melodiques (multi-pistes)
    ~melTrackChoke !? { ~melTrackChoke.value };

    // Master limiter + sidechain bus
    ~masterLim !? { ~masterLim.free; ~masterLim = nil };
    ~scBus !? { ~scBus.free; ~scBus = nil };

    // Bus FX + synths FX
    ~fxFx !? {
        ~fxFx.do { |syn| syn !? { syn.free } };
        ~fxFx = nil;
    };
    ~fxBuses !? {
        ~fxBuses.do { |b| b !? { b.free } };
        ~fxBuses = nil;
    };

    "=== ~teardown OK ===".postln;
};

"~loadFirstBlock / ~check / ~setupAll / ~setupLive / ~ensureLive / ~teardown prets".postln;
)


// =====================================================================
//  BLOCS Cmd+Entree -- workflows manuels (executes a la demande)
//
//  IMPORTANT : ces blocs sont COMMENTES car .load echoue avec >1 bloc
//  top-level. Pour les utiliser : DECOMMENTE la ligne (retire les "//")
//  puis Cmd+Entree dessus dans l'IDE. Ou copie-colle le contenu.
// =====================================================================

// --- VERIF rapide de l'etat ----------
// ( ~check.(); )

// --- INIT COMPLETE (charge tout + boot + setup live + check) ---------
// ( ~setupAll.(); )

// --- INIT LIVE SEULEMENT (serveur deja boote) ------------------------
// ( ~setupLive.(); )

// --- INIT PARESSEUSE (charge ce qui manque seulement) ----------------
// ( ~ensureLive.(); )

// --- ARRET PROPRE ----------------------------------------------------
// ( ~teardown.(); )

// --- COMBO : check d'abord, puis setup auto si besoin ----------------
// ( ~check.(); ~setupAll.(); )

// --- COMBO : teardown puis re-setupAll (full restart sans rebooter) --
// ( ~teardown.(); ~setupAll.(); )
