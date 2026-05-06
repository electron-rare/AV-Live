// =====================================================================
//  _album.scd  --  Album B "Deep to Hard" : 15 tracks
// =====================================================================

(  // --- SETUP ALBUM B ---
~albums = ~albums ? ();
~albums[\B] = (
    title: "Deep to Hard",
    folder: "tracks/B_deep_to_hard/",
    tracks: [
        \B01_deep_intro,
        \B02_deep_house,
        \B03_minimal_techno,
        \B04_detroit_techno,
        \B05_acid_techno,
        \B06_industrial_techno,
        \B07_schranz,
        \B08_hardgroove,
        \B09_hardtechno,
        \B10_gabber_intro,
        \B11_gabber,
        \B12_frenchcore,
        \B13_hardcore,
        \B14_terrorcore,
        \B15_finale_collapse,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album B] setup OK".postln;
)
