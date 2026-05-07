// =====================================================================
//  _album.scd  --  Album F "Trance Uplifter" : 15 tracks
// =====================================================================

(  // --- SETUP ALBUM F ---
~albums = ~albums ? ();
~albums[\F] = (
    title: "Trance Uplifter",
    folder: "tracks/F_trance_uplifter/",
    tracks: [
        \F01_warm_intro,
        \F02_arp_awakening,
        \F03_uplift_one,
        \F04_progressive,
        \F05_classic_trance,
        \F06_epic_lead,
        \F07_tech_trance,
        \F08_uplift_anthem,
        \F09_psy_ride,
        \F10_breakdown_choir,
        \F11_uplift_back,
        \F12_squareLead_drive,
        \F13_emo_finale,
        \F14_drop_anthem,
        \F15_outro_warmPad,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album F] setup OK".postln;
)
