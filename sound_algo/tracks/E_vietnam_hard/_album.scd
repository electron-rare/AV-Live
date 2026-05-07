// =====================================================================
//  _album.scd  --  Album E "Vietnam Hard" : 15 tracks
// =====================================================================

(  // --- SETUP ALBUM E ---
~albums = ~albums ? ();
~albums[\E] = (
    title: "Vietnam Hard",
    folder: "tracks/E_vietnam_hard/",
    tracks: [
        \E01_pipa_intro,
        \E02_erhu_morning,
        \E03_guzheng_dance,
        \E04_koto_groove,
        \E05_shakuhachi_walk,
        \E06_taiko_rise,
        \E07_acid_pipa,
        \E08_hard_erhu,
        \E09_growl_drop,
        \E10_hard_techno_asia,
        \E11_acid_hijaz,
        \E12_zen_break,
        \E13_pipa_finale,
        \E14_growl_hijaz,
        \E15_gong_dissolve,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album E] setup OK".postln;
)
