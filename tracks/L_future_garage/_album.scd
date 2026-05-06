// =====================================================================
//  _album.scd  --  Album L "Future Garage" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM L (1 fois)
//    3. ~playTrack.(\L, 7)        pour jouer la track 7 isolement
//       ~playAlbum.(\L)           pour enchainer 01 -> 15
//       ~stopAlbum.()                     pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM L ---
~albums = ~albums ? ();
~albums[\L] = (
    title: "Future Garage",
    folder: "tracks/L_future_garage/",
    tracks: [
        \L01_garage_opening,
        \L02_midnight_dub,
        \L03_rain_on_glass,
        \L04_warehouse_echo,
        \L05_submerged_bass,
        \L06_vocal_haze,
        \L07_step_two,
        \L08_london_drizzle,
        \L09_breath_pad,
        \L10_deep_swing,
        \L11_ghost_clap,
        \L12_subterranean,
        \L13_neon_droplets,
        \L14_bassline_dub,
        \L15_garage_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \L, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \L, gap = 8|
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

"[album L] setup OK".postln;
)
