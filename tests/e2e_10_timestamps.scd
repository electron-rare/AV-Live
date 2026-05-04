// =====================================================================
//  e2e_10_timestamps.scd
//  Verifie que les timestamps `[X M:SS]` dans les .postln des
//  tracks/*.scd sont monotoniquement croissants.
//  Detecte les copy-paste casses ou les sections "new --" hors
//  chronologie (cf timestamps refacto F/G/M/N).
//  Pure analyse statique : ne lance aucune Routine.
// =====================================================================

"=== e2e_10_timestamps ===".postln;

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

// Parse "M:SS" -> seconds. Returns nil si format invalide.
~parseTs = { |str|
    var parts, m, s;
    parts = str.split($:);
    if (parts.size != 2) { nil } {
        m = parts[0].asInteger;
        s = parts[1].asInteger;
        (m * 60) + s;
    };
};

// Extrait les couples (timestamp_seconds, line_number) d'un fichier
// en cherchant les "[X M:SS] ...".postln; ou .postln (parenthese).
~extractTimestamps = { |srcLines, letter|
    var pattern, results = List.new;
    // pattern : [<letter> <m>:<ss>]
    pattern = "[" ++ letter ++ " ";
    srcLines.do { |line, i|
        var startIdx, endIdx, tsStr, ts;
        startIdx = line.find(pattern);
        if (startIdx.notNil) {
            endIdx = line.find("]", false, startIdx);
            if (endIdx.notNil) {
                tsStr = line.copyRange(startIdx + pattern.size, endIdx - 1);
                ts = ~parseTs.(tsStr);
                if (ts.notNil) {
                    results.add([ts, i + 1, tsStr]);
                };
            };
        };
    };
    results.array;
};

// Verifie monotonie pour une track donnee
~checkTrack = { |trackPath|
    var fileName, src, lines, letter, timestamps, prevTs, allOk;
    fileName = PathName(trackPath).fileName;
    // letter = premier char du nom (A_acid_journey -> A)
    letter = fileName[0].asString;
    src = File.readAllString(trackPath);
    lines = src.split($\n);
    timestamps = ~extractTimestamps.(lines, letter);

    // Au moins 2 timestamps attendus (intro + outro minimum)
    ~assert.(fileName ++ " has timestamps",
        timestamps.size >= 2,
        "found " ++ timestamps.size);

    // Monotonie : chaque ts >= precedent
    prevTs = -1;
    allOk = true;
    timestamps.do { |triple|
        var ts = triple[0], lineNum = triple[1], tsStr = triple[2];
        if (ts < prevTs) {
            allOk = false;
            ("    -> regression line " ++ lineNum
                ++ " : [" ++ letter ++ " " ++ tsStr ++ "] vient apres "
                ++ prevTs).postln;
        };
        prevTs = ts;
    };
    ~assert.(fileName ++ " timestamps monotones", allOk);
};

// Iter sur tous les tracks/*.scd
PathName(~base ++ "tracks/").files.do { |pn|
    if (pn.fullPath.endsWith(".scd")) {
        ~checkTrack.(pn.fullPath);
    };
};

~report.value;
