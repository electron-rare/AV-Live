// =====================================================================
//  _album.scd  --  Album O "Asian Cinematic" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM O (1 fois)
//    3. ~playTrack.(\O, 7)        pour jouer la track 7 isolement
//       ~playAlbum.(\O)           pour enchainer 01 -> 15
//       ~stopAlbum.()                     pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM O ---
~albums = ~albums ? ();
~albums[\O] = (
    title: "Asian Cinematic",
    folder: "tracks/O_asian_cinematic/",
    tracks: [
        \O01_asian_opening,
        \O02_koto_solo,
        \O03_erhu_lament,
        \O04_pipa_journey,
        \O05_shakuhachi_breath,
        \O06_guzheng_river,
        \O07_temple_bells,
        \O08_bamboo_grove,
        \O09_silk_road,
        \O10_mountain_mist,
        \O11_sakura_wind,
        \O12_dragon_dance,
        \O13_zen_garden,
        \O14_imperial_court,
        \O15_asian_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \O, n = 1|
    var info, file, path;
    info = ~albums[album.asSymbol];
    if (info.isNil) {
        ("!! album " ++ album ++ " inconnu").postln;
    } {
        file = info[\tracks][n - 1];
        if (file.isNil) {
            ("!! track " ++ album ++ n ++ " inexistante (1-" ++ info[\tracks].size ++ ")").postln;
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

~playAlbum = ~playAlbum ? { |album = \O, gap = 8|
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

"[album O] setup OK".postln;
)
