// =====================================================================
//  e2e_07_jump.scd
//  Verifie le SETUP de jump.scd et l'execution d'une section.
// =====================================================================

"=== e2e_07_jump ===".postln;

~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo/";
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

// Charge tous les blocs top-level d'un fichier .scd multi-blocs
// jusqu'a un bloc cible (predicat sur le contenu).
~loadAllBlocks = { |path, untilPred|
    var src = File.readAllString(path);
    var lines = src.split($\n);
    var blocks = List.new;
    var capturing = false, balance = 0, current = nil, stop = false;
    lines.do { |line|
        if (stop.not) {
            if (capturing.not and: { (line.size > 0) and: { line[0] == $( } }) {
                capturing = true; balance = 0; current = List.new;
            };
            if (capturing) {
                current.add(line);
                line.do { |c|
                    if (c == $( ) { balance = balance + 1 };
                    if (c == $) ) { balance = balance - 1 };
                };
                if (balance == 0) {
                    var blk = current.join($\n);
                    blocks.add(blk);
                    capturing = false; current = nil;
                    if (untilPred.notNil and: { untilPred.value(blk) }) {
                        stop = true;
                    };
                };
            };
        };
    };
    blocks;
};

s = Server.internal;
s.waitForBoot({
    Routine({
        var blocks, setupOk = true, sectionAOk = true;
        var jumpedOk = true, jumpedNonExistent = true;
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;

        // Charge les blocs jump.scd jusqu'a et y compris le bloc TRACK A
        // (~sections['A'] = ...).
        blocks = ~loadAllBlocks.(~base ++ "control/jump.scd", { |b|
            b.contains("~sections['A']") or: { b.contains("~sections[\\A]") }
        });

        // Execute le 1er bloc (SETUP) et le bloc TRACK A
        try { blocks[0].interpret } { |e|
            setupOk = false; ("setup err: " ++ e.errorString).postln };
        ~assert.("jump SETUP execute", setupOk);
        ~assert.("~jumpTo defini", ~jumpTo.notNil);
        ~assert.("~sections defini", ~sections.notNil);

        // Cherche le bloc qui contient ~sections['A'] ou ~sections[\A]
        blocks.do { |b|
            if (b.contains("~sections['A']") or: { b.contains("~sections[\\A]") }) {
                try { b.interpret } { |e|
                    sectionAOk = false; ("track A err: " ++ e.errorString).postln };
            };
        };
        ~assert.("track A bloc execute", sectionAOk);
        ~assert.("~sections['A'] presente", ~sections['A'.asSymbol].notNil
            or: { ~sections[\A].notNil });

        // ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad')
        try { ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad') }
            { |e| jumpedOk = false; ("jumpTo err: " ++ e.errorString).postln };
        ~assert.("~jumpTo('A','minimal_..._pad') sans erreur", jumpedOk);
        ~assert.("section a set ~melodyInst = \\pad", ~melodyInst == \pad,
            "got: " ++ ~melodyInst);

        // ~jumpTo.('A', 'inexistante_xxx') : doit poster mais ne pas crasher
        try { ~jumpTo.('A', 'inexistante_xxx') }
            { |e| jumpedNonExistent = false; ("err: " ++ e.errorString).postln };
        ~assert.("~jumpTo section inexistante : pas de crash", jumpedNonExistent);

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
