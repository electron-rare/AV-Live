// =====================================================================
//  _album.scd  --  Album W "Dub Techno" : 15 tracks orchestrateur
//
//  USAGE :
//    1. Charger 00_load.scd (engine + palette + live)
//    2. Cmd+Entree sur SETUP ALBUM W
//    3. ~playTrack.(\W, n)        pour jouer la track n isolement
//       ~playAlbum.(\W)           pour enchainer 01 -> 15
//       ~stopAlbum.()              pour interrompre l'album
// =====================================================================

(  // --- SETUP ALBUM W ---
~albums = ~albums ? ();
~albums[\W] = (
    title: "Dub Techno",
    folder: "tracks/W_dub_techno/",
    tracks: [
        \W01_dub_techno,
        \W02_basic_channel,
        \W03_deep_chamber,
        \W04_minimal_dub,
        \W05_cavern_chord,
        \W06_rhodes_dub,
        \W07_berlin_underground,
        \W08_ambient_dub,
        \W09_rolling_sub,
        \W10_space_dub,
        \W11_dark_dub,
        \W12_dub_pulse,
        \W13_stripped_dub,
        \W14_echo_chamber,
        \W15_dub_finale,
    ],
    durations: [240, 300, 360, 420, 480, 360, 300, 360, 420, 480, 420, 300, 240, 300, 360],
);
"[album W] setup OK".postln;
)
