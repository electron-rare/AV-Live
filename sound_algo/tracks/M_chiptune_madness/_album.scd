// =====================================================================
//  _album.scd  --  Album M "Chiptune Madness" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM M (1 fois)
//    3. ~playTrack.(\M, 7)        pour jouer la track 7 isolement
//       ~playAlbum.(\M)           pour enchainer 01 -> 15
//       ~stopAlbum.()                     pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM M ---
~albums = ~albums ? ();
~albums[\M] = (
    title: "Chiptune Madness",
    folder: "tracks/M_chiptune_madness/",
    tracks: [
        \M01_pixel_intro,
        \M02_eight_bit_run,
        \M03_boss_battle,
        \M04_save_point,
        \M05_level_one,
        \M06_game_over,
        \M07_warp_zone,
        \M08_coin_rush,
        \M09_speedrun,
        \M10_hidden_stage,
        \M11_retro_arcade,
        \M12_glitch_world,
        \M13_final_boss,
        \M14_victory_theme,
        \M15_credits_chip,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \M, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \M, gap = 8|
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

"[album M] setup OK".postln;
)
