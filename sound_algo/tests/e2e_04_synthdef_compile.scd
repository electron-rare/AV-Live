// =====================================================================
//  e2e_04_synthdef_compile.scd
//  Charge engine + fx_bus + live + authentic et verifie que les
//  SynthDef critiques compilent sans erreur (.asBytes force la
//  compilation sans envoyer au serveur). Si une UGen manque, .asBytes
//  plante.
// =====================================================================

"=== e2e_04_synthdef_compile ===".postln;

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

// Charge tous les blocs top-level d'un fichier .scd multi-blocs.
// Echoue silencieusement bloc par bloc pour ne pas couper le test.
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
    blocks.do { |b|
        try { b.interpret } { |e|
            // Beaucoup de blocs sont des exemples qui necessitent
            // les Synth runtime ; on ignore les erreurs runtime
            // mais on log les erreurs de compilation/UGen manquante.
            if (e.errorString.contains("UGen") or:
                { e.errorString.contains("doesNotUnderstand") and:
                  { e.errorString.contains("SynthDef") } }) {
                ("    !! load " ++ path.basename ++ " : " ++ e.errorString).postln;
            };
        };
    };
};

s = Server.internal;
// Headroom : 1099 SynthDef dans synth/ + fx/, defaut 1024
s.options.maxSynthDefs = 4096;
s.waitForBoot({
    Routine({
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;
        try { (~base ++ "synth/_index.scd").load } { |e| ("synth err: " ++ e.errorString).postln };
        try { (~base ++ "fx/_index.scd").load }    { |e| ("fx err: "    ++ e.errorString).postln };
        // Multi-blocs : charge bloc par bloc
        ~loadAllBlocks.(~base ++ "live/fx_bus.scd");
        ~loadAllBlocks.(~base ++ "live/live.scd");
        2.wait;
        s.sync;

        // Liste des SynthDef critiques
        // (on verifie qu'ils sont enregistres dans SynthDescLib.global ;
        //  l'enregistrement implique une compilation .asBytes reussie cote sclang)
        [
            // fx_bus.scd : version sans Decimator
            \fxBitcrush, \fxDelay, \fxReverb, \fxChorus, \fxPhaser, \fxFlanger,
            \fxTape, \fxShimmer, \fxDist, \fxSend,
            // authentic.scd : scratch fixe avec Select.kr
            \scratch,
            // live.scd : VCF master
            \vcfMoog, \vcfMs20, \vcfLadder, \vcfFormant, \vcfComb,
            \vcfHpf, \vcfBpf, \vcfNotch,
            // live.scd : FX additionnels
            \fxRingMod, \fxFreqShift, \fxGran, \fxComb, \fxFormant,
            \fxAutoFilter, \fxTremolo, \fxAutopan, \fxStutter,
            \fxResonator, \fxSpringRev, \fxPlate,
            // live.scd : master comp/sat
            \masterComp, \masterSat,
            // live.scd : FX master one-shots
            \fxMasterPitch, \fxMasterRing, \fxMasterFreqShift, \fxMasterGran,
            \fxMasterBitcrush
        ].do { |sym|
            var defined = SynthDescLib.global.synthDescs[sym].notNil;
            ~assert.("synthdef " ++ sym ++ " compile", defined,
                "absent (UGen manquante ? compilation echouee ?)");
        };

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
