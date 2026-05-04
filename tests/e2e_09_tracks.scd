// =====================================================================
//  e2e_09_tracks.scd
//  Verifie que chaque tracks/*.scd compile (.compile retourne une
//  Function et non nil) sans executer la Routine.
// =====================================================================

"=== e2e_09_tracks ===".postln;

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

PathName(~base ++ "tracks/").files.do { |pn|
    if (pn.fullPath.endsWith(".scd")) {
        var src = File.readAllString(pn.fullPath);
        var compiled = src.compile;
        ~assert.("compile track " ++ pn.fileName,
            compiled.isKindOf(Function),
            "got class " ++ compiled.class);
    };
};

~report.value;
