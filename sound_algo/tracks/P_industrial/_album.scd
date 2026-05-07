// =====================================================================
//  _album.scd  --  Album P "Industrial" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM P
//    3. ~playTrack.(\P, n) pour jouer la track n isolement
//       ~playAlbum.(\P)    pour enchainer 01 -> 15
//       ~stopAlbum.()             pour arreter
// =====================================================================

(  // --- SETUP ALBUM P ---
~albums = ~albums ? ();
~albums[\P] = (
    title: "Industrial",
    folder: "tracks/P_industrial/",
    tracks: [
        \P01_industrial,
        \P02_ebm_classic,
        \P03_dark_factory,
        \P04_metal_pulse,
        \P05_industrial_dub,
        \P06_rust_machine,
        \P07_steel_ritual,
        \P08_acid_industrial,
        \P09_noise_engine,
        \P10_dystopia,
        \P11_smoke_stack,
        \P12_ebm_strict,
        \P13_furnace,
        \P14_urban_decay,
        \P15_industrial_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \P, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \P, gap = 8|
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

"[album P] setup OK".postln;
)
