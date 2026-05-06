// =====================================================================
//  _album.scd  --  Album I "Liquid DnB" : 15 tracks orchestrateur
// =====================================================================

(  // --- SETUP ALBUM I ---
~albums = ~albums ? ();
~albums[\I] = (
    title: "Liquid DnB",
    folder: "tracks/I_liquid_dnb/",
    tracks: [
        \I01_first_drops,
        \I02_smooth_amen,
        \I03_rhodes_rain,
        \I04_sub_meditation,
        \I05_atmospheric_roller,
        \I06_jazzy_breaks,
        \I07_minimal_dnb,
        \I08_jungle_revival,
        \I09_neurofunk_lite,
        \I10_deep_liquid,
        \I11_breakbeat_soul,
        \I12_choir_step,
        \I13_techstep_minimal,
        \I14_amen_breakdown,
        \I15_liquid_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album I] setup OK -- ~playTrack.(\\I, n) | ~playAlbum.(\\I) | ~stopAlbum.()".postln;
)


// =====================================================================
//  RACCOURCIS LIVE
// =====================================================================

( ~playTrack.(\I,  1); )    // I01 first_drops           (4 min)
( ~playTrack.(\I,  2); )    // I02 smooth_amen           (5 min)
( ~playTrack.(\I,  3); )    // I03 rhodes_rain           (6 min)
( ~playTrack.(\I,  4); )    // I04 sub_meditation        (7 min)
( ~playTrack.(\I,  5); )    // I05 atmospheric_roller    (8 min)
( ~playTrack.(\I,  6); )    // I06 jazzy_breaks          (6 min)
( ~playTrack.(\I,  7); )    // I07 minimal_dnb           (5 min)
( ~playTrack.(\I,  8); )    // I08 jungle_revival        (6 min)
( ~playTrack.(\I,  9); )    // I09 neurofunk_lite        (7 min)
( ~playTrack.(\I, 10); )    // I10 deep_liquid           (8 min)
( ~playTrack.(\I, 11); )    // I11 breakbeat_soul        (7 min)
( ~playTrack.(\I, 12); )    // I12 choir_step            (5 min)
( ~playTrack.(\I, 13); )    // I13 techstep_minimal      (4 min)
( ~playTrack.(\I, 14); )    // I14 amen_breakdown        (5 min)
( ~playTrack.(\I, 15); )    // I15 liquid_finale         (6 min)

( ~playAlbum.(\I); )
( ~stopAlbum.(); )
