// =====================================================================
//  _album.scd  --  Album Q "Neurofunk DnB" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM Q
//    3. ~playTrack.(\Q, n) pour jouer la track n isolement
//       ~playAlbum.(\Q)    pour enchainer 01 -> 15
//       ~stopAlbum.()             pour arreter
// =====================================================================

(  // --- SETUP ALBUM Q ---
~albums = ~albums ? ();
~albums[\Q] = (
    title: "Neurofunk DnB",
    folder: "tracks/Q_neurofunk_dnb/",
    tracks: [
        \Q01_neurofunk_dnb,
        \Q02_amen_storm,
        \Q03_liquid_neuro,
        \Q04_growl_destroyer,
        \Q05_rolling_neuro,
        \Q06_tech_dnb,
        \Q07_minimal_dnb,
        \Q08_dark_dnb,
        \Q09_atmosphere_dnb,
        \Q10_hard_neuro,
        \Q11_jump_up,
        \Q12_sci_fi_dnb,
        \Q13_breakcore_dnb,
        \Q14_industrial_dnb,
        \Q15_neuro_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = ~playTrack ? { |album = \Q, n = 1|
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

~playAlbum = ~playAlbum ? { |album = \Q, gap = 8|
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

"[album Q] setup OK".postln;
)
