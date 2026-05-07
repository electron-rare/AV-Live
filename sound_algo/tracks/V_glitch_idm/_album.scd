// =====================================================================
//  _album.scd  --  Album V "Glitch IDM" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM V
//    3. ~playTrack.(\V, n)        pour jouer la track n isolement
//       ~playAlbum.(\V)           pour enchainer 01 -> 15
//       ~stopAlbum.()              pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM V ---
~albums = ~albums ? ();
~albums[\V] = (
    title: "Glitch IDM",
    folder: "tracks/V_glitch_idm/",
    tracks: [
        \V01_glitch_idm,
        \V02_broken_beats,
        \V03_aphex_drill,
        \V04_breakcore_chaos,
        \V05_fm_skitter,
        \V06_ambient_idm,
        \V07_drill_n_bass,
        \V08_stutter_groove,
        \V09_clicks_cuts,
        \V10_autechre_machine,
        \V11_neuro_glitch,
        \V12_micro_house_glitch,
        \V13_industrial_idm,
        \V14_broken_techno,
        \V15_glitch_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album V] setup OK".postln;
)
