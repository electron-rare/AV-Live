// =====================================================================
//  e2e_10_timestamps.scd
//  Verifie que les timestamps `[X M:SS]` dans les .postln des
//  tracks/*.scd sont monotoniquement croissants.
//  Detecte les copy-paste casses ou les sections "new --" hors
//  chronologie (cf timestamps refacto F/G/M/N).
//  Pure analyse statique : ne lance aucune Routine.
// =====================================================================

"=== e2e_10_timestamps ===".postln;

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
~extractTimestamps = { |srcLines, tag|
    var pattern, results = List.new;
    // pattern : [<tag> <m>:<ss>]   ex: [A 0:00] ou [A02 1:30]
    pattern = "[" ++ tag ++ " ";
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
    var fileName, src, lines, tag, timestamps, prevTs, allOk;
    fileName = PathName(trackPath).fileName;
    // tag = portion avant le premier '_' du nom de fichier
    //   A_acid_journey.scd       -> "A"   (legacy standalone)
    //   A02_minimal_acid.scd     -> "A02" (album sub-track v2)
    tag = fileName.split($_)[0];
    src = File.readAllString(trackPath);
    lines = src.split($\n);
    timestamps = ~extractTimestamps.(lines, tag);

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
                ++ " : [" ++ tag ++ " " ++ tsStr ++ "] vient apres "
                ++ prevTs).postln;
        };
        prevTs = ts;
    };
    ~assert.(fileName ++ " timestamps monotones", allOk);
};

// Iter recursif : tracks/*.scd ET tracks/<album>/*.scd
// Skip prefixe "_" (orchestrateurs : _index.scd, _album.scd -- ils ne
// contiennent pas de timestamps de sections, c'est de la metadonnee).
~scanForTs = { |dirPath|
    PathName(dirPath).entries.do { |entry|
        if (entry.isFolder) {
            ~scanForTs.(entry.fullPath);
        } {
            if (entry.fullPath.endsWith(".scd") and: {
                entry.fileName.beginsWith("_").not
            }) {
                ~checkTrack.(entry.fullPath);
            };
        };
    };
};
~scanForTs.(~base ++ "tracks/");

~report.value;
