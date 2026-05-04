// =====================================================================
//  e2e_02_load.scd
//  Boot Server.internal, charge engine + synthdefs + fills (sequence
//  "CHARGER TOUT" du loader) et verifie helpers + SynthDefs attendus.
//  Note : engine.scd wrap son SETUP dans s.waitForBoot {} qui differe
//  l'execution sur AppClock. On utilise une Routine + .wait pour
//  laisser le callback s'executer.
// =====================================================================

"=== e2e_02_load ===".postln;

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
    // Pas de s.quit -- declenche un abort C++ a la fin sur certains setups.
    // sclang fera le cleanup propre via 0.exit.
    if (~testFailed > 0) { 1.exit } { 0.exit };
};

// Charge le PREMIER bloc top-level (...) d'un fichier multi-blocs
// (utile pour palette/rhythm/fills.scd qui contient en fin des blocs '( ~snareFill.value; )' de demo).
~loadFirstBlock = { |path|
    var src = File.readAllString(path);
    var lines, block, capturing, done, balance;
    lines = src.split($\n);
    block = List.new;
    capturing = false; done = false; balance = 0;
    lines.do { |line|
        if (done.not) {
            if (capturing.not and: { (line.size > 0) and: { line[0] == $( } }) {
                capturing = true;
                balance = 0;
            };
            if (capturing) {
                block.add(line);
                line.do { |c|
                    if (c == $( ) { balance = balance + 1 };
                    if (c == $) ) { balance = balance - 1 };
                };
                if (balance == 0) { done = true };
            };
        };
    };
    block.join($\n).interpret;
};

s = Server.internal;
s.waitForBoot({
    Routine({
        "  [INFO] Server.internal booted".postln;
        s.sync;

        // engine.scd : single-block top-level qui wrappe s.waitForBoot {...}
        try { (~base ++ "engine.scd").load } { |e|
            ("  [INFO] engine load: " ++ e.errorString).postln };
        // Laisse l'AppClock executer le callback de waitForBoot
        2.wait;
        s.sync;

        try { (~base ++ "synthdefs/asia.scd").load }      { |e| ("  [INFO] asia: "  ++ e.errorString).postln };
        try { (~base ++ "synthdefs/extra.scd").load }     { |e| ("  [INFO] extra: " ++ e.errorString).postln };
        try { (~base ++ "synthdefs/authentic.scd").load } { |e| ("  [INFO] authn: " ++ e.errorString).postln };

        try { ~loadFirstBlock.(~base ++ "palette/rhythm/fills.scd") } { |e|
            ("  [INFO] fills: " ++ e.errorString).postln };
        // Charge scales + harmonics (sources de ~genMelody et ~enableHarmony
        // depuis la reorganisation -- engine.scd ne les definit plus).
        try { (~base ++ "palette/scales.scd").load } { |e|
            ("  [INFO] scales: " ++ e.errorString).postln };
        try { (~base ++ "palette/harmonics/index.scd").load } { |e|
            ("  [INFO] harmonics: " ++ e.errorString).postln };
        s.sync;

        ~assert.("helper ~reload defini",        ~reload.notNil);
        ~assert.("helper ~enableHarmony defini", ~enableHarmony.notNil);
        ~assert.("helper ~snareFill defini",     ~snareFill.notNil);
        ~assert.("helper ~tomFill defini",       ~tomFill.notNil);

        // Note: \fbVoice etait dans la liste attendue mais n'est defini
        // que dans _old/. On le verifie comme reference d'absence.
        [
            \kick, \hat, \snare, \clap, \acid, \koto, \erhu,
            \warmPad, \subBoom, \drone, \kickGabber, \supersaw, \scratch
        ].do { |sym|
            var defined = SynthDescLib.global.synthDescs[sym].notNil;
            ~assert.("synthdef " ++ sym, defined, "absent de SynthDescLib.global");
        };
        // \fbVoice : reporte mais NON-FAIL (reference uniquement dans _old/)
        if (SynthDescLib.global.synthDescs[\fbVoice].isNil) {
            "  [INFO] \\fbVoice non defini (existe seulement dans _old/)".postln;
        };

        ~report.value;
    }).play;
}, 15, { "  [FAIL] Server.internal boot timeout".postln; 1.exit });
