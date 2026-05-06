// =====================================================================
//  e2e_09_tracks.scd
//  Verifie que chaque tracks/*.scd compile (.compile retourne une
//  Function et non nil) sans executer la Routine.
// =====================================================================

"=== e2e_09_tracks ===".postln;

// ~base auto-derive depuis l'emplacement du test (portable entre worktrees).
~base = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../";
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

// Scan recursif : tracks/*.scd ET tracks/<album>/*.scd (sous-dossiers
// d'album generes par la convention "<L>_<slug>/<L>NN_<sub>.scd").
// Skip _album.scd : c'est un orchestrateur multi-bloc, pas une track.
~scanTracks = { |dirPath|
    PathName(dirPath).entries.do { |entry|
        if (entry.isFolder) {
            ~scanTracks.(entry.fullPath);
        } {
            if (entry.fullPath.endsWith(".scd") and: {
                entry.fileName.beginsWith("_").not
            }) {
                var src = File.readAllString(entry.fullPath);
                var compiled = src.compile;
                ~assert.("compile " ++ entry.fileName,
                    compiled.isKindOf(Function),
                    "got class " ++ compiled.class);
            };
        };
    };
};
~scanTracks.(~base ++ "tracks/");

~report.value;
