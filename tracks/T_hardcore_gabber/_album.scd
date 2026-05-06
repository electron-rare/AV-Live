// =====================================================================
//  _album.scd  --  Album T "Hardcore Gabber" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM T
//    3. ~playTrack.(\T, n) pour jouer la track n isolement
//       ~playAlbum.(\T)    pour enchainer 01 -> 15
//       ~stopAlbum.()             pour arreter
// =====================================================================

(  // --- SETUP ALBUM T ---
~albums = ~albums ? ();
~albums[\T] = (
    title: "Hardcore Gabber",
    folder: "tracks/T_hardcore_gabber/",
    tracks: [
        \T01_hardcore_gabber,
        \T02_rotterdam,
        \T03_uptempo,
        \T04_acid_gabber,
        \T05_industrial_gabber,
        \T06_speedcore,
        \T07_oldschool_gabba,
        \T08_dark_hardcore,
        \T09_happy_hardcore,
        \T10_frenchcore,
        \T11_terror,
        \T12_mainstream_hard,
        \T13_raw_gabba,
        \T14_industrial_core,
        \T15_gabber_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \T, n = 1|
    var info, file, path;
    info = ~albums[album.asSymbol];
    if (info.isNil) {
        ("!! album " ++ album ++ " inconnu").postln;
    } {
        file = info[\tracks][n - 1];
        if (file.isNil) {
            ("!! track " ++ album ++ n ++ " inexistante").postln;
        } {
            path = (~base ? "") ++ info[\folder] ++ file ++ ".scd";
            ("[ALBUM " ++ album ++ "] track " ++ n ++ " : " ++ file).postln;
            path.load;
        };
    };
};

~stopAlbum = ~stopAlbum ? {
    ~albumRoutine !? { ~albumRoutine.stop; ~albumRoutine = nil };
    ~track !? { ~track.stop; ~track = nil };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[ALBUM] stop".postln;
};

~playAlbum = ~playAlbum ? { |album = \T, gap = 8|
    var info = ~albums[album.asSymbol];
    if (info.isNil) {
        ("!! album " ++ album ++ " inconnu").postln;
    } {
        ~stopAlbum.();
        ~albumRoutine = Routine({
            ("=== ALBUM " ++ album ++ " : " ++ info[\title] ++ " ===").postln;
            info[\tracks].do { |slug, i|
                var dur = info[\durations][i];
                ("[ALBUM " ++ album ++ "] -> track " ++ (i + 1) ++ "/"
                 ++ info[\tracks].size ++ " : " ++ slug
                 ++ "  (" ++ dur ++ "s)").postln;
                ~playTrack.(album, i + 1);
                (dur + gap).wait;
            };
            ("=== ALBUM " ++ album ++ " complete ===").postln;
        }).play;
    };
};

"[album T] setup OK".postln;
)
