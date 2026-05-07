// =====================================================================
//  _album.scd  --  Album R "Synthwave" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM R
//    3. ~playTrack.(\R, n) pour jouer la track n isolement
//       ~playAlbum.(\R)    pour enchainer 01 -> 15
//       ~stopAlbum.()             pour arreter
// =====================================================================

(  // --- SETUP ALBUM R ---
~albums = ~albums ? ();
~albums[\R] = (
    title: "Synthwave",
    folder: "tracks/R_synthwave/",
    tracks: [
        \R01_synthwave,
        \R02_retrowave,
        \R03_outrun,
        \R04_midnight_drive,
        \R05_neon_dream,
        \R06_vapor_cruise,
        \R07_eighties_pop,
        \R08_dark_synthwave,
        \R09_space_synthwave,
        \R10_italo_disco,
        \R11_synth_funk,
        \R12_dream_wave,
        \R13_synthwave_pulse,
        \R14_retro_arcade,
        \R15_synthwave_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \R, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \R, gap = 8|
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

"[album R] setup OK".postln;
)
