// =====================================================================
//  _album.scd  --  Album N "Phonk" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM N (1 fois)
//    3. ~playTrack.(\N, 7)        pour jouer la track 7 isolement
//       ~playAlbum.(\N)           pour enchainer 01 -> 15
//       ~stopAlbum.()                     pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM N ---
~albums = ~albums ? ();
~albums[\N] = (
    title: "Phonk",
    folder: "tracks/N_phonk/",
    tracks: [
        \N01_phonk_opening,
        \N02_memphis_drift,
        \N03_cowbell_curse,
        \N04_dark_alley,
        \N05_tape_hiss,
        \N06_anguish_808,
        \N07_drift_phonk,
        \N08_haunted_ride,
        \N09_midnight_chase,
        \N10_cursed_bells,
        \N11_trap_phonk,
        \N12_low_riser,
        \N13_ghost_drift,
        \N14_gospel_808,
        \N15_phonk_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \N, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \N, gap = 8|
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

"[album N] setup OK".postln;
)
