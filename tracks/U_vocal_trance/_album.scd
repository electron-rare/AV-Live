// =====================================================================
//  _album.scd  --  Album U "Vocal Trance" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM U
//    3. ~playTrack.(\U, n)        pour jouer la track n isolement
//       ~playAlbum.(\U)           pour enchainer 01 -> 15
//       ~stopAlbum.()              pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM U ---
~albums = ~albums ? ();
~albums[\U] = (
    title: "Vocal Trance",
    folder: "tracks/U_vocal_trance/",
    tracks: [
        \U01_vocal_trance,
        \U02_epic_anthem,
        \U03_uplift_dream,
        \U04_vocal_chop,
        \U05_progressive_journey,
        \U06_psy_vocal,
        \U07_balearic_vocal,
        \U08_deep_vocal_house,
        \U09_tech_trance_vocal,
        \U10_epic_orchestral,
        \U11_hard_trance_vocal,
        \U12_vocal_dub,
        \U13_ambient_vocal,
        \U14_summer_anthem,
        \U15_vocal_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album U] setup OK".postln;
)
