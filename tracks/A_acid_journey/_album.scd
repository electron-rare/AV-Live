// =====================================================================
//  _album.scd  --  Album A "Acid Journey" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM A (1 fois pour declarer ~playAlbum / ~playTrack)
//    3. ~playTrack.(\A, 7)         pour jouer la track 7 isolement
//       ~playAlbum.(\A)            pour enchainer 01 -> 15 sequentiellement
//       ~stopAlbum.()              pour interrompre l'album
//
//  Chaque track est autonome : tu peux aussi ouvrir A07_acid_techno.scd
//  et Cmd+Entree directement sur son bloc (...).
// =====================================================================

(  // --- SETUP ALBUM A ---
~albums = ~albums ? ();
~albums[\A] = (
    title: "Acid Journey",
    folder: "tracks/A_acid_journey/",
    tracks: [
        \A01_acid_journey,
        \A02_minimal_acid,
        \A03_acid_house,
        \A04_detroit_acid,
        \A05_dub_acid,
        \A06_ambient_acid,
        \A07_acid_techno,
        \A08_dark_acid,
        \A09_tribal_acid,
        \A10_cosmic_acid,
        \A11_trance_acid,
        \A12_hard_acid,
        \A13_acidcore,
        \A14_industrial_acid,
        \A15_acid_finale,
    ],
    durations: [480, 240, 360, 300, 420, 480, 360, 360, 420, 480, 420, 300, 240, 300, 360],
);

~playTrack = { |album = \A, n = 1|
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

~stopAlbum = {
    ~albumRoutine !? { ~albumRoutine.stop; ~albumRoutine = nil };
    ~track !? { ~track.stop; ~track = nil };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[ALBUM] stop".postln;
};

~playAlbum = { |album = \A, gap = 8|
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

"[album A] setup OK -- ~playTrack.(\\A, n) | ~playAlbum.(\\A) | ~stopAlbum.()".postln;
)


// =====================================================================
//  RACCOURCIS LIVE -- Cmd+Entree sur la ligne souhaitee
// =====================================================================

( ~playTrack.(\A,  1); )    // A01 acid_journey       (8 min)
( ~playTrack.(\A,  2); )    // A02 minimal_acid       (4 min)
( ~playTrack.(\A,  3); )    // A03 acid_house         (6 min)
( ~playTrack.(\A,  4); )    // A04 detroit_acid       (5 min)
( ~playTrack.(\A,  5); )    // A05 dub_acid           (7 min)
( ~playTrack.(\A,  6); )    // A06 ambient_acid       (8 min)
( ~playTrack.(\A,  7); )    // A07 acid_techno        (6 min)
( ~playTrack.(\A,  8); )    // A08 dark_acid          (6 min)
( ~playTrack.(\A,  9); )    // A09 tribal_acid        (7 min)
( ~playTrack.(\A, 10); )    // A10 cosmic_acid        (8 min)
( ~playTrack.(\A, 11); )    // A11 trance_acid        (7 min)
( ~playTrack.(\A, 12); )    // A12 hard_acid          (5 min)
( ~playTrack.(\A, 13); )    // A13 acidcore           (4 min)
( ~playTrack.(\A, 14); )    // A14 industrial_acid    (5 min)
( ~playTrack.(\A, 15); )    // A15 acid_finale        (6 min)

( ~playAlbum.(\A); )        // album entier 01 -> 15 (~ 88 min)
( ~stopAlbum.(); )          // arret immediat
