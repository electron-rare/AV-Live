// =====================================================================
//  e2e_01_syntax.scd
//  Verifie que chaque .scd parse correctement.
//  Strategie : pour chaque fichier, on extrait les blocs top-level
//  (lignes commencant par '(' a la colonne 0) et on tente de compiler
//  chaque bloc independamment via String.compile.
//  Convention du projet : les blocs ouvrent par '(' col 0 et ferment
//  par ')' col 0 (multi-ligne) OU '( ... )' sur une seule ligne.
// =====================================================================

"=== e2e_01_syntax ===".postln;

~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
~testCount = 0;
~testFailed = 0;

~assert = { |label, cond, info|
    ~testCount = ~testCount + 1;
    if (cond) {
        ("  [OK] " ++ label).postln;
    } {
        ~testFailed = ~testFailed + 1;
        ("  [FAIL] " ++ label ++ if (info.notNil) { " : " ++ info } { "" }).postln;
    };
};

~report = {
    ("== " ++ ~testCount ++ " tests, " ++ ~testFailed ++ " failed ==").postln;
    if (~testFailed > 0) { 1.exit } { 0.exit };
};

// Extrait les blocs top-level d'un .scd selon la convention du projet :
//   - ligne qui commence par '(' = ouverture
//   - ligne qui se termine par ')' au col 0 (ou ligne single-line se
//     terminant par ')' qui equilibre les parens) = fermeture
~extractBlocks = { |src|
    var blocks = List.new;
    var lines = src.split($\n);
    var i = 0, j, startIdx, line, depth, balance;
    while { i < lines.size } {
        line = lines[i];
        // ligne commence par '(' (premier char) ?
        if ((line.size > 0) and: { line[0] == $( }) {
            startIdx = i;
            // calcule la balance de parens pour cette ligne
            // (compte brut sans tenir compte des chaines/commentaires ;
            //  c'est OK pour la convention du projet)
            balance = 0;
            line.do { |c|
                if (c == $( ) { balance = balance + 1 };
                if (c == $) ) { balance = balance - 1 };
            };
            if (balance == 0) {
                // bloc 1-ligne : '( ... )'
                blocks.add(line);
            } {
                // bloc multi-ligne : cherche la ligne suivante qui ramene
                // la balance a 0
                j = i + 1;
                while { (j < lines.size) and: { balance != 0 } } {
                    var l2 = lines[j];
                    l2.do { |c|
                        if (c == $( ) { balance = balance + 1 };
                        if (c == $) ) { balance = balance - 1 };
                    };
                    j = j + 1;
                };
                if (balance == 0) {
                    blocks.add(lines.copyRange(startIdx, j - 1).join($\n));
                    i = j - 1;
                } {
                    ("    [WARN] bloc unterminated ligne " ++ (startIdx + 1)).postln;
                    i = lines.size;
                };
            };
        };
        i = i + 1;
    };
    blocks;
};

// Si un bloc utilise une classe IDE-only (Document, etc.) il echouera
// en mode CLI sclang. On ignore ces blocs (warning seulement).
~ideOnlyKeywords = ["Document.open", "Document.current", "Document.dir"];

~isIdeOnlyBlock = { |src|
    ~ideOnlyKeywords.any { |kw| src.contains(kw) };
};

~compileFileSyntax = { |path|
    var src = File.readAllString(path);
    var blocks, nFail = 0, nIdeSkip = 0, idx = 0;
    if (src.isNil) { false } {
        // Tente d'abord compileFile (rapide pour single-block)
        var single;
        try { single = thisProcess.interpreter.compileFile(path) } { single = nil };
        if (single.notNil) {
            true
        } {
            blocks = ~extractBlocks.(src);
            if (blocks.size == 0) {
                false
            } {
                blocks.do { |b|
                    idx = idx + 1;
                    if (~isIdeOnlyBlock.(b)) {
                        nIdeSkip = nIdeSkip + 1;
                    } {
                        if (b.compile.isNil) {
                            nFail = nFail + 1;
                            ("    !! " ++ path.basename ++ " bloc#" ++ idx
                                ++ " parse FAIL").postln;
                        };
                    };
                };
                if (nIdeSkip > 0) {
                    ("    [INFO] " ++ path.basename ++ " : " ++ nIdeSkip
                        ++ " blocs IDE-only ignores (Document.open)").postln;
                };
                nFail == 0
            };
        };
    };
};

~files = [
    "00_load.scd", "engine.scd",
    "live/fx_bus.scd", "live/live.scd", "live/mixer.scd",
    "live/loops.scd", "live/scenes.scd", "live/tweaks.scd",
    "live/live_fx_panel.scd",
    "control/midi.scd", "control/playlist.scd", "control/jump.scd",
    "synth/_index.scd", "fx/_index.scd",
    "palette/scales.scd",
    "palette/styles.scd", "palette/timbres.scd",
    "palette/melodies/helpers.scd",
    "palette/melodies/index.scd",
    "palette/melodies/bank.scd",
    "palette/melodies/tracks.scd",
    "palette/harmonics/helpers.scd", "palette/harmonics/presets.scd",
    "palette/rhythm/_index.scd",
    "palette/chords_progressions.scd",
    "palette/fx.scd", "palette/fx_genre.scd",
    "palette/tweaks_template.scd",
];

~files.do { |rel|
    var path = ~base ++ rel;
    if (File.exists(path).not) {
        ~assert.(rel, false, "fichier introuvable");
    } {
        ~assert.("syntax: " ++ rel, ~compileFileSyntax.(path), "parse FAIL");
    };
};

// Tracks : scan recursif tracks/*.scd ET tracks/<album>/*.scd
// Skip les fichiers prefixes par "_" (orchestrateurs multi-bloc :
// _index.scd, _album.scd) -- la convention sound_algo les exclut.
~scanTracksSyntax = { |dirPath|
    PathName(dirPath).entries.do { |entry|
        if (entry.isFolder) {
            ~scanTracksSyntax.(entry.fullPath);
        } {
            if (entry.fullPath.endsWith(".scd") and: {
                entry.fileName.beginsWith("_").not
            }) {
                ~assert.("syntax: " ++ entry.fullPath.replace(~base, ""),
                    ~compileFileSyntax.(entry.fullPath), "parse FAIL");
            };
        };
    };
};
~scanTracksSyntax.(~base ++ "tracks/");

// Sous-dossiers eclates de palette/rhythm (presets interactifs)
PathName(~base ++ "palette/rhythm/").deepFiles.do { |pn|
    if (pn.extension == "scd" and: { pn.fileName != "_index.scd" }) {
        ~assert.("syntax: " ++ pn.fullPath.replace(~base, ""),
            ~compileFileSyntax.(pn.fullPath), "parse FAIL");
    };
};

// Sous-dossiers eclates de palette/melodies (short/long/xlong/epic)
["short", "long", "xlong", "epic"].do { |sub|
    PathName(~base ++ "palette/melodies/" ++ sub ++ "/").files.do { |pn|
        if (pn.extension == "scd") {
            ~assert.("syntax: " ++ pn.fullPath.replace(~base, ""),
                ~compileFileSyntax.(pn.fullPath), "parse FAIL");
        };
    };
};

~report.value;
