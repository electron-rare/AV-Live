// =====================================================================
//  _album.scd  --  Album H "Acid Trance" : 15 tracks orchestrateur
// =====================================================================

(  // --- SETUP ALBUM H ---
~albums = ~albums ? ();
~albums[\H] = (
    title: "Acid Trance",
    folder: "tracks/H_acid_trance/",
    tracks: [
        \H01_first_state,
        \H02_goa_dream,
        \H03_303_ascension,
        \H04_psy_acid,
        \H05_uplifting_303,
        \H06_progressive_drift,
        \H07_hard_trance,
        \H08_hoover_storm,
        \H09_acid_cathedral,
        \H10_supersaw_epic,
        \H11_dark_psytrance,
        \H12_nitzhonot_303,
        \H13_full_on_acid,
        \H14_breakdown_climax,
        \H15_trance_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album H] setup OK -- ~playTrack.(\\H, n) | ~playAlbum.(\\H) | ~stopAlbum.()".postln;
)


// =====================================================================
//  RACCOURCIS LIVE
// =====================================================================

( ~playTrack.(\H,  1); )    // H01 first_state           (4 min)
( ~playTrack.(\H,  2); )    // H02 goa_dream             (5 min)
( ~playTrack.(\H,  3); )    // H03 303_ascension         (6 min)
( ~playTrack.(\H,  4); )    // H04 psy_acid              (7 min)
( ~playTrack.(\H,  5); )    // H05 uplifting_303         (8 min)
( ~playTrack.(\H,  6); )    // H06 progressive_drift     (6 min)
( ~playTrack.(\H,  7); )    // H07 hard_trance           (5 min)
( ~playTrack.(\H,  8); )    // H08 hoover_storm          (6 min)
( ~playTrack.(\H,  9); )    // H09 acid_cathedral        (7 min)
( ~playTrack.(\H, 10); )    // H10 supersaw_epic         (8 min)
( ~playTrack.(\H, 11); )    // H11 dark_psytrance        (7 min)
( ~playTrack.(\H, 12); )    // H12 nitzhonot_303         (5 min)
( ~playTrack.(\H, 13); )    // H13 full_on_acid          (4 min)
( ~playTrack.(\H, 14); )    // H14 breakdown_climax      (5 min)
( ~playTrack.(\H, 15); )    // H15 trance_finale         (6 min)

( ~playAlbum.(\H); )
( ~stopAlbum.(); )
