// =====================================================================
//  _album.scd  --  Album J "Ambient Cinematic" : 15 tracks orchestrateur
// =====================================================================

(  // --- SETUP ALBUM J ---
~albums = ~albums ? ();
~albums[\J] = (
    title: "Ambient Cinematic",
    folder: "tracks/J_ambient_cinematic/",
    tracks: [
        \J01_first_light,
        \J02_drone_meditation,
        \J03_strings_horizon,
        \J04_choir_cathedral,
        \J05_endless_sky,
        \J06_handpan_garden,
        \J07_glacial_drift,
        \J08_dark_matter,
        \J09_oceanic,
        \J10_deep_space,
        \J11_neural_dreams,
        \J12_ritual_bells,
        \J13_morning_haze,
        \J14_gong_threshold,
        \J15_eternity_fade,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album J] setup OK -- ~playTrack.(\\J, n) | ~playAlbum.(\\J) | ~stopAlbum.()".postln;
)


// =====================================================================
//  RACCOURCIS LIVE
// =====================================================================

( ~playTrack.(\J,  1); )    // J01 first_light           (4 min)
( ~playTrack.(\J,  2); )    // J02 drone_meditation      (5 min)
( ~playTrack.(\J,  3); )    // J03 strings_horizon       (6 min)
( ~playTrack.(\J,  4); )    // J04 choir_cathedral       (7 min)
( ~playTrack.(\J,  5); )    // J05 endless_sky           (8 min)
( ~playTrack.(\J,  6); )    // J06 handpan_garden        (6 min)
( ~playTrack.(\J,  7); )    // J07 glacial_drift         (5 min)
( ~playTrack.(\J,  8); )    // J08 dark_matter           (6 min)
( ~playTrack.(\J,  9); )    // J09 oceanic               (7 min)
( ~playTrack.(\J, 10); )    // J10 deep_space            (8 min)
( ~playTrack.(\J, 11); )    // J11 neural_dreams         (7 min)
( ~playTrack.(\J, 12); )    // J12 ritual_bells          (5 min)
( ~playTrack.(\J, 13); )    // J13 morning_haze          (4 min)
( ~playTrack.(\J, 14); )    // J14 gong_threshold        (5 min)
( ~playTrack.(\J, 15); )    // J15 eternity_fade         (6 min)

( ~playAlbum.(\J); )
( ~stopAlbum.(); )
