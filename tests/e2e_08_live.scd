// =====================================================================
//  e2e_08_live.scd
//  Verifie les helpers live.scd (LFO, vcf, drop, ...) et le bon
//  fonctionnement d'un LFO sur une variable globale (sans serveur).
// =====================================================================

"=== e2e_08_live ===".postln;

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

~loadAllBlocks = { |path|
    var src = File.readAllString(path);
    var lines = src.split($\n);
    var blocks = List.new;
    var capturing = false, balance = 0, current = nil;
    lines.do { |line|
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
                blocks.add(current.join($\n));
                capturing = false; current = nil;
            };
        };
    };
    blocks;
};

s = Server.internal;
s.waitForBoot({
    Routine({
        var initialKick, valueAfterLfo, blocksFx, blocksLive;
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;

        // fx_bus.scd : on charge le 1er bloc (defs SynthDef + setup buses)
        blocksFx = ~loadAllBlocks.(~base ++ "live/fx_bus.scd");
        blocksFx.do { |b|
            try { b.interpret } { |e|
                // ignore les erreurs runtime non critiques
            };
        };

        // live.scd : pareil, on charge tous les blocs (le 1er bloc est le SETUP
        // gigantesque qui contient les SynthDef + les helpers)
        blocksLive = ~loadAllBlocks.(~base ++ "live/live.scd");
        blocksLive.do { |b|
            try { b.interpret } { |e| /* ignore demos errors */ };
        };
        s.sync;

        ~assert.("~lfoTo defini",       ~lfoTo.notNil);
        ~assert.("~lfoStopVar defini",  ~lfoStopVar.notNil);
        ~assert.("~vcfOn defini",       ~vcfOn.notNil);
        ~assert.("~vcfOff defini",      ~vcfOff.notNil);
        ~assert.("~drop defini",        ~drop.notNil);
        ~assert.("~breakdown defini",   ~breakdown.notNil);
        ~assert.("~stutter defini",     ~stutter.notNil);
        ~assert.("~handsUp defini",     ~handsUp.notNil);

        // --- Test LFO sur ~kickAmp (sans audio, juste Routine sclang) ---
        initialKick = ~kickAmp ? 0.5;
        ~kickAmp = 0.5;  // baseline
        ~lfoTo.(\kickAmp, 2.0, 0.3, \sin, 0.5);  // 2Hz pour bouger vite
        1.0.wait;
        valueAfterLfo = ~kickAmp;
        ~assert.("LFO modifie ~kickAmp",
            valueAfterLfo != 0.5,
            "kickAmp inchange (" ++ valueAfterLfo ++ ")");
        ~assert.("LFO depth respecte (0.5 +/- 0.3)",
            (valueAfterLfo > 0.15) and: { valueAfterLfo < 0.85 },
            "value " ++ valueAfterLfo);

        ~lfoStopVar.(\kickAmp);
        ~assert.("~lfoStopVar -> ~lfos[\\kickAmp].isNil",
            ~lfos[\kickAmp].isNil,
            "still: " ++ ~lfos[\kickAmp]);

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
