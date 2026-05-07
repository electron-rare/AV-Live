// =====================================================================
//  _album.scd  --  Album K "Tribal Ethno" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM K (1 fois)
//    3. ~playTrack.(\K, 7)        pour jouer la track 7 isolement
//       ~playAlbum.(\K)           pour enchainer 01 -> 15
//       ~stopAlbum.()                     pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM K ---
~albums = ~albums ? ();
~albums[\K] = (
    title: "Tribal Ethno",
    folder: "tracks/K_tribal_ethno/",
    tracks: [
        \K01_tribal_opening,
        \K02_handpan_dawn,
        \K03_didgeridoo_drift,
        \K04_taiko_war,
        \K05_tabla_groove,
        \K06_jungle_chant,
        \K07_desert_walk,
        \K08_polyrhythm_storm,
        \K09_shamanic_trance,
        \K10_forest_ritual,
        \K11_river_song,
        \K12_fire_dance,
        \K13_mountain_call,
        \K14_ancestor_voices,
        \K15_tribal_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \K, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \K, gap = 8|
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

"[album K] setup OK".postln;
)
