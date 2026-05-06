// =====================================================================
//  e2e_05_melodies.scd
//  Verifie les melodies/helpers de palette/melodies/index.scd :
//    ~m1..~m78 (32 steps), ~ml1..~ml30 (64), ~mxl1..~mxl15 (96),
//    ~mepic1..~mepic10 (128), ~useMelody, ~melodyByGenre,
//    ~stretchPattern, ~mirror.
// =====================================================================

"=== e2e_05_melodies ===".postln;

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

// Le module melodies est multi-blocs reparti dans plusieurs fichiers.
// On split chaque fichier en blocs et on interprete bloc par bloc,
// en sautant les blocs IDE-only ou les blocs qui font reference a des
// helpers non definis (rares).
~loadAllBlocks = { |path|
    var src = File.readAllString(path);
    var lines, blocks, capturing, balance, current;
    lines = src.split($\n);
    blocks = List.new;
    capturing = false; balance = 0; current = nil;
    lines.do { |line|
        if (capturing.not and: { (line.size > 0) and: { line[0] == $( } }) {
            capturing = true;
            balance = 0;
            current = List.new;
        };
        if (capturing) {
            current.add(line);
            line.do { |c|
                if (c == $( ) { balance = balance + 1 };
                if (c == $) ) { balance = balance - 1 };
            };
            if (balance == 0) {
                blocks.add(current.join($\n));
                capturing = false;
                current = nil;
            };
        };
    };
    blocks;
};

s = Server.internal;
s.waitForBoot({
    Routine({
        var blocks, idx = 0, nFail = 0;
        var initial, lookupHits = 0;
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;

        // Charge palette/scales.scd (scales + helpers melodiques)
        try { (~base ++ "palette/scales.scd").load } { |e|
            ("scales err: " ++ e.errorString).postln };
        s.sync;

        // Charge melodies : helpers.scd + sous-dossiers eclates
        // (short/long/xlong/epic = 2898 fichiers a la v2) + bank + tracks
        // Construction dynamique de la liste (index.scd lui-meme passe par
        // PathName.deepFiles donc on reproduit la meme strategie ici pour
        // les tests bloc par bloc).
        blocks = List.new;
        ([
            "palette/melodies/helpers.scd"
        ] ++ (
            ["short", "long", "xlong", "epic"].collect { |sub|
                PathName(~base ++ "palette/melodies/" ++ sub ++ "/").files
                    .select { |pn| pn.extension == "scd" }
                    .collect { |pn| pn.fullPath.replace(~base, "") };
            }.flatten
        ) ++ [
            "palette/melodies/bank.scd",
            "palette/melodies/tracks.scd"
        ]).do { |relPath|
            var bs = ~loadAllBlocks.(~base ++ relPath);
            bs.do { |b|
                idx = idx + 1;
                try { b.interpret } { |e| nFail = nFail + 1;
                    ("    !! " ++ relPath ++ " bloc#" ++ idx ++ " : " ++ e.errorString).postln };
            };
            bs.do { |b| blocks.add(b) };
        };
        ~assert.("melodies module : " ++ blocks.size ++ " blocs interpretes",
            nFail == 0, nFail.asString ++ " blocs en echec");
        s.sync;

        // --- m1..m78 (32 steps) ---
        // Note : 4 indices sont des "blocs demo" qui ne creent pas de var ~m6
        //   m6  = random walk (genere a la volee)
        //   m22 = modulating runs (evolutif)
        //   m25 = counter melody (set ~harmonyNotes pas ~melodyNotes)
        //   m26 = cascade 32nd (pareil)
        // -> on les exclut. Verifier (1..78).reject({ ... }).
        (1..78).reject { |i| #[6, 22, 25, 26].includes(i) }.do { |i|
            var sym = ("m" ++ i).asSymbol;
            var notes = currentEnvironment[sym];
            if (notes.isNil or: { notes.isArray.not } or: { notes.size == 0 }) {
                ~assert.("~" ++ sym ++ " defini (32 steps attendus)", false,
                    "missing/empty (size=" ++ notes.tryPerform(\size) ++ ")");
            } {
                ~assert.("~" ++ sym ++ " defini (size=" ++ notes.size ++ ")", true);
            };
        };

        // --- ml1..ml30 (64) ---
        (1..30).do { |i|
            var sym = ("ml" ++ i).asSymbol;
            var notes = currentEnvironment[sym];
            ~assert.("~" ++ sym ++ " = 64 steps",
                notes.notNil and: { notes.size == 64 },
                "size=" ++ notes.tryPerform(\size));
        };

        // --- mxl1..mxl15 (96) ---
        (1..15).do { |i|
            var sym = ("mxl" ++ i).asSymbol;
            var notes = currentEnvironment[sym];
            ~assert.("~" ++ sym ++ " = 96 steps",
                notes.notNil and: { notes.size == 96 },
                "size=" ++ notes.tryPerform(\size));
        };

        // --- mepic1..mepic10 (128) ---
        (1..10).do { |i|
            var sym = ("mepic" ++ i).asSymbol;
            var notes = currentEnvironment[sym];
            ~assert.("~" ++ sym ++ " = 128 steps",
                notes.notNil and: { notes.size == 128 },
                "size=" ++ notes.tryPerform(\size));
        };

        // --- ~useMelody.(\m50) ---
        ~useMelody.(\m50);
        ~assert.("~useMelody.(\\m50) -> ~melodyNotes == ~m50",
            ~melodyNotes == ~m50);

        // --- ~melodyByGenre.(\acid) ---
        ~melodyByGenre.(\acid);
        ~assert.("~melodyByGenre.(\\acid) set ~melodyNotes",
            ~melodyNotes.notNil and: { ~melodyNotes.size > 0 });

        // --- Lookup indirect : redefinir ~m29 et verifier que ~melodyByGenre
        //     finit par utiliser la nouvelle valeur (preuve que le bank ne
        //     stocke pas une copie figee de l'ancienne).
        ~m29 = [99, 99, 99];
        // Le bank \acid contient \m29 parmi ~130 entrees (post-split v2).
        // P(hit sur N essais) = 1 - (126/127)^N. Pour 99% on a besoin de
        // N >= 580. On utilise 1000 pour avoir une marge confortable.
        lookupHits = 0;
        1000.do {
            ~melodyByGenre.(\acid);
            if (~melodyNotes == [99, 99, 99]) { lookupHits = lookupHits + 1 };
        };
        ~assert.("~melodyByGenre lookup indirect (m29 modifie pris en compte)",
            lookupHits > 0,
            "0 hits sur 1000 essais -- bank a peut-etre fige les valeurs");

        // --- ~stretchPattern.([1,2,3,4], 2) -> 8 elements ---
        ~assert.("~stretchPattern factor=2", ~stretchPattern.([1,2,3,4], 2).size == 8);

        // --- ~mirror.([1,2,3]) -> [1,2,3,3,2,1] ---
        ~assert.("~mirror retourne palindrome",
            ~mirror.([1,2,3]) == [1,2,3,3,2,1]);

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
