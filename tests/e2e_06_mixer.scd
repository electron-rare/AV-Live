// =====================================================================
//  e2e_06_mixer.scd
//  Verifie l'API mixer.scd : ~setVol, ~masterVol, ~mute, ~unmute,
//  ~solo, ~unsolo, ~mixReset.
// =====================================================================

"=== e2e_06_mixer ===".postln;

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

~floatEq = { |a, b, eps = 1e-6| (a - b).abs < eps };

s = Server.internal;
s.waitForBoot({
    Routine({
        var kickInit, hatInit, refKick, refHat;
        var blocks, idx = 0;
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;

        // Charge le SETUP de mixer.scd : 1er gros bloc seulement (les blocs
        // suivants sont des exemples a la demande).
        blocks = ~loadAllBlocks.(~base ++ "live/mixer.scd");
        // Le 1er bloc top-level est le SETUP complet
        if (blocks.size > 0) {
            try { blocks[0].interpret } { |e|
                ("mixer setup err: " ++ e.errorString).postln };
        };
        s.sync;

        ~assert.("~setVol defini",     ~setVol.notNil);
        ~assert.("~masterVol defini",  ~masterVol.notNil);
        ~assert.("~mute defini",       ~mute.notNil);
        ~assert.("~solo defini",       ~solo.notNil);
        ~assert.("~mixReset defini",   ~mixReset.notNil);

        kickInit = ~kickAmp;
        refKick = ~mixRef[\kick];

        // ~setVol.(\kick, 0.5) : amp = ref * 0.5 * mixMaster(=1) = ref * 0.5
        ~setVol.(\kick, 0.5);
        ~assert.("~setVol kick 0.5 -> kickAmp = ref * 0.5",
            ~floatEq.(~kickAmp, refKick * 0.5),
            "got " ++ ~kickAmp ++ " expected " ++ (refKick * 0.5));

        // ~masterVol.(0.5) : amp = ref * 0.5 (coef voie) * 0.5 (master)
        ~masterVol.(0.5);
        ~assert.("~mixMaster == 0.5", ~floatEq.(~mixMaster, 0.5));
        ~assert.("~kickAmp = ref * 0.5 * 0.5",
            ~floatEq.(~kickAmp, refKick * 0.5 * 0.5),
            "got " ++ ~kickAmp);

        // ~masterVol.(1.0) : kickAmp doit revenir a ref * 0.5
        ~masterVol.(1.0);
        ~assert.("~masterVol(1) restore : kickAmp = ref * 0.5 (non-destructif)",
            ~floatEq.(~kickAmp, refKick * 0.5),
            "got " ++ ~kickAmp);

        // ~mixReset : tous les coefs a 1
        ~mixReset.value;
        ~assert.("~mixReset : ~mix[\\kick] == 1", ~floatEq.(~mix[\kick], 1.0));
        ~assert.("~mixReset : ~mix[\\hat] == 1", ~floatEq.(~mix[\hat], 1.0));
        ~assert.("~mixReset : ~kickAmp == ref", ~floatEq.(~kickAmp, refKick));

        // ~mute / ~unmute
        ~mute.(\kick);
        ~assert.("~mute kick -> kickAmp == 0", ~kickAmp == 0,
            "got " ++ ~kickAmp);
        ~unmute.(\kick);
        ~assert.("~unmute kick -> kickAmp restored",
            ~floatEq.(~kickAmp, refKick),
            "got " ++ ~kickAmp);

        // ~solo / ~unsolo
        ~solo.(\melody);
        ~assert.("~solo melody -> kickAmp == 0", ~kickAmp == 0);
        ~assert.("~solo melody -> melodyAmp != 0", ~melodyAmp != 0);
        ~unsolo.value;
        ~assert.("~unsolo -> kickAmp restored",
            ~floatEq.(~kickAmp, refKick),
            "got " ++ ~kickAmp);

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
